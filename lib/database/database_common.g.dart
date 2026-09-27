// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_common.dart';

// **************************************************************************
// FloorGenerator
// **************************************************************************

abstract class $DComicDatabaseBuilderContract {
  /// Adds migrations to the builder.
  $DComicDatabaseBuilderContract addMigrations(List<Migration> migrations);

  /// Adds a database [Callback] to the builder.
  $DComicDatabaseBuilderContract addCallback(Callback callback);

  /// Creates the database and initializes it.
  Future<DComicDatabase> build();
}

// ignore: avoid_classes_with_only_static_members
class $FloorDComicDatabase {
  /// Creates a database builder for a persistent database.
  /// Once a database is built, you should keep a reference to it and re-use it.
  static $DComicDatabaseBuilderContract databaseBuilder(String name) =>
      _$DComicDatabaseBuilder(name);

  /// Creates a database builder for an in memory database.
  /// Information stored in an in memory database disappears when the process is killed.
  /// Once a database is built, you should keep a reference to it and re-use it.
  static $DComicDatabaseBuilderContract inMemoryDatabaseBuilder() =>
      _$DComicDatabaseBuilder(null);
}

class _$DComicDatabaseBuilder implements $DComicDatabaseBuilderContract {
  _$DComicDatabaseBuilder(this.name);

  final String? name;

  final List<Migration> _migrations = [];

  Callback? _callback;

  @override
  $DComicDatabaseBuilderContract addMigrations(List<Migration> migrations) {
    _migrations.addAll(migrations);
    return this;
  }

  @override
  $DComicDatabaseBuilderContract addCallback(Callback callback) {
    _callback = callback;
    return this;
  }

  @override
  Future<DComicDatabase> build() async {
    final path = name != null
        ? await sqfliteDatabaseFactory.getDatabasePath(name!)
        : ':memory:';
    final database = _$DComicDatabase();
    database.database = await database.open(path, _migrations, _callback);
    return database;
  }
}

class _$DComicDatabase extends DComicDatabase {
  _$DComicDatabase([StreamController<String>? listener]) {
    changeListener = listener ?? StreamController<String>.broadcast();
  }

  ConfigDao? _configDaoInstance;

  ComicHistoryDao? _comicHistoryDaoInstance;

  CookieDao? _cookieDaoInstance;

  ModelConfigDao? _modelConfigDaoInstance;

  ComicMappingDao? _comicMappingDaoInstance;

  ComicSubscribeStateDao? _comicSubscribeStateDaoInstance;

  ChapterRuleDao? _chapterRuleDaoInstance;

