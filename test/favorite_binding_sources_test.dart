import 'dart:async';
import 'dart:io';

import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/entity/comic_mapping.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/page_controllers/comic_favorite_page_controller.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final _cover = ImageEntity(ImageType.unknown, '');

GridItemEntityWithStatus _favorite(String id) => GridItemEntityWithStatus(
      'Comic $id',
      null,
      _cover,
      null,
      DateTime.utc(2026),
      id,
    );

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
  _Account(this.parent, this.pages);

  @override
  final BaseComicSourceModel parent;
  final Map<int, List<GridItemEntity>> pages;
  final List<int> requestedPages = [];

  @override
  Future<List<GridItemEntity>> getSubscribeComics({int page = 0}) async {
    requestedPages.add(page);
    return List.of(pages[page] ?? const []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;

  Future<void> addMapping(
    String provider,
    String comic,
    String otherProvider,
    String otherComic, {
    bool blocked = false,
  }) async {
    await (await DatabaseInstance.instance).comicMappingDao.insertComicMapping(
          ComicMappingEntity.between(
            provider,
            comic,
            otherProvider,
            otherComic,
            blocked: blocked,
          ),
        );
  }

  ComicFavoritePageController controllerFor(
    String sourceId,
    Map<int, List<GridItemEntity>> pages, {
    void Function(_Source source)? onSource,
    void Function(_Account account)? onAccount,
  }) {
    final source = _Source(sourceId);
    final account = _Account(source, pages);
    source.accountModel = account;
    onSource?.call(source);
    onAccount?.call(account);
    final controller = ComicFavoritePageController(source);
    addTearDown(controller.dispose);
    addTearDown(account.dispose);
    addTearDown(source.dispose);
    return controller;
  }

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('favorite_sources_');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(directory.path);
  });

  setUp(() async {
    final database = await DatabaseInstance.instance;
    for (final table in [
      'ComicMappingEntity',
      'ComicSubscribeStateEntity',
      'ConfigEntity',
    ]) {
      await database.database.delete(table);
    }
  });

  tearDownAll(() async {
    await (await DatabaseInstance.instance).close();
    await directory.delete(recursive: true);
  });

  test('returns current source first and direct bindings from either endpoint',
      () async {
    await addMapping('a', '1', 'z', '9');
    await addMapping('c', '3', 'a', '1');
    await addMapping('b', '2', 'a', '1');

    final fromA = _favorite('1');
    final aController = controllerFor('a', {
      0: [fromA],
    });
    await aController.refresh();
    expect(aController.sourceIdsFor(fromA), ['a', 'b', 'c', 'z']);

    final fromZ = _favorite('9');
    final zController = controllerFor('z', {
      0: [fromZ],
    });
    await zController.refresh();
    expect(zController.sourceIdsFor(fromZ), ['z', 'a']);

    final plain = GridItemEntity('Plain', null, _cover, null);
    expect(aController.sourceIdsFor(plain), ['a']);
  });

  test('excludes blocked, empty, and ambiguous endpoint mappings', () async {
    await addMapping('a', '1', 'b', 'valid');
    await addMapping('a', '1', 'c', 'blocked', blocked: true);
    await addMapping('a', '1', 'd', 'first');
    await addMapping('a', '1', 'd', 'second');
    await addMapping('a', '1', 'e', 'shared');
    await addMapping('a', 'other', 'e', 'shared');
    await addMapping('a', '1', 'f', '');

    final item = _favorite('1');
    final controller = controllerFor('a', {
      0: [item],
    });
    await controller.refresh();

    expect(controller.sourceIdsFor(item), ['a', 'b']);
  });

  test('does not infer transitive source bindings', () async {
    await addMapping('a', '1', 'b', '2');
    await addMapping('b', '2', 'c', '3');

    final fromA = _favorite('1');
    final aController = controllerFor('a', {
      0: [fromA],
    });
    await aController.refresh();
    expect(aController.sourceIdsFor(fromA), ['a', 'b']);

    final fromB = _favorite('2');
    final bController = controllerFor('b', {
      0: [fromB],
    });
    await bController.refresh();
    expect(bController.sourceIdsFor(fromB), ['b', 'a', 'c']);
  });

  test('reconciles binding sources for initial and paginated favorites',
      () async {
    await addMapping('a', 'first', 'b', 'bound-first');
    await addMapping('a', 'second', 'c', 'bound-second');
    final first = _favorite('first');
    final second = _favorite('second');
    late _Account account;
    final controller = controllerFor(
      'a',
      {
        0: [first],
        1: [second],
      },
      onAccount: (value) => account = value,
    );

    await controller.refresh();
    expect(controller.sourceIdsFor(first), ['a', 'b']);

    await controller.load();
    expect(controller.sourceIdsFor(first), ['a', 'b']);
    expect(controller.sourceIdsFor(second), ['a', 'c']);
    expect(account.requestedPages, [0, 1]);
  });

  test('live bind and unbind notifications reconcile without a network reload',
      () async {
    final item = _favorite('1');
    late _Source origin;
    late _Account account;
    final controller = controllerFor(
      'a',
      {
        0: [item],
      },
      onSource: (value) => origin = value,
      onAccount: (value) => account = value,
    );
    final target = _Source('b');
    addTearDown(target.dispose);

    await controller.refresh();
    expect(controller.sourceIdsFor(item), ['a']);

    var reconciled = Completer<void>();
    controller.addListener(() {
      if (!reconciled.isCompleted &&
          controller.sourceIdsFor(item).length == 2) {
        reconciled.complete();
      }
    });
    await target.bindComicIdFromSourceModel('1', 'bound', origin);
    await reconciled.future.timeout(const Duration(seconds: 5));
    expect(controller.sourceIdsFor(item), ['a', 'b']);
    expect(account.requestedPages, [0]);

    reconciled = Completer<void>();
    controller.addListener(() {
      if (!reconciled.isCompleted &&
          controller.sourceIdsFor(item).length == 1) {
        reconciled.complete();
      }
    });
    await target.bindComicIdFromSourceModel('1', '', origin);
    await reconciled.future.timeout(const Duration(seconds: 5));
    expect(controller.sourceIdsFor(item), ['a']);
    expect(account.requestedPages, [0]);
  });
}
