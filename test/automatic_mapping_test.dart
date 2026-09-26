import 'dart:async';
import 'dart:io';

import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/providers/automatic_mapping.dart';
import 'package:dcomic/providers/config_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/page_controllers/comic_favorite_page_controller.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final _cover = ImageEntity(ImageType.unknown, '');
GridItemEntityWithStatus _book(String id, [String title = '漫画']) =>
    GridItemEntityWithStatus(title, null, _cover, null, DateTime(2026), id);
ComicListItemEntity _hit(String id, [String title = '漫畫']) =>
    ComicListItemEntity(title, _cover, {}, null, id);

class _Source extends BaseComicSourceModel {
  _Source(this.id);
  final String id;
  int searches = 0;
  List<ComicListItemEntity> results = [];
  Completer<List<ComicListItemEntity>>? gate;
  Object? error;
  final started = Completer<void>();
  final starts = <DateTime>[];
  @override
  BaseComicAccountModel? accountModel;
  final finishes = <DateTime>[];
  @override
  ComicSourceEntity get type => ComicSourceEntity(id, id);
  @override
  Future<BaseComicDetailModel?> getComicDetail(
    String comicId,
    String title,
  ) async => null;
  @override
  Future<List<ComicListItemEntity>> searchComicDetail(
    String keyword, {
    int page = 0,
  }) async {
    searches++;
    starts.add(DateTime.now());
    if (!started.isCompleted) started.complete();
    try {
      if (error != null) throw error!;
      return gate == null ? results : await gate!.future;
    } finally {
      finishes.add(DateTime.now());
    }
  }
}

