import 'package:dcomic/database/converter/datetime_converter.dart';
import 'package:dcomic/database/converter/image_type_converter.dart';
import 'package:dcomic/database/entity/comic_history.dart';
import 'package:dcomic/database/entity/chapter_rule.dart';
import 'package:dcomic/database/entity/comic_mapping.dart';
import 'package:dcomic/database/entity/config.dart';
import 'package:dcomic/database/entity/cookie.dart';
import 'package:dcomic/database/entity/model_config.dart';
import 'package:dcomic/database/entity/somic_subscribe_state.dart';
import 'package:dcomic/utils/chapter_matching_rules.dart';

import 'dart:async';

import 'package:floor_community/floor.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

part 'database_common.g.dart';

@Database(
  version: 7,
  entities: [
    ConfigEntity,
    ComicHistoryEntity,
    CookieEntity,
    ModelConfigEntity,
    ComicMappingEntity,
    ComicSubscribeStateEntity,
    ChapterRuleGroupEntity,
    ChapterRulePatternEntity,
  ],
)
@TypeConverters([
  DateTimeConverter,
  DateTimeNullableConverter,
  ImageTypeConverter,
  ImageTypeNullableConverter,
])
abstract class DComicDatabase extends FloorDatabase {
  sqflite.Database? _syncDatabaseOverride;

  @override
  sqflite.DatabaseExecutor get database =>
      _syncDatabaseOverride ?? super.database;

  /// Installed once, before DAOs capture their executor. Floor's transaction
  /// instances still receive their own transaction executor through the setter.
  void installDatabaseProxy(sqflite.Database value) {
    if (_syncDatabaseOverride != null) {
      throw StateError('The database executor is already installed');
    }
    _syncDatabaseOverride = value;
  }

  ConfigDao get configDao;

  ComicHistoryDao get comicHistoryDao;

  CookieDao get cookieDao;

  ModelConfigDao get modelConfigDao;

  ComicMappingDao get comicMappingDao;

  ComicSubscribeStateDao get comicSubscribeStateDao;

  ChapterRuleDao get chapterRuleDao;
}
