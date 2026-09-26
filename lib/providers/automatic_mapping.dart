import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/providers/config_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/subscribe_badge_state.dart';
import 'package:dcomic/utils/firbaselogoutput.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:pinyin/pinyin.dart';

/// One planned automatic mapping search: [origin] book [comicId] looked up on
/// [target]. Only plain data is extracted from the enqueued grid item so no
/// UI/controller objects are retained while the task sits in the queue.
class _MappingTask {
  _MappingTask(this.origin, this.target, this.comicId, this.title);

  final BaseComicSourceModel origin;
  final BaseComicSourceModel target;
  final String comicId;
  final String title;

  /// JSON-encoded (origin, comicId, target) tuple; doubles as the durable
  /// configDao key for the persisted attempt count.
  late final String key =
      'AutomaticMappingAttempts:${jsonEncode([origin.type.sourceId, comicId, target.type.sourceId])}';
}

/// Serial background queue that fills missing favorite mappings between comic
/// sources.
///
/// - Runs at most one network search at a time and paces every search an
///   interval after the previous search completed, even when the queue had
///   drained in between.
/// - Per app run each (origin, comic, target) tuple is worked on at most
///   once; the number of real attempts (including errors and empty or
///   ambiguous results, never queued/skipped items) persists in [ConfigDao]
///   under a per-tuple JSON-encoded key and is capped unless
///   retry-on-every-launch is enabled (which still records counts).
/// - The attempt count is persisted immediately before the search starts; a
///   disable arriving while that persistence is awaited rolls the count back
///   so unstarted requests are never counted.
/// - Existing relationships or suppression records are skipped regardless of
///   which endpoint was stored first.
/// - Matches are strict: exactly one search result with a simplified Chinese
///   equivalent title and a non-empty id, inserted via
///   [ComicMappingDao.insertAutomaticMappingIfAbsent] so concurrent explicit
///   bind/unbind always wins; successful inserts notify
///   [SubscribeBadgeState.changes].
///
/// The queue is a [ChangeNotifier] that notifies only when the relevant
/// config changed, after having stopped pending work on disable, so callers
/// can re-enqueue their currently loaded items.
class AutomaticMappingQueue extends ChangeNotifier {
  AutomaticMappingQueue(this.config, this.sources) {
    _configSignature = _currentConfigSignature;
    config.addListener(_onConfigChanged);
  }

  final ConfigProvider config;
  final List<BaseComicSourceModel> sources;

  final Logger _logger = Logger(
    printer: PrettyPrinter(noBoxingByDefault: true, methodCount: 2),
    filter: ProductionFilter(),
    output: CrashConsoleOutput(),
  );

  final _pending = ListQueue<_MappingTask>();
  final Set<String> _pendingKeys = {};
  final Set<String> _touchedThisRun = {};
  Completer<void>? _drain;
  bool _running = false;
  bool _disposed = false;

  Stopwatch? _sinceLastSearch;
  Timer? _pacingTimer;
  Completer<void>? _pacingWait;

  (bool, bool, int, bool, int) _configSignature = (false, false, 1, true, 3);

  (bool, bool, int, bool, int) get _currentConfigSignature => (
    config.autoMapMissingComics,
    config.aggregateSubscribeBadges,
    config.autoMapIntervalSeconds,
    config.autoMapRetryEveryLaunch,
    config.autoMapMaxAttempts,
  );

  /// Both the aggregate parent feature and the child switch must be enabled.
  bool get _enabled =>
      !_disposed &&
      config.autoMapMissingComics &&
      config.aggregateSubscribeBadges;

  /// Completes once no pending or in-flight work is left. While the queue
  /// paces between two real searches the future stays pending because the
  /// following search is still pending work.
  Future<void> get idle => _drain?.future ?? Future.value();

  /// Schedules [items] from [origin] for automatic mapping onto every other
  /// known source. Tuples already pending or already worked on this run are
  /// dropped; calling while disabled drops everything (never tried items can
  /// be re-enqueued later).
  void enqueue(BaseComicSourceModel origin, Iterable<GridItemEntity> items) {
    if (!_enabled) return;
    for (final item in items) {
      if (item is! GridItemEntityWithStatus) continue;
      final comicId = item.comicId;
      final title = item.rawTitle;
      if (comicId.isEmpty || title == null || title.isEmpty) continue;
      for (final target in sources) {
        if (target.type.sourceId == origin.type.sourceId) continue;
        final task = _MappingTask(origin, target, comicId, title);
        if (_pendingKeys.contains(task.key) ||
            _touchedThisRun.contains(task.key)) {
          continue;
        }
        _pendingKeys.add(task.key);
        _pending.add(task);
      }
    }
    if (_pending.isEmpty) return;
    _drain ??= Completer<void>();
    _start();
  }

