import 'dart:io';

import 'package:dcomic/database/database_common.dart';
import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/entity/chapter_rule.dart';
import 'package:dcomic/utils/chapter_matching_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late DComicDatabase database;

  Future<DComicDatabase> open() => $FloorDComicDatabase
      .databaseBuilder('${directory.path}/rules.db')
      .addMigrations(DatabaseInstance.migrations)
      .addCallback(DatabaseInstance.databaseCallback)
      .build();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('chapter_rules_');
    database = await open();
  });
  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test(
    'fresh database seeds usable chapter and volume equivalence groups',
    () async {
      final matcher = ChapterRuleMatcher(
        await database.chapterRuleDao.loadChapterRules(),
      );
      final chinese = matcher.match('第10话')!;
      final english = matcher.match('Chapter 010')!;
      expect(
        (chinese.groupIndex, chinese.number),
        (english.groupIndex, english.number),
      );
      expect(matcher.match('Vol. 10')!.groupIndex, isNot(chinese.groupIndex));
      expect(matcher.match('第2.50卷')!.number, '2.5');
      expect(matcher.match('番外10'), isNull);
    },
  );

  test('deleting every group stays empty after reopen', () async {
    for (final group in await database.chapterRuleDao.loadChapterRules()) {
      await database.chapterRuleDao.deleteChapterRuleGroup(group.id!);
    }
    await database.close();
    database = await open();
    expect(await database.chapterRuleDao.loadChapterRules(), isEmpty);
    expect(await database.chapterRuleDao.getAllChapterRulePatterns(), isEmpty);
  });

  test('editing a group replaces its patterns and survives reopen', () async {
    final original = (await database.chapterRuleDao.loadChapterRules()).first;
    await database.chapterRuleDao.saveChapterRuleGroup(
      ChapterRuleGroupEntity(original.id, '本篇'),
      [r'^#(\d+(?:\.\d+)?)#$'],
    );
    await database.close();
    database = await open();
    final groups = await database.chapterRuleDao.loadChapterRules();
    expect(groups.singleWhere((g) => g.id == original.id).name, '本篇');
    final matcher = ChapterRuleMatcher(groups);
    expect(matcher.match('#12.50#')!.number, '12.5');
    expect(matcher.match('Chapter 12'), isNull);
    expect(matcher.match('第2卷')!.number, '2');
  });

  test('reset replaces custom rules rather than appending defaults', () async {
    await database.chapterRuleDao.replaceChapterRules(const [
      ChapterRuleGroup(name: 'special', patterns: [r'^Special(\d+)$']),
    ]);
    expect(
      ChapterRuleMatcher(await database.chapterRuleDao.loadChapterRules())
          .match('Special12')!
          .number,
      '12',
    );
    await database.chapterRuleDao.replaceChapterRules(defaultChapterRuleGroups);
    await database.close();
    database = await open();
    final matcher = ChapterRuleMatcher(
      await database.chapterRuleDao.loadChapterRules(),
    );
    expect(matcher.match('Special12'), isNull);
    expect(matcher.match('Chapter12')!.number, '12');
  });

  test('foreign key cascade removes child patterns with their group', () async {
    final group = (await database.chapterRuleDao.loadChapterRules()).first;
    await database.database.delete(
      'ChapterRuleGroupEntity',
      where: 'id = ?',
      whereArgs: [group.id],
    );
    expect(
      await database.database.query(
        'ChapterRulePatternEntity',
        where: 'groupId = ?',
        whereArgs: [group.id],
      ),
      isEmpty,
    );
    final matcher = ChapterRuleMatcher(
      await database.chapterRuleDao.loadChapterRules(),
    );
    expect(matcher.match('Chapter12'), isNull);
    expect(matcher.match('Vol.12')!.number, '12');
  });

  test('failed group write rolls back its whole transaction', () async {
    final group = (await database.chapterRuleDao.loadChapterRules()).first;
    await database.database.execute(
      "CREATE TRIGGER reject_bad_pattern BEFORE INSERT ON ChapterRulePatternEntity WHEN NEW.pattern = 'bad' BEGIN SELECT RAISE(ABORT, 'rejected'); END",
    );
    await expectLater(
      database.chapterRuleDao.saveChapterRuleGroup(
        ChapterRuleGroupEntity(group.id, 'changed'),
        [r'^Other(\d+)$', 'bad'],
      ),
      throwsA(isA<Exception>()),
    );
    final groups = await database.chapterRuleDao.loadChapterRules();
    expect(groups.singleWhere((g) => g.id == group.id).name, group.name);
    final matcher = ChapterRuleMatcher(groups);
    expect(matcher.match('Chapter12')!.number, '12');
    expect(matcher.match('Other12'), isNull);
  });
}