class _Account extends BaseComicAccountModel {
  _Account(this.parent, this.books);
  @override
  final BaseComicSourceModel parent;
  final List<GridItemEntity> books;
  int loads = 0;
  @override
  Future<List<GridItemEntity>> getSubscribeComics({int page = 0}) async {
    loads++;
    return books;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late ConfigProvider config;
  late _Source origin;
  late _Source target;
  final queues = <AutomaticMappingQueue>[];
  AutomaticMappingQueue queue([List<BaseComicSourceModel>? sources]) {
    final value = AutomaticMappingQueue(config, sources ?? [origin, target]);
    queues.add(value);
    return value;
  }

  Future<String?> mapping(String id) async =>
      (await (await DatabaseInstance.instance).comicMappingDao
              .getComicMappingByComicId(id, 'origin', 'target'))
          ?.resultComicId;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('automatic_mapping_');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(directory.path);
  });
  setUp(() async {
    final db = await DatabaseInstance.instance;
    await db.database.delete('ConfigEntity');
    await db.database.delete('ComicMappingEntity');
    config = ConfigProvider();
    final initialized = Completer<void>();
    void ready() {
      if (!initialized.isCompleted) initialized.complete();
    }

    config.addListener(ready);
    await initialized.future;
    config.removeListener(ready);
    await config.setAggregateSubscribeBadges(true);
    await config.setAutoMapMissingComics(true);
    origin = _Source('origin');
    target = _Source('target');
  });
  tearDown(() async {
    for (final q in queues) {
      q.dispose();
      await q.idle;
    }
    queues.clear();
    config.dispose();
    origin.dispose();
    target.dispose();
  });
  tearDownAll(() async {
    await (await DatabaseInstance.instance).close();
    await directory.delete(recursive: true);
  });

  test('only a unique equivalent title creates a durable mapping', () async {
    target.results = [_hit('wrong', 'Other')];
    final q = queue();
    q.enqueue(origin, [_book('a')]);
    await q.idle;
    expect(await mapping('a'), isNull);
    target.results = [_hit('one'), _hit('two')];
    q.enqueue(origin, [_book('b')]);
    await q.idle;
    expect(await mapping('b'), isNull);
    target.results = [_hit('correct')];
    q.enqueue(origin, [_book('c')]);
    await q.idle;
    expect(await mapping('c'), 'correct');
  });

  test(
    'attempt caps persist across runs and remain per book and target',
    () async {
      await config.setAutoMapRetryEveryLaunch(false);
      await config.setAutoMapMaxAttempts(1);
      final first = queue();
      first.enqueue(origin, [_book('a')]);
      await first.idle;
      first.dispose();
      final second = queue();
      second.enqueue(origin, [_book('a'), _book('b')]);
      await second.idle;
      expect(target.searches, 2);
      final other = _Source('other');
      addTearDown(other.dispose);
      final third = queue([origin, other]);
      third.enqueue(origin, [_book('a')]);
      await third.idle;
      expect(other.searches, 1);
      await config.setAutoMapRetryEveryLaunch(true);
      final fourth = queue();
      fourth.enqueue(origin, [_book('a')]);
      await fourth.idle;
      expect(target.searches, 3);
      await config.setAutoMapRetryEveryLaunch(false);
      final fifth = queue();
      fifth.enqueue(origin, [_book('a')]);
      await fifth.idle;
      expect(target.searches, 3);
    },
  );

  test(
    'refreshes deduplicate and searches wait after the prior completion',
    () async {
      target.gate = Completer();
      final q = queue();
      q.enqueue(origin, [_book('a'), _book('b')]);
      await target.started.future;
      q.enqueue(origin, [_book('a'), _book('b')]);
      expect(target.searches, 1);
      target.gate!.complete([]);
      await q.idle;
      expect(target.searches, 2);
      expect(
        target.starts[1].difference(target.finishes[0]),
        greaterThanOrEqualTo(const Duration(seconds: 1)),
      );
    },
  );

  test(
    'manual unbinding during search wins and existing unbinds are skipped',
    () async {
      await target.bindComicIdFromSourceModel('skip', '', origin);
      target.gate = Completer();
      final q = queue();
      q.enqueue(origin, [_book('skip'), _book('race')]);
      await target.started.future;
      await target.bindComicIdFromSourceModel('race', '', origin);
      target.gate!.complete([_hit('automatic')]);
      await q.idle;
      expect(target.searches, 1);
      expect(await mapping('race'), '');
    },
  );

  test(
    'disabling stops remaining work and does not count unstarted requests',
    () async {
      target.gate = Completer();
      final q = queue();
      q.enqueue(origin, [_book('a'), _book('b')]);
      await target.started.future;
      await config.setAutoMapMissingComics(false);
      target.gate!.complete([]);
      await q.idle;
      expect(target.searches, 1);
      q.dispose();
      await config.setAutoMapMaxAttempts(1);
      await config.setAutoMapRetryEveryLaunch(false);
      await config.setAutoMapMissingComics(true);
      final next = queue();
      next.enqueue(origin, [_book('b')]);
      await next.idle;
      expect(target.searches, 2);
    },
  );

  test('network errors count once without blocking subsequent books', () async {
    target.error = const SocketException('offline');
    await config.setAutoMapRetryEveryLaunch(false);
    await config.setAutoMapMaxAttempts(1);
    final q = queue();
    q.enqueue(origin, [_book('a'), _book('b')]);
    await q.idle;
    expect(target.searches, 2);
    q.dispose();
    target.error = null;
    final next = queue();
    next.enqueue(origin, [_book('a'), _book('b')]);
    await next.idle;
    expect(target.searches, 2);
  });
  test(
    'config enables already loaded favorites and mapping updates only badges',
    () async {
      await config.setAutoMapMissingComics(false);
      final item = _book('a');
      final account = _Account(origin, [item]);
      origin.accountModel = account;
      addTearDown(account.dispose);
      final other = _Account(target, []);
      addTearDown(other.dispose);
      await other.addSubscribeState('linked');
      target.results = [_hit('linked')];
      final q = queue();
      final controller = ComicFavoritePageController(origin, mappingQueue: q);
      addTearDown(controller.dispose);
      await controller.refresh();
      expect(item.badges, isNotEmpty);
      expect(target.searches, 0);
      await config.setAutoMapMissingComics(true);
      await q.idle;
      await controller.refreshBadges();
      expect(item.badges, isEmpty);
      expect(account.loads, 1);
      expect(controller.data.single, same(item));
    },
  );

  test('reliable reverse bindings require no search and reverse unbind prevents linking', () async {
    await origin.bindComicIdFromSourceModel('linked', 'a', target);
    final q = queue();
    q.enqueue(origin, [_book('a')]);
    await q.idle;
    expect(target.searches, 0);
    await origin.bindComicIdFromSourceModel('blocked', '', target);
    target.results = [_hit('blocked')];
    q.enqueue(origin, [_book('b')]);
    await q.idle;
    expect(await mapping('b'), isNull);
  });

  test('custom interval applies between completed searches', () async {
    await config.setAutoMapIntervalSeconds(2);
    final q = queue();
    q.enqueue(origin, [_book('a'), _book('b')]);
    await q.idle;
    expect(
      target.starts[1].difference(target.finishes[0]),
      greaterThanOrEqualTo(const Duration(seconds: 2)),
    );
  });
  test(
    'disabling during pacing leaves unstarted books eligible this run',
    () async {
      final q = queue();
      q.enqueue(origin, [_book('a'), _book('b')]);
      await target.started.future;
      // The first immediate response finishes before the next event-loop turn.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await config.setAutoMapMissingComics(false);
      await q.idle;
      expect(target.searches, 1);
      await config.setAutoMapMissingComics(true);
      q.enqueue(origin, [_book('b')]);
      await q.idle;
      expect(target.searches, 2);
    },
  );

  test('binding while a request is pacing prevents that search', () async {
    final q = queue();
    q.enqueue(origin, [_book('a'), _book('b')]);
    await target.started.future;
    await target.bindComicIdFromSourceModel('b', '', origin);
    await q.idle;
    expect(target.searches, 1);
  });
}
