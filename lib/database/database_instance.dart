import 'package:dcomic/database/database_common.dart';
import 'package:floor/floor.dart';

class DatabaseInstance {
  static final List<Migration> migrations = [
    Migration(2, 3, (database) async {
      await database.execute(
          'CREATE TABLE IF NOT EXISTS `ModelConfigEntity` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `key` TEXT NOT NULL, `value` TEXT, `sourceModel` TEXT)');
    }),
    Migration(4, 5, (database) async {
      await database.execute(
          'CREATE TABLE IF NOT EXISTS `ComicSubscribeStateEntity` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `comicId` TEXT NOT NULL, `timestamp` INTEGER, `providerName` TEXT NOT NULL)');
    })
  ];
  static DComicDatabase? _database;

  static Future<DComicDatabase> get instance async {
    _database ??= await $FloorDComicDatabase
        .databaseBuilder('dcomic.db')
        .addMigrations(migrations)
        .build();
    return _database!;
  }
}