  /// Stops the queue: cancels pacing timers/waits, drops pending work and
  /// ignores future [enqueue] calls. In-flight searches finish on their own;
  /// [idle] covers them.
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    config.removeListener(_onConfigChanged);
    _pending.clear();
    _pendingKeys.clear();
    _wakePacing();
    super.dispose();
  }

  void _start() {
    if (_running) return;
    _running = true;
    unawaited(_run());
  }

  Future<void> _run() async {
    try {
      while (_pending.isNotEmpty) {
        if (!_enabled) break;
        final task = _pending.removeFirst();
        try {
          if (!_touchedThisRun.contains(task.key)) await _process(task);
        } catch (e, s) {
          _logger.e(
            'automatic mapping task failed: $e',
            error: e,
            stackTrace: s,
          );
        } finally {
          _pendingKeys.remove(task.key);
        }
      }
    } finally {
      _running = false;
      // A disable or dispose dropped the rest; nothing may stay pending.
      _pending.clear();
      _pendingKeys.clear();
      final drain = _drain;
      _drain = null;
      drain?.complete();
    }
  }

  Future<void> _process(_MappingTask task) async {
    final database = await DatabaseInstance.instance;
    if (!_enabled) return;
    final existing = await database.comicMappingDao.lookupComicId(
      task.comicId,
      task.origin.type.sourceId,
      task.target.type.sourceId,
    );
    if (!_enabled) return;
    if (existing != null) {
      _touchedThisRun.add(task.key);
      return;
    }
    // Persistent per-tuple attempt cap.
    final attempts = await _readAttempts(task.key);
    if (!_enabled) return;
    if (!config.autoMapRetryEveryLaunch &&
        attempts >= config.autoMapMaxAttempts) {
      _touchedThisRun.add(task.key);
      return;
    }
    // Pace after the previous actual search completed.
    await _waitPacing();
    if (!_enabled) return;
    // Bindings and retry settings may change while pacing.
    final currentMapping = await database.comicMappingDao.lookupComicId(
      task.comicId,
      task.origin.type.sourceId,
      task.target.type.sourceId,
    );
    if (!_enabled) return;
    if (currentMapping != null ||
        (!config.autoMapRetryEveryLaunch &&
            attempts >= config.autoMapMaxAttempts)) {
      _touchedThisRun.add(task.key);
      return;
    }
    await _writeAttempts(task.key, attempts + 1);
    if (!_enabled) {
      // Disabled while the count was persisting: the request never started,
      // so the increment must not stand.
      await _writeAttempts(task.key, attempts);
      return;
    }
    _touchedThisRun.add(task.key);
    final List<ComicListItemEntity> results;
    try {
      results = await task.target.searchComicDetail(task.title);
    } catch (e, s) {
      // Expected transient network failures keep the queue running and keep
      // the attempt counted; warnings stay out of crash reporting.
      _logger.w('automatic mapping search failed: $e', error: e, stackTrace: s);
      return;
    } finally {
      _sinceLastSearch ??= Stopwatch()..start();
      _sinceLastSearch!.reset();
    }
    // Strict match: exactly one simplified-equivalent title with a real id.
    final wanted = ChineseHelper.convertToSimplifiedChinese(task.title);
    String? matched;
    for (final result in results) {
      if (result.comicId.isEmpty) continue;
      if (ChineseHelper.convertToSimplifiedChinese(result.rawTitle) != wanted) {
        continue;
      }
      if (matched != null) {
        matched = null;
        break;
      }
      matched = result.comicId;
    }
    if (matched == null) return;
    await _insertMapping(task, matched);
  }

  Future<void> _insertMapping(_MappingTask task, String targetComicId) async {
    final database = await DatabaseInstance.instance;
    final result = await database.comicMappingDao
        .insertAutomaticMappingIfAbsent(
          task.comicId,
          task.origin.type.sourceId,
          task.target.type.sourceId,
          targetComicId,
        );
    if (result == targetComicId) {
      SubscribeBadgeState.changes.notifyListeners();
    }
  }

  Future<int> _readAttempts(String key) async {
    final database = await DatabaseInstance.instance;
    return (await database.configDao.getConfigByKey(key))?.get<int>() ?? 0;
  }

  Future<void> _writeAttempts(String key, int value) async {
    final database = await DatabaseInstance.instance;
    final entity = await database.configDao.getOrCreateConfigByKey(key);
    entity.set(value);
    await database.configDao.updateConfig(entity);
  }

  Future<void> _waitPacing() async {
    final last = _sinceLastSearch;
    if (last == null) return;
    while (_enabled) {
      final remaining =
          Duration(seconds: config.autoMapIntervalSeconds) - last.elapsed;
      if (remaining <= Duration.zero) return;
      final wait = Completer<void>();
      _pacingWait = wait;
      _pacingTimer = Timer(remaining, _wakePacing);
      await wait.future;
    }
  }

  /// Completes the pacing wait early (timer fired, disable or dispose).
  void _wakePacing() {
    _pacingTimer?.cancel();
    _pacingTimer = null;
    final wait = _pacingWait;
    _pacingWait = null;
    if (wait != null && !wait.isCompleted) wait.complete();
  }

  void _onConfigChanged() {
    if (_disposed) return;
    final signature = _currentConfigSignature;
    if (signature == _configSignature) return;
    _configSignature = signature;
    if (!_enabled) {
      // Stop remaining work now; never tried items may be re-enqueued later.
      _pending.clear();
      _pendingKeys.clear();
    }
    _wakePacing();
    notifyListeners();
  }
}