  Future<sqflite.Database> open(
    String path,
    List<Migration> migrations, [
    Callback? callback,
  ]) async {
    final databaseOptions = sqflite.OpenDatabaseOptions(
      version: 7,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
        await callback?.onConfigure?.call(database);
      },
      onOpen: (database) async {
        await callback?.onOpen?.call(database);
      },
      onUpgrade: (database, startVersion, endVersion) async {
        await MigrationAdapter.runMigrations(
          database,
          startVersion,
          endVersion,
          migrations,
        );

        await callback?.onUpgrade?.call(database, startVersion, endVersion);
      },
      onCreate: (database, version) async {
        await database.execute(
          'CREATE TABLE IF NOT EXISTS `ConfigEntity` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `key` TEXT NOT NULL, `value` TEXT)',
        );
        await database.execute(
          'CREATE TABLE IF NOT EXISTS `ComicHistoryEntity` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `comicId` TEXT NOT NULL, `title` TEXT NOT NULL, `cover` TEXT NOT NULL, `coverType` INTEGER NOT NULL, `lastChapterTitle` TEXT NOT NULL, `lastChapterId` TEXT NOT NULL, `timestamp` INTEGER, `providerName` TEXT NOT NULL)',
        );
        await database.execute(
          'CREATE TABLE IF NOT EXISTS `CookieEntity` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `key` TEXT NOT NULL, `value` TEXT NOT NULL)',
        );
        await database.execute(
          'CREATE TABLE IF NOT EXISTS `ModelConfigEntity` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `key` TEXT NOT NULL, `value` TEXT, `sourceModel` TEXT)',
        );
        await database.execute(
          'CREATE TABLE IF NOT EXISTS `ComicMappingEntity` (`providerA` TEXT NOT NULL, `comicA` TEXT NOT NULL, `providerB` TEXT NOT NULL, `comicB` TEXT NOT NULL, `blocked` INTEGER NOT NULL, PRIMARY KEY (`providerA`, `comicA`, `providerB`, `comicB`))',
        );
        await database.execute(
          'CREATE TABLE IF NOT EXISTS `ComicSubscribeStateEntity` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `comicId` TEXT NOT NULL, `timestamp` INTEGER, `providerName` TEXT NOT NULL)',
        );
        await database.execute(
          'CREATE TABLE IF NOT EXISTS `ChapterRuleGroupEntity` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `name` TEXT NOT NULL)',
        );
        await database.execute(
          'CREATE TABLE IF NOT EXISTS `ChapterRulePatternEntity` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `groupId` INTEGER NOT NULL, `pattern` TEXT NOT NULL, FOREIGN KEY (`groupId`) REFERENCES `ChapterRuleGroupEntity` (`id`) ON UPDATE NO ACTION ON DELETE CASCADE)',
        );
        await database.execute(
          'CREATE INDEX `index_ComicMappingEntity_providerB_comicB_providerA` ON `ComicMappingEntity` (`providerB`, `comicB`, `providerA`)',
        );
        await database.execute(
          'CREATE INDEX `index_ChapterRulePatternEntity_groupId` ON `ChapterRulePatternEntity` (`groupId`)',
        );

        await callback?.onCreate?.call(database, version);
      },
    );
    return sqfliteDatabaseFactory.openDatabase(path, options: databaseOptions);
  }

  @override
  ConfigDao get configDao {
    return _configDaoInstance ??= _$ConfigDao(database, changeListener);
  }

  @override
  ComicHistoryDao get comicHistoryDao {
    return _comicHistoryDaoInstance ??= _$ComicHistoryDao(
      database,
      changeListener,
    );
  }

  @override
  CookieDao get cookieDao {
    return _cookieDaoInstance ??= _$CookieDao(database, changeListener);
  }

  @override
  ModelConfigDao get modelConfigDao {
    return _modelConfigDaoInstance ??= _$ModelConfigDao(
      database,
      changeListener,
    );
  }

  @override
  ComicMappingDao get comicMappingDao {
    return _comicMappingDaoInstance ??= _$ComicMappingDao(
      database,
      changeListener,
    );
  }

  @override
  ComicSubscribeStateDao get comicSubscribeStateDao {
    return _comicSubscribeStateDaoInstance ??= _$ComicSubscribeStateDao(
      database,
      changeListener,
    );
  }

  @override
  ChapterRuleDao get chapterRuleDao {
    return _chapterRuleDaoInstance ??= _$ChapterRuleDao(
      database,
      changeListener,
    );
  }
}

class _$ConfigDao extends ConfigDao {
  _$ConfigDao(this.database, this.changeListener)
    : _queryAdapter = QueryAdapter(database),
      _configEntityInsertionAdapter = InsertionAdapter(
        database,
        'ConfigEntity',
        (ConfigEntity item) => <String, Object?>{
          'id': item.id,
          'key': item.key,
          'value': item.value,
        },
      ),
      _configEntityUpdateAdapter = UpdateAdapter(
        database,
        'ConfigEntity',
        ['id'],
        (ConfigEntity item) => <String, Object?>{
          'id': item.id,
          'key': item.key,
          'value': item.value,
        },
      );

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<ConfigEntity> _configEntityInsertionAdapter;

