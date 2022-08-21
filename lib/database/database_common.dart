import 'package:dcomic/database/entity/config.dart';
import 'dart:async';
import 'package:floor/floor.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

part 'database_common.g.dart';

@Database(version: 1, entities: [ConfigEntity])
abstract class DComicDatabase extends FloorDatabase {
  ConfigDao get configDao;
}