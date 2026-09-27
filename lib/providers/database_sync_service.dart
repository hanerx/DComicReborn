import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/sync/sync_models.dart';
import 'package:dcomic/database/sync/sync_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class DatabaseSyncService extends ChangeNotifier with WidgetsBindingObserver {
  static const Duration _requestTimeout = Duration(seconds: 20);

  final SyncStore? _providedStore;
  final Dio _dio;
  final bool _ownsDio;
  final Stream<bool> _onlineChanges;
  final Duration _pollInterval;
  final Duration _reconnectDelay;
  final String _deviceName;

  SyncStore? _store;
  StreamSubscription<Set<SyncCategory>>? _pendingSubscription;
  StreamSubscription<Set<SyncCategory>>? _storeSubscription;
  StreamSubscription<bool>? _onlineSubscription;
  Timer? _pollTimer;
  Timer? _reconnectTimer;
  HttpClient? _eventsClient;
  Future<void>? _eventsRun;
  Future<void>? _initializeRun;
  Future<void>? _syncRun;
  Completer<void>? _operationGate;
  Completer<void>? _applicationGate;
  Future<void>? _preferenceWriter;

  bool _initialized = false;
  bool _busy = false;
  bool _enabled = false;
  bool _connected = false;
  bool _online = true;
  bool _foreground = true;
  bool _disposed = false;
  bool _syncAgain = false;
  bool _preferencesDirty = false;
  int _eventsGeneration = 0;
  int _categoryRevision = 0;
  int _cursor = 0;
  String? _error;
  String? _serverUrl;
  String? _userId;
  String? _username;
  String? _token;
  DateTime? _lastSuccess;
  int _pendingCount = 0;
  Set<SyncCategory> _categories = _defaultCategories();
  List<SyncConflict> _conflicts = const [];

  DatabaseSyncService({
    SyncStore? store,
    Dio? dio,
    Stream<bool>? onlineChanges,
    Duration pollInterval = const Duration(minutes: 5),
    Duration reconnectDelay = const Duration(seconds: 5),
    String? deviceName,
  }) : _providedStore = store,
       _dio = dio ?? Dio(),
       _ownsDio = dio == null,
       _onlineChanges = onlineChanges ??
           Connectivity().onConnectivityChanged.map(
             (results) => results.any(
               (result) => result != ConnectivityResult.none,
             ),
           ),
       // ignore: prefer_initializing_formals
       _pollInterval = pollInterval,
       // ignore: prefer_initializing_formals
       _reconnectDelay = reconnectDelay,
       _deviceName = deviceName ?? _defaultDeviceName();

  bool get initialized => _initialized;
  bool get busy => _busy;
  bool get syncing => _syncRun != null;
  bool get enabled => _enabled;
  bool get connected => _connected;
  String? get error => _error;
  String? get serverUrl => _serverUrl;
  String? get username => _username;
  DateTime? get lastSuccess => _lastSuccess;
  int get pendingCount => _pendingCount;
  Set<SyncCategory> get categories => Set.unmodifiable(_categories);
  List<SyncConflict> get conflicts => List.unmodifiable(_conflicts);
  SyncStore? get store => _initialized ? _store : null;

  Future<void> initialize() {
    if (_initialized || _disposed) return Future<void>.value();
    return _initializeRun ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      final syncStore = _providedStore ?? await _defaultStore();
      _store = syncStore;
      await _loadPreferences();
      await _refreshLocalStatus();
      if (_disposed) return;

      _pendingSubscription = syncStore.pendingChanges.listen(
        (_) {
          if (_disposed) return;
          unawaited(_refreshPendingCount());
          unawaited(_requestSync());
        },
        onError: (Object failure) {
          if (_disposed) return;
          _setError(_friendlyError(failure));
        },
      );
      _storeSubscription = syncStore.changes.listen((_) {
        if (_disposed) return;
        unawaited(_refreshLocalStatus());
      });
      _onlineSubscription = _onlineChanges.listen(
        _handleOnlineChanged,
        onError: (_) {
          // Connectivity is only a hint. HTTP remains the source of truth.
        },
      );
      WidgetsBinding.instance.addObserver(this);
      _initialized = true;
      _notify();
      _updateTransports();
    } catch (failure) {
      if (_disposed) return;
      _initialized = true;
      _error = _friendlyError(failure);
      _notify();
    }
  }

  static Future<SyncStore> _defaultStore() async {
    await DatabaseInstance.instance;
    return DatabaseInstance.syncStore;
  }

  Future<void> login({
    required String serverUrl,
    required String username,
    required String password,
    required bool migrateLocal,
  }) async {
    await _ensureInitialized();
    late final String normalizedUrl;
    try {
      normalizedUrl = _normalizeServerUrl(serverUrl);
    } catch (failure) {
      _setError(_friendlyError(failure, login: true));
      return;
    }
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty || password.isEmpty) {
      _setError('Enter a username and password.');
      return;
    }

    var loggedIn = false;
    await _exclusive(() async {
      try {
        await _flushPreferenceWrites();
        final timeResult = await _readServerTime(normalizedUrl);
        final stopwatch = Stopwatch()..start();
        final response = await _post(
          normalizedUrl,
          '/api/v1/login',
          data: {
            'username': normalizedUsername,
            'password': password,
            'deviceId': _store!.deviceId,
            'deviceName': _deviceName,
          },
        );
        stopwatch.stop();
        final body = _map(response.data);
        final newToken = _requiredString(body, 'token');
        final newUserId = _requiredString(body, 'userId');
        final returnedUsername = _requiredString(body, 'username');
        final serverTime = _requiredInt(body, 'serverTime');

        final replacesAccount =
            _serverUrl != normalizedUrl || _userId != newUserId;
        await _withApplicationLock(() async {
          _stopTransports();
          await _store!.bindAccount(
            jsonEncode([normalizedUrl, newUserId]),
            migrateLocal: migrateLocal,
          );
          await _store!.calibrate(
            timeResult.serverTime,
            roundTrip: timeResult.roundTrip,
          );
          await _store!.calibrate(serverTime, roundTrip: stopwatch.elapsed);
          final accountPreferences = await _store!.readPreferences();
          _applyAccountPreferences(accountPreferences);
          if (migrateLocal && replacesAccount) _cursor = 0;
          _serverUrl = normalizedUrl;
          _userId = newUserId;
          _username = returnedUsername;
          _token = newToken;
          _error = null;
          await _persistPreferences();
          await _refreshLocalStatus();
        });
        loggedIn = true;
      } catch (failure) {
        _setError(_friendlyError(failure, login: true));
      }
    });
    _updateTransports();
    if (loggedIn && _canTransport) unawaited(_requestSync());
  }

  Future<void> logout() async {
    await _ensureInitialized();
    if (_token == null || _serverUrl == null) return;
    await _exclusive(() async {
      try {
        await _post(
          _serverUrl!,
          '/api/v1/logout',
          token: _token,
          data: const <String, Object>{},
        );
      } on DioException catch (failure) {
        if (failure.response?.statusCode != HttpStatus.unauthorized) {
          _setError(_friendlyError(failure));
          return;
        }
      } catch (failure) {
        _setError(_friendlyError(failure));
        return;
      }
      _stopTransports();
      _token = null;
      _username = null;
      _enabled = false;
      _connected = false;
      _error = null;
      await _persistPreferences();
    });
  }

  Future<void> setEnabled(bool value) async {
    await _ensureInitialized();
    if (value && (_token == null || _serverUrl == null)) {
      _setError('Sign in to a sync server first.');
      return;
    }
    if (value && _categories.isEmpty) {
      _setError('Select at least one sync category first.');
      return;
    }
    var changed = false;
    await _withApplicationLock(() async {
      if (_enabled == value) return;
      changed = true;
      _enabled = value;
      _error = null;
      if (!value) _stopTransports();
      await _persistPreferences();
      _notify();
    });
    if (!changed) return;
    _updateTransports();
    if (value) unawaited(_requestSync());
  }

  Future<void> setCategory(SyncCategory category, bool value) async {
    await _ensureInitialized();
    var changed = false;
    await _withApplicationLock(() async {
      changed = value
          ? _categories.add(category)
          : _categories.remove(category);
      if (!changed) return;
      if (value) _cursor = 0;
      _categoryRevision++;
      _syncAgain = true;
      _error = null;
      await _persistPreferences();
      await _refreshLocalStatus();
    });
    if (!changed) return;
    _updateTransports();
    unawaited(_requestSync());
  }

  Future<void> syncNow() async {
    await _ensureInitialized();
    if (!_enabled || _token == null || _serverUrl == null) {
      _setError('Enable sync after signing in.');
      return;
    }
    if (_categories.isEmpty) {
      _setError('Select at least one sync category.');
      return;
    }
    await _requestSync();
  }

  Future<void> resolveConflict(
    SyncConflict conflict, {
    required bool useLocal,
  }) async {
    await _ensureInitialized();
    if (_token == null || _serverUrl == null) {
      _setError('Sign in before resolving a server conflict.');
      return;
    }
    if (!_enabled) {
      _setError('Enable sync before resolving a conflict.');
      return;
    }
    if (!_categories.contains(conflict.local.category)) {
      _setError('Enable this sync category before resolving its conflict.');
      return;
    }
    await _exclusive(() async {
      try {
        var resolution = await _store!.pendingResolution(conflict.id);
        if (resolution == null) {
          final time = await _readServerTime(_serverUrl!);
          resolution = await _withApplicationLock<SyncRecord?>(() async {
            if (!_canTransport ||
                !_categories.contains(conflict.local.category)) {
              return null;
            }
            await _store!.calibrate(
              time.serverTime,
              roundTrip: time.roundTrip,
            );
            await _store!.resolveConflict(conflict.id, useLocal: useLocal);
            return _store!.pendingResolution(conflict.id);
          });
        }
        if (resolution == null) {
          if (!_canTransport ||
              !_categories.contains(conflict.local.category)) {
            return;
          }
          throw const _SyncFailure('The resolution could not be queued.');
        }
        if (!await _submitResolution(conflict, resolution)) return;
        _error = null;
        await _refreshConflicts();
        await _refreshPendingCount();
      } catch (failure) {
        final status = failure is DioException
            ? failure.response?.statusCode
            : null;
        if (status == HttpStatus.conflict ||
            status == HttpStatus.notFound) {
          try {
            await _fetchServerConflicts();
            if (status == HttpStatus.notFound) {
              _error = null;
              _notify();
              return;
            }
          } catch (_) {
            // Surface the original resolution failure.
          }
        }
        _setError(_friendlyError(failure, conflict: true));
      }
    });
    unawaited(_requestSync());
  }

  Future<void> changePassword(String current, String next) async {
    await _ensureInitialized();
    if (_token == null || _serverUrl == null) {
      _setError('Sign in before changing the password.');
      return;
    }
    if (current.isEmpty || next.isEmpty) {
      _setError('Enter the current and new passwords.');
      return;
    }
    await _exclusive(() async {
      try {
        await _post(
          _serverUrl!,
          '/api/v1/password',
          token: _token,
          data: {'currentPassword': current, 'newPassword': next},
        );
        _stopTransports();
        _token = null;
        _username = null;
        _enabled = false;
        _connected = false;
        _error = null;
        await _persistPreferences();
      } catch (failure) {
        _setError(_friendlyError(failure));
      }
    });
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) await initialize();
    if (_disposed || _store == null) {
      throw StateError('DatabaseSyncService is unavailable.');
    }
  }

  Future<void> _loadPreferences() async {
    final preferences = await _store!.readPreferences();
    _applyAccountPreferences(preferences);
    final savedUrl = preferences['serverUrl'];
    if (savedUrl is String && savedUrl.isNotEmpty) {
      try {
        _serverUrl = _normalizeServerUrl(savedUrl);
      } catch (_) {
        _serverUrl = null;
      }
    }
    _userId = _optionalString(preferences['userId']);
    _username = _optionalString(preferences['username']);
    _token = _optionalString(preferences['token']);
    if (_serverUrl == null || _userId == null || _username == null || _token == null) {
      _enabled = false;
      _connected = false;
    }
  }

  void _applyAccountPreferences(Map<String, dynamic> preferences) {
    final categoryNames = preferences['categories'];
    if (categoryNames is List) {
      final parsed = <SyncCategory>{};
      for (final name in categoryNames.whereType<String>()) {
        for (final category in SyncCategory.values) {
          if (category.name == name) parsed.add(category);
        }
      }
      _categories = parsed;
    } else {
      _categories = _defaultCategories();
    }
    _enabled = preferences['enabled'] == true;
    final cursor = preferences['cursor'];
    _cursor = cursor is int && cursor >= 0 ? cursor : 0;
    final lastSuccess = preferences['lastSuccess'];
    _lastSuccess = lastSuccess is int
        ? DateTime.fromMillisecondsSinceEpoch(lastSuccess)
        : null;
  }

  Future<void> _persistPreferences() {
    if (_disposed || _store == null) return Future<void>.value();
    _preferencesDirty = true;
    final active = _preferenceWriter;
    if (active != null) return active;
    final writer = _writePreferencesUntilClean();
    _preferenceWriter = writer;
    return writer;
  }

  Future<void> _writePreferencesUntilClean() async {
    try {
      while (_preferencesDirty && !_disposed) {
        _preferencesDirty = false;
        await _store!.writePreferences({
          'version': 1,
          if (_serverUrl != null) 'serverUrl': _serverUrl,
          if (_userId != null) 'userId': _userId,
          if (_username != null) 'username': _username,
          if (_token != null) 'token': _token,
          'enabled': _enabled,
          'categories': _categories.map((category) => category.name).toList(),
          'cursor': _cursor,
          if (_lastSuccess != null)
            'lastSuccess': _lastSuccess!.millisecondsSinceEpoch,
        });
      }
    } finally {
      _preferenceWriter = null;
      if (_preferencesDirty && !_disposed) {
        unawaited(_persistPreferences());
      }
    }
  }

  Future<void> _flushPreferenceWrites() async {
    while (_preferenceWriter != null) {
      await _preferenceWriter;
    }
  }

  Future<void> _refreshLocalStatus() async {
    if (_store == null || _disposed) return;
    try {
      final pending = await _store!.pendingCount(_categories);
      final conflicts = await _store!.conflicts();
      if (_disposed) return;
      _pendingCount = pending;
      _conflicts = conflicts
          .where((conflict) => _categories.contains(conflict.local.category))
          .toList(growable: false);
      _notify();
    } catch (_) {
      // Initialization and the active operation surface their own failures.
    }
  }

  Future<void> _refreshPendingCount() async {
    if (_store == null || _disposed) return;
    try {
      final value = await _store!.pendingCount(_categories);
      if (_disposed) return;
      _pendingCount = value;
      _notify();
    } catch (_) {
      // The next operation refreshes the count again.
    }
  }

  Future<void> _refreshConflicts() async {
    final value = await _store!.conflicts();
    if (_disposed) return;
    _conflicts = value
        .where((conflict) => _categories.contains(conflict.local.category))
        .toList(growable: false);
    _notify();
  }

  Future<void> _requestSync() {
    if (_disposed || !_initialized || !_enabled || !_foreground || !_online ||
        _token == null || _serverUrl == null || _categories.isEmpty) {
      return Future<void>.value();
    }
    _syncAgain = true;
    final active = _syncRun;
    if (active != null) return active;
    late final Future<void> run;
    run = _exclusive(_runRequestedSyncs);
    _syncRun = run;
    unawaited(
      run.whenComplete(() {
        if (identical(_syncRun, run)) _syncRun = null;
        if (_syncAgain) unawaited(_requestSync());
      }),
    );
    return run;
  }

  Future<void> _runRequestedSyncs() async {
    while (_syncAgain && _canTransport) {
      _syncAgain = false;
      try {
        await _syncUntilSettled();
        _error = null;
        if (_canTransport) _connected = true;
      } catch (failure) {
        _connected = false;
        _setError(_friendlyError(failure));
        break;
      }
    }
    await _refreshLocalStatus();
    _notify();
  }

  Future<void> _syncUntilSettled() async {
    await _retryPendingResolutions();
    while (_canTransport) {
      final revision = _categoryRevision;
      final requestedCategories = Set<SyncCategory>.of(_categories);
      final requestedCursor = _cursor;
      final sent = await _store!.pending(requestedCategories, limit: 200);
      final stopwatch = Stopwatch()..start();
      final response = await _post(
        _serverUrl!,
        '/api/v1/sync',
        token: _token,
        data: {
          'cursor': requestedCursor,
          'categories': requestedCategories
              .map((category) => category.name)
              .toList(),
          'changes': sent.map((record) => record.toJson()).toList(),
        },
      );
      stopwatch.stop();
      final body = _map(response.data);
      final responseCursor = _requiredInt(body, 'cursor');
      final hasMore = body['hasMore'];
      if (responseCursor < 0 || hasMore is! bool) {
        throw const _SyncFailure('The sync server returned an invalid page.');
      }
      var applied = false;
      var categoriesChanged = false;
      await _withApplicationLock(() async {
        if (!_canTransport) return;
        final enabledRequestedCategories = requestedCategories
            .intersection(_categories);
        final serverTime = _requiredInt(body, 'serverTime');
        await _store!.calibrate(serverTime, roundTrip: stopwatch.elapsed);
        await _applySyncResults(
          body,
          sent,
          enabledRequestedCategories,
        );
        final records = _list(body, 'records')
            .map((value) => SyncRecord.fromJson(_map(value)))
            .where(
              (record) => enabledRequestedCategories.contains(record.category),
            )
            .toList();
        await _store!.receive(records);
        applied = true;

        if (revision == _categoryRevision &&
            setEquals(requestedCategories, _categories)) {
          _cursor = responseCursor;
          _lastSuccess = DateTime.now();
          await _persistPreferences();
        } else {
          _syncAgain = true;
          categoriesChanged = true;
        }
      });
      if (!applied || categoriesChanged) return;

      if (hasMore) continue;
      final remaining = await _store!.pendingCount(requestedCategories);
      if (remaining == 0) break;
    }
    if (_canTransport) await _fetchServerConflicts();
  }

  Future<void> _retryPendingResolutions() async {
    final conflicts = await _store!.conflicts();
    for (final conflict in conflicts) {
      if (!_categories.contains(conflict.local.category)) continue;
      final resolution = await _store!.pendingResolution(conflict.id);
      if (resolution == null) continue;
      try {
        if (!await _submitResolution(conflict, resolution)) return;
      } on DioException catch (failure) {
        final status = failure.response?.statusCode;
        if (status != HttpStatus.conflict &&
            status != HttpStatus.notFound) {
          rethrow;
        }
        await _fetchServerConflicts();
        return;
      }
    }
  }

  Future<bool> _submitResolution(
    SyncConflict conflict,
    SyncRecord resolution,
  ) async {
    final maySubmit = await _withApplicationLock(
      () async =>
          _canTransport &&
          _categories.contains(conflict.local.category),
    );
    if (!maySubmit) return false;
    final response = await _post(
      _serverUrl!,
      '/api/v1/conflicts/resolve',
      token: _token,
      data: {
        'record': resolution.toJson(),
        'rejectedVersion': conflict.local.version.toJson(),
      },
    );
    return _withApplicationLock(() async {
      if (!_canTransport ||
          !_categories.contains(conflict.local.category)) {
        return false;
      }
      final canonical = SyncRecord.fromJson(_map(response.data));
      await _store!.acknowledge(resolution, canonical);
      return true;
    });
  }

  Future<void> _applySyncResults(
    Map<String, dynamic> body,
    List<SyncRecord> sent,
    Set<SyncCategory> enabledCategories,
  ) async {
    final results = _list(body, 'results');
    final unmatched = List<SyncRecord>.of(sent);
    for (final value in results) {
      final result = _map(value);
      final categoryName = _requiredString(result, 'category');
      final key = _requiredString(result, 'key');
      final status = _requiredString(result, 'status');
      final sentIndex = unmatched.indexWhere(
        (record) => record.category.name == categoryName && record.key == key,
      );
      if (sentIndex < 0) {
        throw const _SyncFailure('The sync server returned an unknown result.');
      }
      final local = unmatched.removeAt(sentIndex);
      if (!enabledCategories.contains(local.category)) continue;
      final canonical = SyncRecord.fromJson(_map(result['record']));
      switch (status) {
        case 'accepted':
        case 'superseded':
          await _store!.acknowledge(local, canonical);
          break;
        case 'conflict':
          await _store!.addConflict(local, canonical);
          break;
        default:
          throw const _SyncFailure('The sync server returned an invalid status.');
      }
    }
    if (unmatched.isNotEmpty) {
      throw const _SyncFailure('The sync server omitted a change result.');
    }
  }

  Future<void> _fetchServerConflicts() async {
    if (_token == null || _serverUrl == null) return;
    final response = await _get(
      _serverUrl!,
      '/api/v1/conflicts',
      token: _token,
    );
    final body = _map(response.data);
    await _withApplicationLock(() async {
      if (!_canTransport) return;
      final existing = await _store!.conflicts();
      final serverCandidates = <(SyncCategory, String, SyncVersion)>{};
      for (final value in _list(body, 'conflicts')) {
        final conflict = _map(value);
        final local = SyncRecord.fromJson(_map(conflict['local']));
        final remote = SyncRecord.fromJson(_map(conflict['remote']));
        if (!_categories.contains(local.category)) continue;
        serverCandidates.add((local.category, local.key, local.version));
        await _store!.addConflict(local, remote);
      }
      for (final conflict in existing) {
        if (!_categories.contains(conflict.local.category)) continue;
        final identity = (
          conflict.local.category,
          conflict.local.key,
          conflict.local.version,
        );
        if (!serverCandidates.contains(identity)) {
          await _store!.removeConflict(conflict.id);
        }
      }
      await _refreshConflicts();
    });
  }

  Future<_ServerTime> _readServerTime(String baseUrl) async {
    final stopwatch = Stopwatch()..start();
    final response = await _get(baseUrl, '/api/v1/time');
    stopwatch.stop();
    return _ServerTime(
      _requiredInt(_map(response.data), 'serverTime'),
      stopwatch.elapsed,
    );
  }

  Future<Response<dynamic>> _get(
    String baseUrl,
    String path, {
    String? token,
  }) => _dio.getUri<dynamic>(
    _endpoint(baseUrl, path),
    options: _options(token),
  );

  Future<Response<dynamic>> _post(
    String baseUrl,
    String path, {
    String? token,
    required Object data,
  }) => _dio.postUri<dynamic>(
    _endpoint(baseUrl, path),
    data: data,
    options: _options(token),
  );

  Options _options(String? token) => Options(
    followRedirects: false,
    maxRedirects: 0,
    sendTimeout: _requestTimeout,
    receiveTimeout: _requestTimeout,
    responseType: ResponseType.json,
    headers: {
      HttpHeaders.acceptHeader: ContentType.json.mimeType,
      HttpHeaders.contentTypeHeader: ContentType.json.mimeType,
      if (token != null) HttpHeaders.authorizationHeader: 'Bearer $token',
    },
    validateStatus: (status) => status != null && status >= 200 && status < 300,
  );

  Uri _endpoint(String baseUrl, String suffix) {
    final base = Uri.parse(baseUrl);
    final prefix = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    return base.replace(path: '$prefix$suffix', query: null, fragment: null);
  }

  static String _normalizeServerUrl(String input) {
    final trimmed = input.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const _SyncFailure('Enter a complete sync server URL.');
    }
    if (uri.userInfo.isNotEmpty || uri.query.isNotEmpty || uri.fragment.isNotEmpty) {
      throw const _SyncFailure('The server URL cannot contain credentials, a query, or a fragment.');
    }
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    if (scheme != 'https' && scheme != 'http') {
      throw const _SyncFailure('The server URL must use HTTP or HTTPS.');
    }
    if (uri.path.contains('/../') || uri.path.endsWith('/..')) {
      throw const _SyncFailure('The server URL path is not valid.');
    }
    final normalizedPath = uri.path == '/'
        ? ''
        : uri.path.replaceFirst(RegExp(r'/+$'), '');
    return uri
        .replace(
          scheme: scheme,
          host: host,
          path: normalizedPath,
          query: null,
          fragment: null,
        )
        .toString();
  }

  void _updateTransports() {
    if (!_canTransport) {
      _stopTransports();
      return;
    }
    _pollTimer ??= Timer.periodic(
      _pollInterval,
      (_) => unawaited(_requestSync()),
    );
    _startEvents();
  }

  bool get _canTransport =>
      !_disposed &&
      _initialized &&
      _enabled &&
      _foreground &&
      _online &&
      _token != null &&
      _serverUrl != null &&
      _categories.isNotEmpty;

  void _startEvents() {
    if (!_canTransport || _eventsRun != null) return;
    final generation = _eventsGeneration;
    late final Future<void> run;
    run = _listenForEvents(generation);
    _eventsRun = run;
    unawaited(
      run.whenComplete(() {
        if (identical(_eventsRun, run)) _eventsRun = null;
        if (!_disposed && generation == _eventsGeneration && _canTransport) {
          _reconnectTimer?.cancel();
          _reconnectTimer = Timer(_reconnectDelay, _startEvents);
        }
      }),
    );
  }

  Future<void> _listenForEvents(int generation) async {
    final client = HttpClient()
      ..connectionTimeout = _requestTimeout
      ..idleTimeout = const Duration(minutes: 2);
    _eventsClient = client;
    try {
      final request = await client.getUrl(_endpoint(_serverUrl!, '/api/v1/events'));
      request.followRedirects = false;
      request.maxRedirects = 0;
      request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
      final response = await request.close().timeout(_requestTimeout);
      if (response.statusCode != HttpStatus.ok ||
          response.isRedirect ||
          !response.headers.contentType.toString().startsWith('text/event-stream')) {
        await response.drain<void>();
        return;
      }
      if (generation != _eventsGeneration || !_canTransport) return;
      _connected = true;
      _notify();
      var eventName = '';
      await for (final line
          in response.transform(utf8.decoder).transform(const LineSplitter())) {
        if (generation != _eventsGeneration || !_canTransport) return;
        if (line.isEmpty) {
          if (eventName == 'change') unawaited(_requestSync());
          eventName = '';
        } else if (line.startsWith('event:')) {
          eventName = line.substring(6).trim();
        }
      }
    } catch (_) {
      // Polling remains authoritative; reconnect is scheduled by the caller.
    } finally {
      if (identical(_eventsClient, client)) _eventsClient = null;
      client.close(force: true);
      if (generation == _eventsGeneration && !_disposed) {
        _connected = false;
        _notify();
      }
    }
  }

  void _stopTransports() {
    _eventsGeneration++;
    _pollTimer?.cancel();
    _pollTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _eventsClient?.close(force: true);
    _eventsRun = null;
    _eventsClient = null;
    _connected = false;
  }

  void _handleOnlineChanged(bool online) {
    if (_disposed || _online == online) return;
    _online = online;
    if (!online) {
      _stopTransports();
    } else {
      _updateTransports();
      unawaited(_requestSync());
    }
    _notify();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (_disposed || _foreground == foreground) return;
    _foreground = foreground;
    if (!foreground) {
      _stopTransports();
    } else {
      _updateTransports();
      unawaited(_requestSync());
    }
    _notify();
  }

  Future<T> _withApplicationLock<T>(
    Future<T> Function() action,
  ) async {
    while (_applicationGate != null) {
      await _applicationGate!.future;
    }
    final gate = Completer<void>();
    _applicationGate = gate;
    try {
      return await action();
    } finally {
      if (identical(_applicationGate, gate)) _applicationGate = null;
      if (!gate.isCompleted) gate.complete();
    }
  }

  Future<void> _exclusive(Future<void> Function() action) async {
    while (_operationGate != null) {
      await _operationGate!.future;
    }
    final gate = Completer<void>();
    _operationGate = gate;
    _busy = true;
    _notify();
    try {
      await action();
    } finally {
      if (identical(_operationGate, gate)) _operationGate = null;
      if (!gate.isCompleted) gate.complete();
      _busy = false;
      _notify();
    }
  }

  void _setError(String message) {
    if (_disposed) return;
    _error = message;
    _notify();
  }

  String _friendlyError(
    Object failure, {
    bool login = false,
    bool conflict = false,
  }) {
    if (failure is _SyncFailure) return failure.message;
    if (failure is DioException) {
      final status = failure.response?.statusCode;
      if (status == HttpStatus.unauthorized) {
        return login
            ? 'The username or password is incorrect.'
            : 'The sync session has expired. Sign in again.';
      }
      if (status == HttpStatus.forbidden) {
        return 'This sync account is disabled or does not allow this action.';
      }
      if (status == HttpStatus.conflict && conflict) {
        return 'This conflict changed on another device. Refresh and choose again.';
      }
      if (status == HttpStatus.unprocessableEntity) {
        return 'The server rejected a record timestamp. Check the device clock.';
      }
      if (status != null) return 'The sync server returned HTTP $status.';
      if (failure.type == DioExceptionType.connectionTimeout ||
          failure.type == DioExceptionType.sendTimeout ||
          failure.type == DioExceptionType.receiveTimeout) {
        return 'The sync server timed out.';
      }
      return 'Could not connect to the sync server.';
    }
    if (failure is SocketException || failure is TimeoutException) {
      return 'Could not connect to the sync server.';
    }
    return conflict
        ? 'Could not resolve the conflict. Try again.'
        : 'Synchronization failed. Try again.';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    final pendingSubscription = _pendingSubscription;
    if (pendingSubscription != null) {
      unawaited(pendingSubscription.cancel());
    }
    final storeSubscription = _storeSubscription;
    if (storeSubscription != null) {
      unawaited(storeSubscription.cancel());
    }
    final onlineSubscription = _onlineSubscription;
    if (onlineSubscription != null) {
      unawaited(onlineSubscription.cancel());
    }
    _stopTransports();
    if (_ownsDio) _dio.close(force: true);
    super.dispose();
  }

  static Set<SyncCategory> _defaultCategories() => SyncCategory.values
      .where((category) => !category.sensitive)
      .toSet();

  static String _defaultDeviceName() {
    try {
      final host = Platform.localHostname.trim();
      if (host.isNotEmpty) {
        return host.length <= 128 ? host : host.substring(0, 128);
      }
    } catch (_) {
      // Use a stable non-secret fallback below.
    }
    return 'DComic ${Platform.operatingSystem}';
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    throw const _SyncFailure('The sync server returned invalid JSON.');
  }

  static List<dynamic> _list(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is List) return value;
    throw const _SyncFailure('The sync server returned invalid JSON.');
  }

  static String _requiredString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is String && value.isNotEmpty) return value;
    throw const _SyncFailure('The sync server returned invalid JSON.');
  }

  static int _requiredInt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is int) return value;
    throw const _SyncFailure('The sync server returned invalid JSON.');
  }

  static String? _optionalString(Object? value) =>
      value is String && value.isNotEmpty ? value : null;
}

class _ServerTime {
  final int serverTime;
  final Duration roundTrip;

  const _ServerTime(this.serverTime, this.roundTrip);
}

class _SyncFailure implements Exception {
  final String message;

  const _SyncFailure(this.message);
}