  final UpdateAdapter<ConfigEntity> _configEntityUpdateAdapter;

  @override
  Future<List<ConfigEntity>> getAllConfig() async {
    return _queryAdapter.queryList(
      'SELECT * FROM ConfigEntity',
      mapper: (Map<String, Object?> row) => ConfigEntity(
        row['id'] as int?,
        row['key'] as String,
        row['value'] as String?,
      ),
    );
  }

  @override
  Future<ConfigEntity?> getConfigByKey(String key) async {
    return _queryAdapter.query(
      'SELECT * FROM ConfigEntity WHERE `key` = ?1',
      mapper: (Map<String, Object?> row) => ConfigEntity(
        row['id'] as int?,
        row['key'] as String,
        row['value'] as String?,
      ),
      arguments: [key],
    );
  }

  @override
  Future<void> insertConfig(ConfigEntity configEntity) async {
    await _configEntityInsertionAdapter.insert(
      configEntity,
      OnConflictStrategy.abort,
    );
  }

  @override
  Future<void> updateConfig(ConfigEntity configEntity) async {
    await _configEntityUpdateAdapter.update(
      configEntity,
      OnConflictStrategy.replace,
    );
  }

  @override
  Future<void> setConfigByKey(String key, String? value) async {
    if (database is sqflite.Transaction) {
      await super.setConfigByKey(key, value);
    } else {
      await (database as sqflite.Database).transaction<void>((
        transaction,
      ) async {
        final transactionDatabase = _$DComicDatabase(changeListener)
          ..database = transaction;
        await transactionDatabase.configDao.setConfigByKey(key, value);
      });
    }
  }
}

class _$ComicHistoryDao extends ComicHistoryDao {
  _$ComicHistoryDao(this.database, this.changeListener)
    : _queryAdapter = QueryAdapter(database),
      _comicHistoryEntityInsertionAdapter = InsertionAdapter(
        database,
        'ComicHistoryEntity',
        (ComicHistoryEntity item) => <String, Object?>{
          'id': item.id,
          'comicId': item.comicId,
          'title': item.title,
          'cover': item.cover,
          'coverType': _imageTypeConverter.encode(item.coverType),
          'lastChapterTitle': item.lastChapterTitle,
          'lastChapterId': item.lastChapterId,
          'timestamp': _dateTimeNullableConverter.encode(item.timestamp),
          'providerName': item.providerName,
        },
      ),
      _comicHistoryEntityUpdateAdapter = UpdateAdapter(
        database,
        'ComicHistoryEntity',
        ['id'],
        (ComicHistoryEntity item) => <String, Object?>{
          'id': item.id,
          'comicId': item.comicId,
          'title': item.title,
          'cover': item.cover,
          'coverType': _imageTypeConverter.encode(item.coverType),
          'lastChapterTitle': item.lastChapterTitle,
          'lastChapterId': item.lastChapterId,
          'timestamp': _dateTimeNullableConverter.encode(item.timestamp),
          'providerName': item.providerName,
        },
      );

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<ComicHistoryEntity>
  _comicHistoryEntityInsertionAdapter;

  final UpdateAdapter<ComicHistoryEntity> _comicHistoryEntityUpdateAdapter;

  @override
  Future<List<ComicHistoryEntity>> getAllComicHistoryEntity() async {
    return _queryAdapter.queryList(
      'SELECT * FROM ComicHistoryEntity',
      mapper: (Map<String, Object?> row) => ComicHistoryEntity(
        row['id'] as int?,
        row['comicId'] as String,
        row['title'] as String,
        row['cover'] as String,
        _imageTypeConverter.decode(row['coverType'] as int),
        row['lastChapterTitle'] as String,
        row['lastChapterId'] as String,
        _dateTimeNullableConverter.decode(row['timestamp'] as int?),
        row['providerName'] as String,
      ),
    );
  }

