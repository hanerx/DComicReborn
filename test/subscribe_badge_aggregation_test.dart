import 'dart:async';
import 'dart:io';

import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/entity/comic_mapping.dart';
import 'package:dcomic/database/entity/somic_subscribe_state.dart';
import 'package:dcomic/providers/config_provider.dart';
import 'package:dcomic/providers/page_controllers/comic_favorite_page_controller.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Source extends BaseComicSourceModel {
  _Source(this.id);
  final String id;
  @override
  BaseComicAccountModel? accountModel;
  @override
  ComicSourceEntity get type => ComicSourceEntity(id, id);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Account extends BaseComicAccountModel {
  _Account(this.parent);
  @override
  final BaseComicSourceModel parent;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  final update = DateTime.utc(2026, 9, 10);
  late _Account account;
  late GridItemEntityWithStatus item;

  Future<void> mapping(
    String from,
    String fromId,
    String to,
    String toId,
  ) async {
    await (await DatabaseInstance.instance).comicMappingDao.insertComicMapping(
      ComicMappingEntity(null, fromId, from, to, toId),
    );
  }

  Future<void> seen(String source, String id, DateTime time) async {
    await (await DatabaseInstance.instance).comicSubscribeStateDao
        .insertComicSubscribeState(
          ComicSubscribeStateEntity(null, id, time, source),
        );
  }

  Future<void> enabled(bool value) async {
    final dao = (await DatabaseInstance.instance).configDao;
    final setting = await dao.getOrCreateConfigByKey(
      'AggregateSubscribeBadges',
      value: false,
    );
    setting.set(value);
    await dao.updateConfig(setting);
  }

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('subscribe_badges_');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(directory.path);
  });
  setUp(() async {
    final db = await DatabaseInstance.instance;
    for (final table in [
      'ComicMappingEntity',
      'ComicSubscribeStateEntity',
      'ConfigEntity',
    ]) {
      await db.database.delete(table);
    }
    final source = _Source('a');
    account = _Account(source);
    source.accountModel = account;
    addTearDown(account.dispose);
    addTearDown(source.dispose);
    item = GridItemEntityWithStatus(
      'Book',
      null,
      ImageEntity(ImageType.unknown, ''),
      null,
      update,
      '1',
    );
  });
  tearDownAll(() async {
    await (await DatabaseInstance.instance).close();
    await directory.delete(recursive: true);
  });

  test('loaded favorites react to another source viewing and persisted toggle changes', () async {
    final config = ConfigProvider();
    addTearDown(config.dispose);
    final ready = Completer<void>();
    void initialized() => ready.complete();
    config.addListener(initialized);
    await ready.future;
    config.removeListener(initialized);
    await config.setAggregateSubscribeBadges(true);
    await mapping('b', '2', 'a', '1');
    final controller = ComicFavoritePageController(account.parent);
    addTearDown(controller.dispose);
    controller.data = [item];
    await controller.refreshBadges();
    expect(item.badges, isNotEmpty);

    var changed = Completer<void>();
    controller.addListener(() {
      if (!changed.isCompleted) changed.complete();
    });
    final otherSource = _Source('b');
    final other = _Account(otherSource);
    addTearDown(otherSource.dispose);
    addTearDown(other.dispose);
    await other.addSubscribeState('2');
    await changed.future.timeout(const Duration(seconds: 5));
    expect(item.badges, isEmpty);

    changed = Completer<void>();
    await config.setAggregateSubscribeBadges(false);
    await changed.future.timeout(const Duration(seconds: 5));
    expect(item.badges, isNotEmpty);
    final stored = await (await DatabaseInstance.instance).configDao
        .getConfigByKey('AggregateSubscribeBadges');
    expect(stored!.get<bool>(), isFalse);
  });

  test('opt in aggregates reverse mappings without copying state; disabling restores badge', () async {
    await mapping('b', '2', 'a', '1');
    await seen('b', '2', update);
    await account.refreshSubscribeBadges([item]);
    expect(item.badges, isNotEmpty);
    await enabled(true);
    await account.refreshSubscribeBadges([item]);
    expect(item.badges, isEmpty);
    expect(
      await (await DatabaseInstance.instance).comicSubscribeStateDao
          .getComicSubscribeStateByComicId('1', 'a'),
      isNull,
    );
    await enabled(false);
    await account.refreshSubscribeBadges([item]);
    expect(item.badges, isNotEmpty);
  });

  test(
    'forward mapping retains updates newer than either viewing time',
    () async {
      await enabled(true);
      await mapping('a', '1', 'b', '2');
      await seen('a', '1', update.subtract(const Duration(days: 2)));
      await seen('b', '2', update.subtract(const Duration(days: 1)));
      await account.refreshSubscribeBadges([item]);
      expect(item.badges, isNotEmpty);
      await (await DatabaseInstance.instance).database.delete(
        'ComicSubscribeStateEntity',
      );
      await seen('b', '2', update.add(const Duration(hours: 1)));
      await account.refreshSubscribeBadges([item]);
      expect(item.badges, isEmpty);
    },
  );

  test('explicit reverse unbinding blocks aggregation', () async {
    await enabled(true);
    await mapping('b', '2', 'a', '1');
    await mapping('a', '1', 'b', '');
    await seen('b', '2', update);
    await account.refreshSubscribeBadges([item]);
    expect(item.badges, isNotEmpty);
  });

  test(
    'conflicting or many to one bindings do not merge unrelated books',
    () async {
      await enabled(true);
      await mapping('a', '1', 'b', '2');
      await mapping('a', 'other', 'b', '2');
      await seen('b', '2', update);
      await account.refreshSubscribeBadges([item]);
      expect(item.badges, isNotEmpty);
    },
  );
}
