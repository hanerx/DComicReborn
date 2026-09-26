import 'package:dcomic/utils/chapter_matching_rules.dart';
import 'package:floor_community/floor.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

@Entity()
class ChapterRuleGroupEntity {
  @PrimaryKey(autoGenerate: true)
  final int? id;

  final String name;

  ChapterRuleGroupEntity(this.id, this.name);
}

@Entity(
  indices: [
    Index(value: ['groupId']),
  ],
  foreignKeys: [
    ForeignKey(
      childColumns: ['groupId'],
      parentColumns: ['id'],
      entity: ChapterRuleGroupEntity,
      onDelete: ForeignKeyAction.cascade,
    ),
  ],
)
class ChapterRulePatternEntity {
  @PrimaryKey(autoGenerate: true)
  final int? id;

  final int groupId;

  final String pattern;

  ChapterRulePatternEntity(this.id, this.groupId, this.pattern);
}

@dao
abstract class ChapterRuleDao {
  @Query('SELECT * FROM ChapterRuleGroupEntity ORDER BY id ASC')
  Future<List<ChapterRuleGroupEntity>> getAllChapterRuleGroups();

  @Query('SELECT * FROM ChapterRulePatternEntity ORDER BY id ASC')
  Future<List<ChapterRulePatternEntity>> getAllChapterRulePatterns();

  @transaction
  Future<List<ChapterRuleGroup>> loadChapterRules() async {
    final groups = await getAllChapterRuleGroups();
    final patterns = await getAllChapterRulePatterns();
    final patternsByGroup = <int, List<String>>{};
    for (final pattern in patterns) {
      patternsByGroup
          .putIfAbsent(pattern.groupId, () => [])
          .add(pattern.pattern);
    }
    return [
      for (final group in groups)
        ChapterRuleGroup(
          id: group.id,
          name: group.name,
          patterns: patternsByGroup[group.id] ?? const [],
        ),
    ];
  }

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<int> insertChapterRuleGroup(ChapterRuleGroupEntity entity);

  @Update(onConflict: OnConflictStrategy.replace)
  Future<void> updateChapterRuleGroup(ChapterRuleGroupEntity entity);

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<int> insertChapterRulePattern(ChapterRulePatternEntity entity);

  @Query('DELETE FROM ChapterRulePatternEntity WHERE `groupId` = :groupId')
  Future<void> deleteChapterRulePatternsByGroupId(int groupId);

  @Query('DELETE FROM ChapterRulePatternEntity')
  Future<void> deleteAllChapterRulePatterns();

  @Query('DELETE FROM ChapterRuleGroupEntity')
  Future<void> deleteAllChapterRuleGroups();

  /// 新增分组（[ChapterRuleGroupEntity.id] 为空）或更新分组名并整体替换其规则。
  @transaction
  Future<void> saveChapterRuleGroup(
    ChapterRuleGroupEntity group,
    List<String> patterns,
  ) async {
    final int groupId;
    if (group.id == null) {
      groupId = await insertChapterRuleGroup(group);
    } else {
      groupId = group.id!;
      await updateChapterRuleGroup(group);
      await deleteChapterRulePatternsByGroupId(groupId);
    }
    for (final pattern in patterns) {
      await insertChapterRulePattern(
        ChapterRulePatternEntity(null, groupId, pattern),
      );
    }
  }

  /// 删除分组及其全部规则（事务内先删子行再删父行）。
  @transaction
  Future<void> deleteChapterRuleGroup(int id) async {
    await deleteChapterRulePatternsByGroupId(id);
    await deleteChapterRuleGroupById(id);
  }

  @Query('DELETE FROM ChapterRuleGroupEntity WHERE `id` = :id')
  Future<void> deleteChapterRuleGroupById(int id);

  /// 清空后按给定顺序重建全部分组与规则。
  @transaction
  Future<void> replaceChapterRules(List<ChapterRuleGroup> seeds) async {
    await deleteAllChapterRulePatterns();
    await deleteAllChapterRuleGroups();
    for (final seed in seeds) {
      final groupId = await insertChapterRuleGroup(
        ChapterRuleGroupEntity(null, seed.name),
      );
      for (final pattern in seed.patterns) {
        await insertChapterRulePattern(
          ChapterRulePatternEntity(null, groupId, pattern),
        );
      }
    }
  }
}

/// 建表语句与 Floor 生成器的输出保持一致，供 v5 -> v6 迁移复用。
const List<String> chapterRuleTableStatements = [
  'CREATE TABLE IF NOT EXISTS `ChapterRuleGroupEntity` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `name` TEXT NOT NULL)',
  'CREATE TABLE IF NOT EXISTS `ChapterRulePatternEntity` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `groupId` INTEGER NOT NULL, `pattern` TEXT NOT NULL, FOREIGN KEY (`groupId`) REFERENCES `ChapterRuleGroupEntity` (`id`) ON UPDATE NO ACTION ON DELETE CASCADE)',
  'CREATE INDEX IF NOT EXISTS `index_ChapterRulePatternEntity_groupId` ON `ChapterRulePatternEntity` (`groupId`)',
];

Future<void> createChapterRuleTables(sqflite.DatabaseExecutor database) async {
  for (final statement in chapterRuleTableStatements) {
    await database.execute(statement);
  }
}

/// 把 [defaultChapterRuleGroups] 写入空表，供新装回调与 v5 -> v6 迁移共用。
Future<void> seedChapterRuleDefaults(sqflite.DatabaseExecutor database) async {
  for (final group in defaultChapterRuleGroups) {
    final groupId = await database.insert('ChapterRuleGroupEntity', {
      'name': group.name,
    });
    for (final pattern in group.patterns) {
      await database.insert('ChapterRulePatternEntity', {
        'groupId': groupId,
        'pattern': pattern,
      });
    }
  }
}