  @override
  Future<ComicHistoryEntity?> getComicHistoryByComicId(
    String comicId,
    String providerName,
  ) async {
    return _queryAdapter.query(
      'SELECT * FROM ComicHistoryEntity WHERE `comicId`= ?1 AND `providerName`= ?2',
      mapper: (Map<String, Object?> row) => ComicHistoryEntity(
        row['id'] as int?,
        row['comicId'] as String,
        row['title'] as String,
        row['cover'] as String,
        _imageTypeConverter.decode(row['coverType'] as int),
        row['lastChapterTitle'] as String,
        row['lastChapterId'] as String,
        _dateTimeNullableConverter.decode(row['timestamp'] as int?),
        row['providerName'] as String,
      ),
      arguments: [comicId, providerName],
    );
  }

  @override
  Future<List<ComicHistoryEntity>> getComicHistoryByProvider(
    String providerName,
  ) async {
    return _queryAdapter.queryList(
      'SELECT * FROM ComicHistoryEntity WHERE `providerName`= ?1 GROUP BY comicId',
      mapper: (Map<String, Object?> row) => ComicHistoryEntity(
        row['id'] as int?,
        row['comicId'] as String,
        row['title'] as String,
        row['cover'] as String,
        _imageTypeConverter.decode(row['coverType'] as int),
        row['lastChapterTitle'] as String,
        row['lastChapterId'] as String,
        _dateTimeNullableConverter.decode(row['timestamp'] as int?),
        row['providerName'] as String,
      ),
      arguments: [providerName],
    );
  }

  @override
  Future<void> insertComicHistory(ComicHistoryEntity comicHistoryEntity) async {
    await _comicHistoryEntityInsertionAdapter.insert(
      comicHistoryEntity,
      OnConflictStrategy.replace,
    );
  }

  @override
  Future<void> updateComicHistory(ComicHistoryEntity comicHistoryEntity) async {
    await _comicHistoryEntityUpdateAdapter.update(
      comicHistoryEntity,
      OnConflictStrategy.replace,
    );
  }
}

class _$CookieDao extends CookieDao {
  _$CookieDao(this.database, this.changeListener)
    : _queryAdapter = QueryAdapter(database),
      _cookieEntityInsertionAdapter = InsertionAdapter(
        database,
        'CookieEntity',
        (CookieEntity item) => <String, Object?>{
          'id': item.id,
          'key': item.key,
          'value': item.value,
        },
      ),
      _cookieEntityUpdateAdapter = UpdateAdapter(
        database,
        'CookieEntity',
        ['id'],
        (CookieEntity item) => <String, Object?>{
          'id': item.id,
          'key': item.key,
          'value': item.value,
        },
      );

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<CookieEntity> _cookieEntityInsertionAdapter;

  final UpdateAdapter<CookieEntity> _cookieEntityUpdateAdapter;

  @override
  Future<List<CookieEntity>> getAllCookies() async {
    return _queryAdapter.queryList(
      'SELECT * FROM CookieEntity',
      mapper: (Map<String, Object?> row) => CookieEntity(
        row['id'] as int?,
        row['key'] as String,
        row['value'] as String,
      ),
    );
  }

  @override
  Future<CookieEntity?> getCookieByKey(String key) async {
    return _queryAdapter.query(
      'SELECT * FROM CookieEntity WHERE `key` = ?1',
      mapper: (Map<String, Object?> row) => CookieEntity(
        row['id'] as int?,
        row['key'] as String,
        row['value'] as String,
      ),
      arguments: [key],
    );
  }

  @override
  Future<void> deleteCookie(String key) async {
    await _queryAdapter.queryNoReturn(
      'DELETE FROM CookieEntity WHERE `key` = ?1',
      arguments: [key],
    );
  }

  @override
  Future<void> insertCookie(CookieEntity cookieEntity) async {
    await _cookieEntityInsertionAdapter.insert(
      cookieEntity,
      OnConflictStrategy.replace,
    );
  }

