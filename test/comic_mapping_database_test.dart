import 'dart:io';

import 'package:dcomic/database/database_common.dart';
import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/entity/comic_mapping.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late DComicDatabase database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('comic_mapping_');
    database = await $FloorDComicDatabase
        .databaseBuilder('${directory.path}/mapping.db')
        .addMigrations(DatabaseInstance.migrations)
        .build();
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('canonical edge lookup is symmetric and active edges outrank blocks',
      () async {
    final dao = database.comicMappingDao;
    await dao.insertComicMapping(
      ComicMappingEntity.between('zeta', 'z', 'alpha', 'a'),
    );
    await dao.insertComicMapping(
      ComicMappingEntity.between('alpha', 'a', 'zeta', 'old', blocked: true),
    );

    expect(await dao.lookupComicId('a', 'alpha', 'zeta'), 'z');
    expect(await dao.lookupComicId('z', 'zeta', 'alpha'), 'a');

    final stored = await dao.getAllComicMappingEntity();
    final active = stored.singleWhere((row) => !row.blocked);
    expect(
      (active.providerA, active.comicA, active.providerB, active.comicB),
      ('alpha', 'a', 'zeta', 'z'),
    );
  });

  test('lookup reports suppression and ambiguous active counterparts', () async {
    final dao = database.comicMappingDao;
    await dao.insertComicMapping(
      ComicMappingEntity.between('a', 'book', 'b', '', blocked: true),
    );
    expect(await dao.lookupComicId('book', 'a', 'b'), '');
    expect(await dao.lookupComicId('missing', 'a', 'b'), isNull);

    await dao.insertComicMapping(
      ComicMappingEntity.between('a', 'ambiguous', 'b', 'one'),
    );
    await dao.insertComicMapping(
      ComicMappingEntity.between('a', 'ambiguous', 'b', 'two'),
    );
    expect(await dao.lookupComicId('ambiguous', 'a', 'b'), '');
  });

  test('manual unbind blocks an existing edge from both endpoints', () async {
    final dao = database.comicMappingDao;
    await dao.bindComic('left', 'a', 'b', 'right');

    await dao.bindComic('left', 'a', 'b', '');

    expect(await dao.lookupComicId('left', 'a', 'b'), '');
    expect(await dao.lookupComicId('right', 'b', 'a'), '');
    final rows = await dao.getAllComicMappingEntity();
    expect(rows, hasLength(1));
    expect(rows.single.blocked, isTrue);
    expect(rows.single.comicA, 'left');
    expect(rows.single.comicB, 'right');
  });

  test('manual unbind without an edge stores unknown-counterpart suppression',
      () async {
    final dao = database.comicMappingDao;

    await dao.bindComic('left', 'a', 'b', '');

    final row = (await dao.getAllComicMappingEntity()).single;
    expect(row.blocked, isTrue);
    expect(
      {
        (row.providerA, row.comicA),
        (row.providerB, row.comicB),
      },
      {('a', 'left'), ('b', '')},
    );
    expect(await dao.lookupComicId('left', 'a', 'b'), '');
  });

  test('manual replace blocks conflicts at both endpoints', () async {
    final dao = database.comicMappingDao;
    await dao.bindComic('left', 'a', 'b', 'old-right');
    await dao.bindComic('new-right', 'b', 'a', 'other-left');
    await dao.bindComic('new-right', 'b', 'c', 'third');

    await dao.bindComic('left', 'a', 'b', 'new-right');

    expect(await dao.lookupComicId('left', 'a', 'b'), 'new-right');
    expect(await dao.lookupComicId('new-right', 'b', 'a'), 'left');
    expect(await dao.lookupComicId('old-right', 'b', 'a'), '');
    expect(await dao.lookupComicId('other-left', 'a', 'b'), '');
    expect(await dao.lookupComicId('third', 'c', 'b'), 'new-right');
    final rows = await dao.getAllComicMappingEntity();
    expect(rows.where((row) => !row.blocked), hasLength(2));
    expect(rows.where((row) => row.blocked), hasLength(2));
  });

  test('failed manual replace rolls back displaced-edge blocks', () async {
    final dao = database.comicMappingDao;
    await dao.bindComic('left', 'a', 'b', 'old-right');
    await dao.bindComic('new-right', 'b', 'a', 'other-left');
    await database.database.execute(
      "CREATE TRIGGER reject_new_mapping BEFORE INSERT ON ComicMappingEntity "
      "WHEN NEW.providerA = 'a' AND NEW.comicA = 'left' "
      "AND NEW.providerB = 'b' AND NEW.comicB = 'new-right' "
      "AND NEW.blocked = 0 BEGIN SELECT RAISE(ABORT, 'rejected'); END",
    );

    await expectLater(
      dao.bindComic('left', 'a', 'b', 'new-right'),
      throwsA(anything),
    );

    expect(await dao.lookupComicId('left', 'a', 'b'), 'old-right');
    expect(await dao.lookupComicId('new-right', 'b', 'a'), 'other-left');
    expect(
      (await dao.getAllComicMappingEntity()).where((row) => row.blocked),
      isEmpty,
    );
  });

  test('automatic insert respects caller and counterpart state', () async {
    final dao = database.comicMappingDao;
    expect(
      await dao.insertAutomaticMappingIfAbsent('left', 'a', 'b', 'right'),
      'right',
    );
    expect(await dao.lookupComicId('right', 'b', 'a'), 'left');

    expect(
      await dao.insertAutomaticMappingIfAbsent('left', 'a', 'b', 'other'),
      'right',
      reason: 'the existing caller-side result wins',
    );

    await dao.bindComic('shared', 'b', 'c', 'third');
    expect(
      await dao.insertAutomaticMappingIfAbsent(
        'free-shared',
        'a',
        'b',
        'shared',
      ),
      'shared',
      reason: 'relationships to other providers do not occupy the A/B slot',
    );
    expect(await dao.lookupComicId('third', 'c', 'b'), 'shared');

    await dao.bindComic('occupied', 'b', 'a', 'other');
    expect(
      await dao.insertAutomaticMappingIfAbsent('free', 'a', 'b', 'occupied'),
      '',
    );
    expect(await dao.lookupComicId('free', 'a', 'b'), isNull);

    await dao.bindComic('blocked', 'b', 'a', '');
    expect(
      await dao.insertAutomaticMappingIfAbsent('another', 'a', 'b', 'blocked'),
      '',
    );
    expect(await dao.lookupComicId('another', 'a', 'b'), isNull);
  });

  test('same-provider overrides use symmetric endpoint matching', () async {
    final dao = database.comicMappingDao;

    await dao.bindComic('old', 'same', 'same', 'new');

    expect(await dao.lookupComicId('old', 'same', 'same'), 'new');
    expect(await dao.lookupComicId('new', 'same', 'same'), 'old');
    await dao.bindComic('new', 'same', 'same', '');
    expect(await dao.lookupComicId('old', 'same', 'same'), '');
    expect(await dao.lookupComicId('new', 'same', 'same'), '');
  });
}
