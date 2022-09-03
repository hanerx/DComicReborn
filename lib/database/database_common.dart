import 'package:dcomic/database/converter/datetime_converter.dart';
import 'package:dcomic/database/converter/image_type_converter.dart';
import 'package:dcomic/database/entity/comic_history.dart';
import 'package:dcomic/database/entity/config.dart';
import 'dart:async';
import 'package:floor/floor.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

part 'database_common.g.dart';

@Database(version: 1, entities: [ConfigEntity,ComicHistoryEntity])
@TypeConverters([DateTimeConverter,DateTimeNullableConverter,ImageTypeConverter,ImageTypeNullableConverter])
abstract class DComicDatabase extends FloorDatabase {
  ConfigDao get configDao;

  ComicHistoryDao get comicHistoryDao;
}