  @override
  Future<void> updateCookie(CookieEntity cookieEntity) async {
    await _cookieEntityUpdateAdapter.update(
      cookieEntity,
      OnConflictStrategy.replace,
    );
  }
}

class _$ModelConfigDao extends ModelConfigDao {
  _$ModelConfigDao(this.database, this.changeListener)
    : _queryAdapter = QueryAdapter(database),
      _modelConfigEntityInsertionAdapter = InsertionAdapter(
        database,
        'ModelConfigEntity',
        (ModelConfigEntity item) => <String, Object?>{
          'id': item.id,
          'key': item.key,
          'value': item.value,
          'sourceModel': item.sourceModel,
        },
      ),
      _modelConfigEntityUpdateAdapter = UpdateAdapter(
        database,
        'ModelConfigEntity',
        ['id'],
        (ModelConfigEntity item) => <String, Object?>{
          'id': item.id,
          'key': item.key,
          'value': item.value,
          'sourceModel': item.sourceModel,
        },
      );

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<ModelConfigEntity> _modelConfigEntityInsertionAdapter;

  final UpdateAdapter<ModelConfigEntity> _modelConfigEntityUpdateAdapter;

  @override
  Future<List<ModelConfigEntity>> getAllConfig() async {
    return _queryAdapter.queryList(
      'SELECT * FROM ModelConfigEntity',
      mapper: (Map<String, Object?> row) => ModelConfigEntity(
        row['id'] as int?,
        row['key'] as String,
        row['value'] as String?,
        row['sourceModel'] as String?,
      ),
    );
  }

  @override
  Future<ModelConfigEntity?> getConfigByKeyAndModel(
    String key,
    String sourceModel,
  ) async {
    return _queryAdapter.query(
      'SELECT * FROM ModelConfigEntity WHERE `key` = ?1 AND `sourceModel` = ?2',
      mapper: (Map<String, Object?> row) => ModelConfigEntity(
        row['id'] as int?,
        row['key'] as String,
        row['value'] as String?,
        row['sourceModel'] as String?,
      ),
      arguments: [key, sourceModel],
    );
  }

  @override
  Future<void> insertConfig(ModelConfigEntity configEntity) async {
    await _modelConfigEntityInsertionAdapter.insert(
      configEntity,
      OnConflictStrategy.replace,
    );
  }

  @override
  Future<void> updateConfig(ModelConfigEntity configEntity) async {
    await _modelConfigEntityUpdateAdapter.update(
      configEntity,
      OnConflictStrategy.replace,
    );
  }
}

class _$ComicMappingDao extends ComicMappingDao {
  _$ComicMappingDao(this.database, this.changeListener)
    : _queryAdapter = QueryAdapter(database),
      _comicMappingEntityInsertionAdapter = InsertionAdapter(
        database,
        'ComicMappingEntity',
        (ComicMappingEntity item) => <String, Object?>{
          'providerA': item.providerA,
          'comicA': item.comicA,
          'providerB': item.providerB,
          'comicB': item.comicB,
          'blocked': item.blocked ? 1 : 0,
        },
      );

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<ComicMappingEntity>
  _comicMappingEntityInsertionAdapter;

  @override
  Future<List<ComicMappingEntity>> getAllComicMappingEntity() async {
    return _queryAdapter.queryList(
      'SELECT * FROM ComicMappingEntity',
      mapper: (Map<String, Object?> row) => ComicMappingEntity(
        row['providerA'] as String,
        row['comicA'] as String,
        row['providerB'] as String,
        row['comicB'] as String,
        (row['blocked'] as int) != 0,
      ),
    );
  }

