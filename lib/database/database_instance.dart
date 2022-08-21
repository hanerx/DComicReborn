import 'package:dcomic/database/database_common.dart';

class DatabaseInstance{
  static DComicDatabase? _database;
  
  static Future<DComicDatabase> get instance async {
    _database??=await $FloorDComicDatabase.databaseBuilder('dcomic.db').build();
    return _database!;
  }
}