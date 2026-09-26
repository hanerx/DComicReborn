import 'package:dcomic/database/database_common.dart';
import 'package:dcomic/database/entity/chapter_rule.dart';
import 'package:floor_community/floor.dart';

class DatabaseInstance {
  static final List<Migration> migrations = [
    Migration(2, 3, (database) async {
      await database.execute(
        'CREATE TABLE IF NOT EXISTS `ModelConfigEntity` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `key` TEXT NOT NULL, `value` TEXT, `sourceModel` TEXT)',
      );
    }),
    Migration(4, 5, (database) async {
      await database.execute(
        'CREATE TABLE IF NOT EXISTS `ComicSubscribeStateEntity` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `comicId` TEXT NOT NULL, `timestamp` INTEGER, `providerName` TEXT NOT NULL)',
      );
    }),
    Migration(5, 6, (database) async {
      await createChapterRuleTables(database);
      await seedChapterRuleDefaults(database);
    }),
  ];

  /// 新装数据库建表完成后写入默认章节匹配分组；升级场景由 5 -> 6 迁移负责。
  static final Callback databaseCallback = Callback(
    onCreate: (database, _) => seedChapterRuleDefaults(database),
  );

  static DComicDatabase? _database;

  static Future<DComicDatabase> get instance async {
    _database ??= await $FloorDComicDatabase
        .databaseBuilder('dcomic.db')
        .addMigrations(migrations)
        .addCallback(databaseCallback)
        .build();
    return _database!;
  }
}