  @override
  Future<List<ComicMappingEntity>> getIncidentComicMappings(
    String comicId,
    String provider,
    String otherProvider,
  ) async {
    return _queryAdapter.queryList(
      'SELECT * FROM ComicMappingEntity WHERE (`providerA` = ?2 AND `comicA` = ?1 AND `providerB` = ?3) OR (`providerB` = ?2 AND `comicB` = ?1 AND `providerA` = ?3)',
      mapper: (Map<String, Object?> row) => ComicMappingEntity(
        row['providerA'] as String,
        row['comicA'] as String,
        row['providerB'] as String,
        row['comicB'] as String,
        (row['blocked'] as int) != 0,
      ),
      arguments: [comicId, provider, otherProvider],
    );
  }

  @override
  Future<void> insertComicMapping(ComicMappingEntity comicMappingEntity) async {
    await _comicMappingEntityInsertionAdapter.insert(
      comicMappingEntity,
      OnConflictStrategy.replace,
    );
  }

  @override
  Future<void> bindComic(
    String comicId,
    String provider,
    String otherProvider,
    String otherComicId,
  ) async {
    if (database is sqflite.Transaction) {
      await super.bindComic(comicId, provider, otherProvider, otherComicId);
    } else {
      await (database as sqflite.Database).transaction<void>((
        transaction,
      ) async {
        final transactionDatabase = _$DComicDatabase(changeListener)
          ..database = transaction;
        await transactionDatabase.comicMappingDao.bindComic(
          comicId,
          provider,
          otherProvider,
          otherComicId,
        );
      });
    }
  }

  @override
  Future<String> insertAutomaticMappingIfAbsent(
    String comicId,
    String provider,
    String otherProvider,
    String otherComicId,
  ) async {
    if (database is sqflite.Transaction) {
      return super.insertAutomaticMappingIfAbsent(
        comicId,
        provider,
        otherProvider,
        otherComicId,
      );
    } else {
      return (database as sqflite.Database).transaction<String>((
        transaction,
      ) async {
        final transactionDatabase = _$DComicDatabase(changeListener)
          ..database = transaction;
        return transactionDatabase.comicMappingDao
            .insertAutomaticMappingIfAbsent(
              comicId,
              provider,
              otherProvider,
              otherComicId,
            );
      });
    }
  }
}

class _$ComicSubscribeStateDao extends ComicSubscribeStateDao {
  _$ComicSubscribeStateDao(this.database, this.changeListener)
    : _queryAdapter = QueryAdapter(database),
      _comicSubscribeStateEntityInsertionAdapter = InsertionAdapter(
        database,
        'ComicSubscribeStateEntity',
        (ComicSubscribeStateEntity item) => <String, Object?>{
          'id': item.id,
          'comicId': item.comicId,
          'timestamp': _dateTimeNullableConverter.encode(item.timestamp),
          'providerName': item.providerName,
        },
      ),
      _comicSubscribeStateEntityUpdateAdapter = UpdateAdapter(
        database,
        'ComicSubscribeStateEntity',
        ['id'],
        (ComicSubscribeStateEntity item) => <String, Object?>{
          'id': item.id,
          'comicId': item.comicId,
          'timestamp': _dateTimeNullableConverter.encode(item.timestamp),
          'providerName': item.providerName,
        },
      );

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<ComicSubscribeStateEntity>
  _comicSubscribeStateEntityInsertionAdapter;

  final UpdateAdapter<ComicSubscribeStateEntity>
  _comicSubscribeStateEntityUpdateAdapter;

  @override
  Future<List<ComicSubscribeStateEntity>>
  getAllComicSubscribeStateEntity() async {
    return _queryAdapter.queryList(
      'SELECT * FROM ComicSubscribeStateEntity',
      mapper: (Map<String, Object?> row) => ComicSubscribeStateEntity(
        row['id'] as int?,
        row['comicId'] as String,
        _dateTimeNullableConverter.decode(row['timestamp'] as int?),
        row['providerName'] as String,
      ),
    );
  }

  @override
  Future<ComicSubscribeStateEntity?> getComicSubscribeStateByComicId(
    String comicId,
    String providerName,
  ) async {
    return _queryAdapter.query(
      'SELECT * FROM ComicSubscribeStateEntity WHERE `comicId`= ?1 AND `providerName`= ?2',
      mapper: (Map<String, Object?> row) => ComicSubscribeStateEntity(
        row['id'] as int?,
        row['comicId'] as String,
        _dateTimeNullableConverter.decode(row['timestamp'] as int?),
        row['providerName'] as String,
      ),
      arguments: [comicId, providerName],
    );
  }

  @override
  Future<List<ComicSubscribeStateEntity>> getComicSubscribeStateByProvider(
    String providerName,
  ) async {
    return _queryAdapter.queryList(
      'SELECT * FROM ComicSubscribeStateEntity WHERE `providerName`= ?1 GROUP BY comicId',
      mapper: (Map<String, Object?> row) => ComicSubscribeStateEntity(
        row['id'] as int?,
        row['comicId'] as String,
        _dateTimeNullableConverter.decode(row['timestamp'] as int?),
        row['providerName'] as String,
      ),
      arguments: [providerName],
    );
  }

  @override
  Future<void> insertComicSubscribeState(
    ComicSubscribeStateEntity comicSubscribeStateEntity,
  ) async {
    await _comicSubscribeStateEntityInsertionAdapter.insert(
      comicSubscribeStateEntity,
      OnConflictStrategy.replace,
    );
  }

  @override
  Future<void> updateComicSubscribeState(
    ComicSubscribeStateEntity comicSubscribeStateEntity,
  ) async {
    await _comicSubscribeStateEntityUpdateAdapter.update(
      comicSubscribeStateEntity,
      OnConflictStrategy.replace,
    );
  }
}

class _$ChapterRuleDao extends ChapterRuleDao {
  _$ChapterRuleDao(this.database, this.changeListener)
    : _queryAdapter = QueryAdapter(database),
      _chapterRuleGroupEntityInsertionAdapter = InsertionAdapter(
        database,
        'ChapterRuleGroupEntity',
        (ChapterRuleGroupEntity item) => <String, Object?>{
          'id': item.id,
          'name': item.name,
        },
      ),
      _chapterRulePatternEntityInsertionAdapter = InsertionAdapter(
        database,
        'ChapterRulePatternEntity',
        (ChapterRulePatternEntity item) => <String, Object?>{
          'id': item.id,
          'groupId': item.groupId,
          'pattern': item.pattern,
        },
      ),
      _chapterRuleGroupEntityUpdateAdapter = UpdateAdapter(
        database,
        'ChapterRuleGroupEntity',
        ['id'],
        (ChapterRuleGroupEntity item) => <String, Object?>{
          'id': item.id,
          'name': item.name,
        },
      );

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<ChapterRuleGroupEntity>
  _chapterRuleGroupEntityInsertionAdapter;

  final InsertionAdapter<ChapterRulePatternEntity>
  _chapterRulePatternEntityInsertionAdapter;

  final UpdateAdapter<ChapterRuleGroupEntity>
  _chapterRuleGroupEntityUpdateAdapter;

  @override
  Future<List<ChapterRuleGroupEntity>> getAllChapterRuleGroups() async {
    return _queryAdapter.queryList(
      'SELECT * FROM ChapterRuleGroupEntity ORDER BY id ASC',
      mapper: (Map<String, Object?> row) =>
          ChapterRuleGroupEntity(row['id'] as int?, row['name'] as String),
    );
  }

  @override
  Future<List<ChapterRulePatternEntity>> getAllChapterRulePatterns() async {
    return _queryAdapter.queryList(
      'SELECT * FROM ChapterRulePatternEntity ORDER BY id ASC',
      mapper: (Map<String, Object?> row) => ChapterRulePatternEntity(
        row['id'] as int?,
        row['groupId'] as int,
        row['pattern'] as String,
      ),
    );
  }

  @override
  Future<void> deleteChapterRulePatternsByGroupId(int groupId) async {
    await _queryAdapter.queryNoReturn(
      'DELETE FROM ChapterRulePatternEntity WHERE `groupId` = ?1',
      arguments: [groupId],
    );
  }

  @override
  Future<void> deleteAllChapterRulePatterns() async {
    await _queryAdapter.queryNoReturn('DELETE FROM ChapterRulePatternEntity');
  }

  @override
  Future<void> deleteAllChapterRuleGroups() async {
    await _queryAdapter.queryNoReturn('DELETE FROM ChapterRuleGroupEntity');
  }

  @override
  Future<void> deleteChapterRuleGroupById(int id) async {
    await _queryAdapter.queryNoReturn(
      'DELETE FROM ChapterRuleGroupEntity WHERE `id` = ?1',
      arguments: [id],
    );
  }

  @override
  Future<int> insertChapterRuleGroup(ChapterRuleGroupEntity entity) {
    return _chapterRuleGroupEntityInsertionAdapter.insertAndReturnId(
      entity,
      OnConflictStrategy.replace,
    );
  }

  @override
  Future<int> insertChapterRulePattern(ChapterRulePatternEntity entity) {
    return _chapterRulePatternEntityInsertionAdapter.insertAndReturnId(
      entity,
      OnConflictStrategy.replace,
    );
  }

  @override
  Future<void> updateChapterRuleGroup(ChapterRuleGroupEntity entity) async {
    await _chapterRuleGroupEntityUpdateAdapter.update(
      entity,
      OnConflictStrategy.replace,
    );
  }

  @override
  Future<List<ChapterRuleGroup>> loadChapterRules() async {
    if (database is sqflite.Transaction) {
      return super.loadChapterRules();
    } else {
      return (database as sqflite.Database).transaction<List<ChapterRuleGroup>>(
        (transaction) async {
          final transactionDatabase = _$DComicDatabase(changeListener)
            ..database = transaction;
          return transactionDatabase.chapterRuleDao.loadChapterRules();
        },
      );
    }
  }

  @override
  Future<void> saveChapterRuleGroup(
    ChapterRuleGroupEntity group,
    List<String> patterns,
  ) async {
    if (database is sqflite.Transaction) {
      await super.saveChapterRuleGroup(group, patterns);
    } else {
      await (database as sqflite.Database).transaction<void>((
        transaction,
      ) async {
        final transactionDatabase = _$DComicDatabase(changeListener)
          ..database = transaction;
        await transactionDatabase.chapterRuleDao.saveChapterRuleGroup(
          group,
          patterns,
        );
      });
    }
  }

  @override
  Future<void> deleteChapterRuleGroup(int id) async {
    if (database is sqflite.Transaction) {
      await super.deleteChapterRuleGroup(id);
    } else {
      await (database as sqflite.Database).transaction<void>((
        transaction,
      ) async {
        final transactionDatabase = _$DComicDatabase(changeListener)
          ..database = transaction;
        await transactionDatabase.chapterRuleDao.deleteChapterRuleGroup(id);
      });
    }
  }

  @override
  Future<void> replaceChapterRules(List<ChapterRuleGroup> seeds) async {
    if (database is sqflite.Transaction) {
      await super.replaceChapterRules(seeds);
    } else {
      await (database as sqflite.Database).transaction<void>((
        transaction,
      ) async {
        final transactionDatabase = _$DComicDatabase(changeListener)
          ..database = transaction;
        await transactionDatabase.chapterRuleDao.replaceChapterRules(seeds);
      });
    }
  }
}

// ignore_for_file: unused_element
final _dateTimeConverter = DateTimeConverter();
final _dateTimeNullableConverter = DateTimeNullableConverter();
final _imageTypeConverter = ImageTypeConverter();
final _imageTypeNullableConverter = ImageTypeNullableConverter();
