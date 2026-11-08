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

  DownloadTaskDao? _downloadTaskDaoInstance;

  OfflineComicDao? _offlineComicDaoInstance;

  Future<sqflite.Database> open(
    String path,
    List<Migration> migrations, [
    Callback? callback,
  ]) async {
    final databaseOptions = sqflite.OpenDatabaseOptions(
      version: 12,
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
          'CREATE TABLE IF NOT EXISTS `ComicHistoryEntity` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `comicId` TEXT NOT NULL, `title` TEXT NOT NULL, `cover` TEXT NOT NULL, `coverType` INTEGER NOT NULL, `lastChapterTitle` TEXT NOT NULL, `lastChapterId` TEXT NOT NULL, `lastPage` INTEGER NOT NULL, `timestamp` INTEGER, `providerName` TEXT NOT NULL)',
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
          'CREATE TABLE IF NOT EXISTS `DownloadTaskEntity` (`id` TEXT NOT NULL, `url` TEXT NOT NULL, `headersJson` TEXT NOT NULL, `relativePath` TEXT NOT NULL, `canonicalPath` TEXT NOT NULL, `taskGroup` TEXT NOT NULL, `expectedBytes` INTEGER, `sha256Hex` TEXT, `strategy` TEXT NOT NULL, `effectiveStrategy` TEXT NOT NULL, `chunks` INTEGER NOT NULL, `cacheKey` TEXT, `displayName` TEXT, `state` TEXT NOT NULL, `generation` INTEGER NOT NULL, `engineTaskId` TEXT, `resumeRequested` INTEGER NOT NULL, `bytesReceived` INTEGER NOT NULL, `totalBytes` INTEGER, `error` TEXT, `createdAt` INTEGER NOT NULL, `completedAt` INTEGER, PRIMARY KEY (`id`))',
        );
        await database.execute(
          'CREATE TABLE IF NOT EXISTS `DownloadTaskEpochEntity` (`id` TEXT NOT NULL, `nextGeneration` INTEGER NOT NULL, PRIMARY KEY (`id`))',
        );
        await database.execute(
          'CREATE TABLE IF NOT EXISTS `OfflineComicEntity` (`sourceId` TEXT NOT NULL, `comicId` TEXT NOT NULL, `rawTitle` TEXT NOT NULL, `catalogJson` TEXT NOT NULL, `coverRelativePath` TEXT, `remoteCoverUrl` TEXT, `isLongComic` INTEGER NOT NULL, PRIMARY KEY (`sourceId`, `comicId`))',
        );
        await database.execute(
          'CREATE TABLE IF NOT EXISTS `OfflineChapterEntity` (`sourceId` TEXT NOT NULL, `comicId` TEXT NOT NULL, `chapterId` TEXT NOT NULL, `rawTitle` TEXT NOT NULL, `groupName` TEXT NOT NULL, `sortIndex` INTEGER NOT NULL, `manifestGeneration` INTEGER NOT NULL, `operationGeneration` INTEGER NOT NULL, `manifestSignature` TEXT NOT NULL, `state` TEXT NOT NULL, `error` TEXT, `completedAt` INTEGER, FOREIGN KEY (`sourceId`, `comicId`) REFERENCES `OfflineComicEntity` (`sourceId`, `comicId`) ON UPDATE NO ACTION ON DELETE CASCADE, PRIMARY KEY (`sourceId`, `comicId`, `chapterId`))',
        );
        await database.execute(
          'CREATE TABLE IF NOT EXISTS `OfflinePageEntity` (`sourceId` TEXT NOT NULL, `comicId` TEXT NOT NULL, `chapterId` TEXT NOT NULL, `manifestGeneration` INTEGER NOT NULL, `pageIndex` INTEGER NOT NULL, `taskId` TEXT NOT NULL, `relativePath` TEXT NOT NULL, `resourceUrl` TEXT NOT NULL, `headersJson` TEXT NOT NULL, `cacheKey` TEXT, `expectedBytes` INTEGER, `submitted` INTEGER NOT NULL, FOREIGN KEY (`sourceId`, `comicId`, `chapterId`) REFERENCES `OfflineChapterEntity` (`sourceId`, `comicId`, `chapterId`) ON UPDATE NO ACTION ON DELETE CASCADE, PRIMARY KEY (`sourceId`, `comicId`, `chapterId`, `manifestGeneration`, `pageIndex`))',
        );
        await database.execute(
          'CREATE INDEX `index_ComicMappingEntity_providerB_comicB_providerA` ON `ComicMappingEntity` (`providerB`, `comicB`, `providerA`)',
        );
        await database.execute(
          'CREATE INDEX `index_ChapterRulePatternEntity_groupId` ON `ChapterRulePatternEntity` (`groupId`)',
        );
        await database.execute(
          'CREATE INDEX `index_DownloadTaskEntity_state` ON `DownloadTaskEntity` (`state`)',
        );
        await database.execute(
          'CREATE UNIQUE INDEX `index_DownloadTaskEntity_engineTaskId` ON `DownloadTaskEntity` (`engineTaskId`)',
        );
        await database.execute(
          'CREATE UNIQUE INDEX `index_DownloadTaskEntity_canonicalPath` ON `DownloadTaskEntity` (`canonicalPath`)',
        );
        await database.execute(
          'CREATE INDEX `index_OfflineChapterEntity_state_completedAt` ON `OfflineChapterEntity` (`state`, `completedAt`)',
        );
        await database.execute(
          'CREATE UNIQUE INDEX `index_OfflinePageEntity_taskId` ON `OfflinePageEntity` (`taskId`)',
        );
        await database.execute(
          'CREATE INDEX `index_OfflinePageEntity_sourceId_comicId_chapterId_manifestGeneration` ON `OfflinePageEntity` (`sourceId`, `comicId`, `chapterId`, `manifestGeneration`)',
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

  @override
  DownloadTaskDao get downloadTaskDao {
    return _downloadTaskDaoInstance ??= _$DownloadTaskDao(
      database,
      changeListener,
    );
  }

  @override
  OfflineComicDao get offlineComicDao {
    return _offlineComicDaoInstance ??= _$OfflineComicDao(
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
          'lastPage': item.lastPage,
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
          'lastPage': item.lastPage,
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
        row['lastPage'] as int,
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
        row['lastPage'] as int,
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
      'SELECT * FROM ComicHistoryEntity WHERE `providerName`= ?1 GROUP BY comicId ORDER BY timestamp DESC',
      mapper: (Map<String, Object?> row) => ComicHistoryEntity(
        row['id'] as int?,
        row['comicId'] as String,
        row['title'] as String,
        row['cover'] as String,
        _imageTypeConverter.decode(row['coverType'] as int),
        row['lastChapterTitle'] as String,
        row['lastChapterId'] as String,
        row['lastPage'] as int,
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

class _$DownloadTaskDao extends DownloadTaskDao {
  _$DownloadTaskDao(this.database, this.changeListener)
    : _queryAdapter = QueryAdapter(database),
      _downloadTaskEntityInsertionAdapter = InsertionAdapter(
        database,
        'DownloadTaskEntity',
        (DownloadTaskEntity item) => <String, Object?>{
          'id': item.id,
          'url': item.url,
          'headersJson': item.headersJson,
          'relativePath': item.relativePath,
          'canonicalPath': item.canonicalPath,
          'taskGroup': item.taskGroup,
          'expectedBytes': item.expectedBytes,
          'sha256Hex': item.sha256Hex,
          'strategy': item.strategy,
          'effectiveStrategy': item.effectiveStrategy,
          'chunks': item.chunks,
          'cacheKey': item.cacheKey,
          'displayName': item.displayName,
          'state': item.state,
          'generation': item.generation,
          'engineTaskId': item.engineTaskId,
          'resumeRequested': item.resumeRequested ? 1 : 0,
          'bytesReceived': item.bytesReceived,
          'totalBytes': item.totalBytes,
          'error': item.error,
          'createdAt': item.createdAt,
          'completedAt': item.completedAt,
        },
      ),
      _downloadTaskEpochEntityInsertionAdapter = InsertionAdapter(
        database,
        'DownloadTaskEpochEntity',
        (DownloadTaskEpochEntity item) => <String, Object?>{
          'id': item.id,
          'nextGeneration': item.nextGeneration,
        },
      ),
      _downloadTaskEntityUpdateAdapter = UpdateAdapter(
        database,
        'DownloadTaskEntity',
        ['id'],
        (DownloadTaskEntity item) => <String, Object?>{
          'id': item.id,
          'url': item.url,
          'headersJson': item.headersJson,
          'relativePath': item.relativePath,
          'canonicalPath': item.canonicalPath,
          'taskGroup': item.taskGroup,
          'expectedBytes': item.expectedBytes,
          'sha256Hex': item.sha256Hex,
          'strategy': item.strategy,
          'effectiveStrategy': item.effectiveStrategy,
          'chunks': item.chunks,
          'cacheKey': item.cacheKey,
          'displayName': item.displayName,
          'state': item.state,
          'generation': item.generation,
          'engineTaskId': item.engineTaskId,
          'resumeRequested': item.resumeRequested ? 1 : 0,
          'bytesReceived': item.bytesReceived,
          'totalBytes': item.totalBytes,
          'error': item.error,
          'createdAt': item.createdAt,
          'completedAt': item.completedAt,
        },
      ),
      _downloadTaskEntityDeletionAdapter = DeletionAdapter(
        database,
        'DownloadTaskEntity',
        ['id'],
        (DownloadTaskEntity item) => <String, Object?>{
          'id': item.id,
          'url': item.url,
          'headersJson': item.headersJson,
          'relativePath': item.relativePath,
          'canonicalPath': item.canonicalPath,
          'taskGroup': item.taskGroup,
          'expectedBytes': item.expectedBytes,
          'sha256Hex': item.sha256Hex,
          'strategy': item.strategy,
          'effectiveStrategy': item.effectiveStrategy,
          'chunks': item.chunks,
          'cacheKey': item.cacheKey,
          'displayName': item.displayName,
          'state': item.state,
          'generation': item.generation,
          'engineTaskId': item.engineTaskId,
          'resumeRequested': item.resumeRequested ? 1 : 0,
          'bytesReceived': item.bytesReceived,
          'totalBytes': item.totalBytes,
          'error': item.error,
          'createdAt': item.createdAt,
          'completedAt': item.completedAt,
        },
      );

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<DownloadTaskEntity>
  _downloadTaskEntityInsertionAdapter;

  final InsertionAdapter<DownloadTaskEpochEntity>
  _downloadTaskEpochEntityInsertionAdapter;

  final UpdateAdapter<DownloadTaskEntity> _downloadTaskEntityUpdateAdapter;

  final DeletionAdapter<DownloadTaskEntity> _downloadTaskEntityDeletionAdapter;

  @override
  Future<DownloadTaskEntity?> findDownloadTask(String id) async {
    return _queryAdapter.query(
      'SELECT * FROM DownloadTaskEntity WHERE id = ?1',
      mapper: (Map<String, Object?> row) => DownloadTaskEntity(
        id: row['id'] as String,
        url: row['url'] as String,
        headersJson: row['headersJson'] as String,
        relativePath: row['relativePath'] as String,
        canonicalPath: row['canonicalPath'] as String,
        taskGroup: row['taskGroup'] as String,
        expectedBytes: row['expectedBytes'] as int?,
        sha256Hex: row['sha256Hex'] as String?,
        strategy: row['strategy'] as String,
        effectiveStrategy: row['effectiveStrategy'] as String,
        chunks: row['chunks'] as int,
        cacheKey: row['cacheKey'] as String?,
        displayName: row['displayName'] as String?,
        state: row['state'] as String,
        generation: row['generation'] as int,
        engineTaskId: row['engineTaskId'] as String?,
        resumeRequested: (row['resumeRequested'] as int) != 0,
        bytesReceived: row['bytesReceived'] as int,
        totalBytes: row['totalBytes'] as int?,
        error: row['error'] as String?,
        createdAt: row['createdAt'] as int,
        completedAt: row['completedAt'] as int?,
      ),
      arguments: [id],
    );
  }

  @override
  Future<DownloadTaskEntity?> findDownloadTaskByCanonicalPath(
    String canonicalPath,
  ) async {
    return _queryAdapter.query(
      'SELECT * FROM DownloadTaskEntity WHERE canonicalPath = ?1',
      mapper: (Map<String, Object?> row) => DownloadTaskEntity(
        id: row['id'] as String,
        url: row['url'] as String,
        headersJson: row['headersJson'] as String,
        relativePath: row['relativePath'] as String,
        canonicalPath: row['canonicalPath'] as String,
        taskGroup: row['taskGroup'] as String,
        expectedBytes: row['expectedBytes'] as int?,
        sha256Hex: row['sha256Hex'] as String?,
        strategy: row['strategy'] as String,
        effectiveStrategy: row['effectiveStrategy'] as String,
        chunks: row['chunks'] as int,
        cacheKey: row['cacheKey'] as String?,
        displayName: row['displayName'] as String?,
        state: row['state'] as String,
        generation: row['generation'] as int,
        engineTaskId: row['engineTaskId'] as String?,
        resumeRequested: (row['resumeRequested'] as int) != 0,
        bytesReceived: row['bytesReceived'] as int,
        totalBytes: row['totalBytes'] as int?,
        error: row['error'] as String?,
        createdAt: row['createdAt'] as int,
        completedAt: row['completedAt'] as int?,
      ),
      arguments: [canonicalPath],
    );
  }

  @override
  Future<DownloadTaskEpochEntity?> findDownloadTaskEpoch(String id) async {
    return _queryAdapter.query(
      'SELECT * FROM DownloadTaskEpochEntity WHERE id = ?1',
      mapper: (Map<String, Object?> row) => DownloadTaskEpochEntity(
        row['id'] as String,
        row['nextGeneration'] as int,
      ),
      arguments: [id],
    );
  }

  @override
  Future<List<DownloadTaskEntity>> listDownloadTasks() async {
    return _queryAdapter.queryList(
      'SELECT * FROM DownloadTaskEntity ORDER BY createdAt DESC, id ASC',
      mapper: (Map<String, Object?> row) => DownloadTaskEntity(
        id: row['id'] as String,
        url: row['url'] as String,
        headersJson: row['headersJson'] as String,
        relativePath: row['relativePath'] as String,
        canonicalPath: row['canonicalPath'] as String,
        taskGroup: row['taskGroup'] as String,
        expectedBytes: row['expectedBytes'] as int?,
        sha256Hex: row['sha256Hex'] as String?,
        strategy: row['strategy'] as String,
        effectiveStrategy: row['effectiveStrategy'] as String,
        chunks: row['chunks'] as int,
        cacheKey: row['cacheKey'] as String?,
        displayName: row['displayName'] as String?,
        state: row['state'] as String,
        generation: row['generation'] as int,
        engineTaskId: row['engineTaskId'] as String?,
        resumeRequested: (row['resumeRequested'] as int) != 0,
        bytesReceived: row['bytesReceived'] as int,
        totalBytes: row['totalBytes'] as int?,
        error: row['error'] as String?,
        createdAt: row['createdAt'] as int,
        completedAt: row['completedAt'] as int?,
      ),
    );
  }

  @override
  Future<void> insertDownloadTaskRow(DownloadTaskEntity entity) async {
    await _downloadTaskEntityInsertionAdapter.insert(
      entity,
      OnConflictStrategy.abort,
    );
  }

  @override
  Future<void> upsertDownloadTaskEpoch(DownloadTaskEpochEntity entity) async {
    await _downloadTaskEpochEntityInsertionAdapter.insert(
      entity,
      OnConflictStrategy.replace,
    );
  }

  @override
  Future<int> updateDownloadTask(DownloadTaskEntity entity) {
    return _downloadTaskEntityUpdateAdapter.updateAndReturnChangedRows(
      entity,
      OnConflictStrategy.abort,
    );
  }

  @override
  Future<int> deleteDownloadTask(DownloadTaskEntity entity) {
    return _downloadTaskEntityDeletionAdapter.deleteAndReturnChangedRows(
      entity,
    );
  }

  @override
  Future<void> insertFreshDownloadTask(DownloadTaskEntity entity) async {
    if (database is sqflite.Transaction) {
      await super.insertFreshDownloadTask(entity);
    } else {
      await (database as sqflite.Database).transaction<void>((
        transaction,
      ) async {
        final transactionDatabase = _$DComicDatabase(changeListener)
          ..database = transaction;
        await transactionDatabase.downloadTaskDao.insertFreshDownloadTask(
          entity,
        );
      });
    }
  }

  @override
  Future<bool> transitionDownloadTask(
    String id,
    int generation,
    String fromState,
    String toState,
    String? error,
    int? completedAt,
  ) async {
    if (database is sqflite.Transaction) {
      return super.transitionDownloadTask(
        id,
        generation,
        fromState,
        toState,
        error,
        completedAt,
      );
    } else {
      return (database as sqflite.Database).transaction<bool>((
        transaction,
      ) async {
        final transactionDatabase = _$DComicDatabase(changeListener)
          ..database = transaction;
        return transactionDatabase.downloadTaskDao.transitionDownloadTask(
          id,
          generation,
          fromState,
          toState,
          error,
          completedAt,
        );
      });
    }
  }

  @override
  Future<bool> bindDownloadEngine(
    String id,
    int generation,
    String engineTaskId,
  ) async {
    if (database is sqflite.Transaction) {
      return super.bindDownloadEngine(id, generation, engineTaskId);
    } else {
      return (database as sqflite.Database).transaction<bool>((
        transaction,
      ) async {
        final transactionDatabase = _$DComicDatabase(changeListener)
          ..database = transaction;
        return transactionDatabase.downloadTaskDao.bindDownloadEngine(
          id,
          generation,
          engineTaskId,
        );
      });
    }
  }

  @override
  Future<bool> updateDownloadProgress(
    String id,
    int generation,
    int bytesReceived,
    int? totalBytes,
  ) async {
    if (database is sqflite.Transaction) {
      return super.updateDownloadProgress(
        id,
        generation,
        bytesReceived,
        totalBytes,
      );
    } else {
      return (database as sqflite.Database).transaction<bool>((
        transaction,
      ) async {
        final transactionDatabase = _$DComicDatabase(changeListener)
          ..database = transaction;
        return transactionDatabase.downloadTaskDao.updateDownloadProgress(
          id,
          generation,
          bytesReceived,
          totalBytes,
        );
      });
    }
  }

  @override
  Future<bool> requestDownloadResume(String id, int generation) async {
    if (database is sqflite.Transaction) {
      return super.requestDownloadResume(id, generation);
    } else {
      return (database as sqflite.Database).transaction<bool>((
        transaction,
      ) async {
        final transactionDatabase = _$DComicDatabase(changeListener)
          ..database = transaction;
        return transactionDatabase.downloadTaskDao.requestDownloadResume(
          id,
          generation,
        );
      });
    }
  }

  @override
  Future<DownloadTaskEntity> cancelDownloadTask(String id) async {
    if (database is sqflite.Transaction) {
      return super.cancelDownloadTask(id);
    } else {
      return (database as sqflite.Database).transaction<DownloadTaskEntity>((
        transaction,
      ) async {
        final transactionDatabase = _$DComicDatabase(changeListener)
          ..database = transaction;
        return transactionDatabase.downloadTaskDao.cancelDownloadTask(id);
      });
    }
  }

  @override
  Future<List<DownloadTaskEntity>> cancelDownloadGroup(String taskGroup) async {
    if (database is sqflite.Transaction) {
      return super.cancelDownloadGroup(taskGroup);
    } else {
      return (database as sqflite.Database)
          .transaction<List<DownloadTaskEntity>>((transaction) async {
            final transactionDatabase = _$DComicDatabase(changeListener)
              ..database = transaction;
            return transactionDatabase.downloadTaskDao.cancelDownloadGroup(
              taskGroup,
            );
          });
    }
  }

  @override
  Future<bool> restartDownloadTask(
    String id,
    int generation,
    String fromState,
    String? reason,
  ) async {
    if (database is sqflite.Transaction) {
      return super.restartDownloadTask(id, generation, fromState, reason);
    } else {
      return (database as sqflite.Database).transaction<bool>((
        transaction,
      ) async {
        final transactionDatabase = _$DComicDatabase(changeListener)
          ..database = transaction;
        return transactionDatabase.downloadTaskDao.restartDownloadTask(
          id,
          generation,
          fromState,
          reason,
        );
      });
    }
  }

  @override
  Future<bool> fallBackToSingleConnection(
    String id,
    int generation,
    String reason,
  ) async {
    if (database is sqflite.Transaction) {
      return super.fallBackToSingleConnection(id, generation, reason);
    } else {
      return (database as sqflite.Database).transaction<bool>((
        transaction,
      ) async {
        final transactionDatabase = _$DComicDatabase(changeListener)
          ..database = transaction;
        return transactionDatabase.downloadTaskDao.fallBackToSingleConnection(
          id,
          generation,
          reason,
        );
      });
    }
  }

  @override
  Future<void> invalidateDownloadTask(String id, String reason) async {
    if (database is sqflite.Transaction) {
      await super.invalidateDownloadTask(id, reason);
    } else {
      await (database as sqflite.Database).transaction<void>((
        transaction,
      ) async {
        final transactionDatabase = _$DComicDatabase(changeListener)
          ..database = transaction;
        await transactionDatabase.downloadTaskDao.invalidateDownloadTask(
          id,
          reason,
        );
      });
    }
  }

  @override
  Future<bool> deleteDownloadTaskIfGeneration(String id, int generation) async {
    if (database is sqflite.Transaction) {
      return super.deleteDownloadTaskIfGeneration(id, generation);
    } else {
      return (database as sqflite.Database).transaction<bool>((
        transaction,
      ) async {
        final transactionDatabase = _$DComicDatabase(changeListener)
          ..database = transaction;
        return transactionDatabase.downloadTaskDao
            .deleteDownloadTaskIfGeneration(id, generation);
      });
    }
  }
}

class _$OfflineComicDao extends OfflineComicDao {
  _$OfflineComicDao(this.database, this.changeListener)
    : _queryAdapter = QueryAdapter(database),
      _offlineComicEntityInsertionAdapter = InsertionAdapter(
        database,
        'OfflineComicEntity',
        (OfflineComicEntity item) => <String, Object?>{
          'sourceId': item.sourceId,
          'comicId': item.comicId,
          'rawTitle': item.rawTitle,
          'catalogJson': item.catalogJson,
          'coverRelativePath': item.coverRelativePath,
          'remoteCoverUrl': item.remoteCoverUrl,
          'isLongComic': item.isLongComic ? 1 : 0,
        },
      ),
      _offlineChapterEntityInsertionAdapter = InsertionAdapter(
        database,
        'OfflineChapterEntity',
        (OfflineChapterEntity item) => <String, Object?>{
          'sourceId': item.sourceId,
          'comicId': item.comicId,
          'chapterId': item.chapterId,
          'rawTitle': item.rawTitle,
          'groupName': item.groupName,
          'sortIndex': item.sortIndex,
          'manifestGeneration': item.manifestGeneration,
          'operationGeneration': item.operationGeneration,
          'manifestSignature': item.manifestSignature,
          'state': item.state,
          'error': item.error,
          'completedAt': _dateTimeNullableConverter.encode(item.completedAt),
        },
      ),
      _offlinePageEntityInsertionAdapter = InsertionAdapter(
        database,
        'OfflinePageEntity',
        (OfflinePageEntity item) => <String, Object?>{
          'sourceId': item.sourceId,
          'comicId': item.comicId,
          'chapterId': item.chapterId,
          'manifestGeneration': item.manifestGeneration,
          'pageIndex': item.pageIndex,
          'taskId': item.taskId,
          'relativePath': item.relativePath,
          'resourceUrl': item.resourceUrl,
          'headersJson': item.headersJson,
          'cacheKey': item.cacheKey,
          'expectedBytes': item.expectedBytes,
          'submitted': item.submitted ? 1 : 0,
        },
      ),
      _offlineComicEntityUpdateAdapter = UpdateAdapter(
        database,
        'OfflineComicEntity',
        ['sourceId', 'comicId'],
        (OfflineComicEntity item) => <String, Object?>{
          'sourceId': item.sourceId,
          'comicId': item.comicId,
          'rawTitle': item.rawTitle,
          'catalogJson': item.catalogJson,
          'coverRelativePath': item.coverRelativePath,
          'remoteCoverUrl': item.remoteCoverUrl,
          'isLongComic': item.isLongComic ? 1 : 0,
        },
      );

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<OfflineComicEntity>
  _offlineComicEntityInsertionAdapter;

  final InsertionAdapter<OfflineChapterEntity>
  _offlineChapterEntityInsertionAdapter;

  final InsertionAdapter<OfflinePageEntity> _offlinePageEntityInsertionAdapter;

  final UpdateAdapter<OfflineComicEntity> _offlineComicEntityUpdateAdapter;

  @override
  Future<OfflineComicEntity?> getComic(String sourceId, String comicId) async {
    return _queryAdapter.query(
      'SELECT * FROM OfflineComicEntity WHERE sourceId = ?1 AND comicId = ?2',
      mapper: (Map<String, Object?> row) => OfflineComicEntity(
        row['sourceId'] as String,
        row['comicId'] as String,
        row['rawTitle'] as String,
        row['catalogJson'] as String,
        row['coverRelativePath'] as String?,
        row['remoteCoverUrl'] as String?,
        (row['isLongComic'] as int) != 0,
      ),
      arguments: [sourceId, comicId],
    );
  }

  @override
  Future<List<OfflineComicEntity>> getAllComics() async {
    return _queryAdapter.queryList(
      'SELECT * FROM OfflineComicEntity ORDER BY rawTitle, sourceId, comicId',
      mapper: (Map<String, Object?> row) => OfflineComicEntity(
        row['sourceId'] as String,
        row['comicId'] as String,
        row['rawTitle'] as String,
        row['catalogJson'] as String,
        row['coverRelativePath'] as String?,
        row['remoteCoverUrl'] as String?,
        (row['isLongComic'] as int) != 0,
      ),
    );
  }

  @override
  Future<OfflineChapterEntity?> getChapter(
    String sourceId,
    String comicId,
    String chapterId,
  ) async {
    return _queryAdapter.query(
      'SELECT * FROM OfflineChapterEntity WHERE sourceId = ?1 AND comicId = ?2 AND chapterId = ?3',
      mapper: (Map<String, Object?> row) => OfflineChapterEntity(
        row['sourceId'] as String,
        row['comicId'] as String,
        row['chapterId'] as String,
        row['rawTitle'] as String,
        row['groupName'] as String,
        row['sortIndex'] as int,
        row['manifestGeneration'] as int,
        row['operationGeneration'] as int,
        row['manifestSignature'] as String,
        row['state'] as String,
        row['error'] as String?,
        _dateTimeNullableConverter.decode(row['completedAt'] as int?),
      ),
      arguments: [sourceId, comicId, chapterId],
    );
  }

  @override
  Future<List<OfflineChapterEntity>> getChapters(
    String sourceId,
    String comicId,
  ) async {
    return _queryAdapter.queryList(
      'SELECT * FROM OfflineChapterEntity WHERE sourceId = ?1 AND comicId = ?2 ORDER BY groupName, sortIndex, chapterId',
      mapper: (Map<String, Object?> row) => OfflineChapterEntity(
        row['sourceId'] as String,
        row['comicId'] as String,
        row['chapterId'] as String,
        row['rawTitle'] as String,
        row['groupName'] as String,
        row['sortIndex'] as int,
        row['manifestGeneration'] as int,
        row['operationGeneration'] as int,
        row['manifestSignature'] as String,
        row['state'] as String,
        row['error'] as String?,
        _dateTimeNullableConverter.decode(row['completedAt'] as int?),
      ),
      arguments: [sourceId, comicId],
    );
  }

  @override
  Future<List<OfflineChapterEntity>> getAllReadableChapters() async {
    return _queryAdapter.queryList(
      'SELECT * FROM OfflineChapterEntity WHERE state = \'completed\' ORDER BY completedAt, sourceId, comicId, groupName, sortIndex, chapterId',
      mapper: (Map<String, Object?> row) => OfflineChapterEntity(
        row['sourceId'] as String,
        row['comicId'] as String,
        row['chapterId'] as String,
        row['rawTitle'] as String,
        row['groupName'] as String,
        row['sortIndex'] as int,
        row['manifestGeneration'] as int,
        row['operationGeneration'] as int,
        row['manifestSignature'] as String,
        row['state'] as String,
        row['error'] as String?,
        _dateTimeNullableConverter.decode(row['completedAt'] as int?),
      ),
    );
  }

  @override
  Future<List<OfflineChapterEntity>> getIncompleteChapters() async {
    return _queryAdapter.queryList(
      'SELECT * FROM OfflineChapterEntity WHERE state != \'completed\' ORDER BY sourceId, comicId, groupName, sortIndex, chapterId',
      mapper: (Map<String, Object?> row) => OfflineChapterEntity(
        row['sourceId'] as String,
        row['comicId'] as String,
        row['chapterId'] as String,
        row['rawTitle'] as String,
        row['groupName'] as String,
        row['sortIndex'] as int,
        row['manifestGeneration'] as int,
        row['operationGeneration'] as int,
        row['manifestSignature'] as String,
        row['state'] as String,
        row['error'] as String?,
        _dateTimeNullableConverter.decode(row['completedAt'] as int?),
      ),
    );
  }

  @override
  Future<List<OfflinePageEntity>> getPages(
    String sourceId,
    String comicId,
    String chapterId,
    int generation,
  ) async {
    return _queryAdapter.queryList(
      'SELECT * FROM OfflinePageEntity WHERE sourceId = ?1 AND comicId = ?2 AND chapterId = ?3 AND manifestGeneration = ?4 ORDER BY pageIndex',
      mapper: (Map<String, Object?> row) => OfflinePageEntity(
        row['sourceId'] as String,
        row['comicId'] as String,
        row['chapterId'] as String,
        row['manifestGeneration'] as int,
        row['pageIndex'] as int,
        row['taskId'] as String,
        row['relativePath'] as String,
        row['resourceUrl'] as String,
        row['headersJson'] as String,
        row['cacheKey'] as String?,
        row['expectedBytes'] as int?,
        (row['submitted'] as int) != 0,
      ),
      arguments: [sourceId, comicId, chapterId, generation],
    );
  }

  @override
  Future<OfflinePageEntity?> getPageByTaskId(String taskId) async {
    return _queryAdapter.query(
      'SELECT * FROM OfflinePageEntity WHERE taskId = ?1',
      mapper: (Map<String, Object?> row) => OfflinePageEntity(
        row['sourceId'] as String,
        row['comicId'] as String,
        row['chapterId'] as String,
        row['manifestGeneration'] as int,
        row['pageIndex'] as int,
        row['taskId'] as String,
        row['relativePath'] as String,
        row['resourceUrl'] as String,
        row['headersJson'] as String,
        row['cacheKey'] as String?,
        row['expectedBytes'] as int?,
        (row['submitted'] as int) != 0,
      ),
      arguments: [taskId],
    );
  }

  @override
  Future<void> setPageExpectedBytes(
    String sourceId,
    String comicId,
    String chapterId,
    int generation,
    int pageIndex,
    int expectedBytes,
  ) async {
    await _queryAdapter.queryNoReturn(
      'UPDATE OfflinePageEntity SET expectedBytes = ?6 WHERE sourceId = ?1 AND comicId = ?2 AND chapterId = ?3 AND manifestGeneration = ?4 AND pageIndex = ?5',
      arguments: [
        sourceId,
        comicId,
        chapterId,
        generation,
        pageIndex,
        expectedBytes,
      ],
    );
  }

  @override
  Future<void> markPageSubmitted(
    String sourceId,
    String comicId,
    String chapterId,
    int generation,
    int pageIndex,
  ) async {
    await _queryAdapter.queryNoReturn(
      'UPDATE OfflinePageEntity SET submitted = 1 WHERE sourceId = ?1 AND comicId = ?2 AND chapterId = ?3 AND manifestGeneration = ?4 AND pageIndex = ?5',
      arguments: [sourceId, comicId, chapterId, generation, pageIndex],
    );
  }

  @override
  Future<void> markPageUnsubmitted(
    String sourceId,
    String comicId,
    String chapterId,
    int generation,
    int pageIndex,
  ) async {
    await _queryAdapter.queryNoReturn(
      'UPDATE OfflinePageEntity SET submitted = 0 WHERE sourceId = ?1 AND comicId = ?2 AND chapterId = ?3 AND manifestGeneration = ?4 AND pageIndex = ?5',
      arguments: [sourceId, comicId, chapterId, generation, pageIndex],
    );
  }

  @override
  Future<void> setResolutionOperation(
    String sourceId,
    String comicId,
    String chapterId,
    int operationGeneration,
  ) async {
    await _queryAdapter.queryNoReturn(
      'UPDATE OfflineChapterEntity SET operationGeneration = ?4, state = \'resolving\', error = NULL, completedAt = NULL WHERE sourceId = ?1 AND comicId = ?2 AND chapterId = ?3',
      arguments: [sourceId, comicId, chapterId, operationGeneration],
    );
  }

  @override
  Future<void> deleteChapterPages(
    String sourceId,
    String comicId,
    String chapterId,
  ) async {
    await _queryAdapter.queryNoReturn(
      'DELETE FROM OfflinePageEntity WHERE sourceId = ?1 AND comicId = ?2 AND chapterId = ?3',
      arguments: [sourceId, comicId, chapterId],
    );
  }

  @override
  Future<void> markChapterCompletedForGeneration(
    String sourceId,
    String comicId,
    String chapterId,
    int generation,
    DateTime completedAt,
  ) async {
    await _queryAdapter.queryNoReturn(
      'UPDATE OfflineChapterEntity SET state = \'completed\', error = NULL, completedAt = ?5 WHERE sourceId = ?1 AND comicId = ?2 AND chapterId = ?3 AND manifestGeneration = ?4 AND state IN (\'downloading\', \'completed\')',
      arguments: [
        sourceId,
        comicId,
        chapterId,
        generation,
        _dateTimeConverter.encode(completedAt),
      ],
    );
  }

  @override
  Future<void> markChapterPausedForOperation(
    String sourceId,
    String comicId,
    String chapterId,
    int operationGeneration,
  ) async {
    await _queryAdapter.queryNoReturn(
      'UPDATE OfflineChapterEntity SET state = \'paused\', error = NULL, completedAt = NULL WHERE sourceId = ?1 AND comicId = ?2 AND chapterId = ?3 AND operationGeneration = ?4 AND state = \'downloading\'',
      arguments: [sourceId, comicId, chapterId, operationGeneration],
    );
  }

  @override
  Future<void> markChapterErrorForOperation(
    String sourceId,
    String comicId,
    String chapterId,
    int operationGeneration,
    String state,
    String error,
  ) async {
    await _queryAdapter.queryNoReturn(
      'UPDATE OfflineChapterEntity SET state = ?5, error = ?6, completedAt = NULL WHERE sourceId = ?1 AND comicId = ?2 AND chapterId = ?3 AND operationGeneration = ?4 AND state IN (\'resolving\', \'downloading\')',
      arguments: [
        sourceId,
        comicId,
        chapterId,
        operationGeneration,
        state,
        error,
      ],
    );
  }

  @override
  Future<void> setChapterStateClearedForGeneration(
    String sourceId,
    String comicId,
    String chapterId,
    int generation,
    String state,
  ) async {
    await _queryAdapter.queryNoReturn(
      'UPDATE OfflineChapterEntity SET state = ?5, error = NULL, completedAt = NULL WHERE sourceId = ?1 AND comicId = ?2 AND chapterId = ?3 AND manifestGeneration = ?4',
      arguments: [sourceId, comicId, chapterId, generation, state],
    );
  }

  @override
  Future<void> setChapterStateErrorForGeneration(
    String sourceId,
    String comicId,
    String chapterId,
    int generation,
    String state,
    String error,
  ) async {
    await _queryAdapter.queryNoReturn(
      'UPDATE OfflineChapterEntity SET state = ?5, error = ?6, completedAt = NULL WHERE sourceId = ?1 AND comicId = ?2 AND chapterId = ?3 AND manifestGeneration = ?4',
      arguments: [sourceId, comicId, chapterId, generation, state, error],
    );
  }

  @override
  Future<void> setChapterStateCompletedForGeneration(
    String sourceId,
    String comicId,
    String chapterId,
    int generation,
    String state,
    DateTime completedAt,
  ) async {
    await _queryAdapter.queryNoReturn(
      'UPDATE OfflineChapterEntity SET state = ?5, error = NULL, completedAt = ?6 WHERE sourceId = ?1 AND comicId = ?2 AND chapterId = ?3 AND manifestGeneration = ?4',
      arguments: [
        sourceId,
        comicId,
        chapterId,
        generation,
        state,
        _dateTimeConverter.encode(completedAt),
      ],
    );
  }

  @override
  Future<void> setChapterStateErrorAndCompletedForGeneration(
    String sourceId,
    String comicId,
    String chapterId,
    int generation,
    String state,
    String error,
    DateTime completedAt,
  ) async {
    await _queryAdapter.queryNoReturn(
      'UPDATE OfflineChapterEntity SET state = ?5, error = ?6, completedAt = ?7 WHERE sourceId = ?1 AND comicId = ?2 AND chapterId = ?3 AND manifestGeneration = ?4',
      arguments: [
        sourceId,
        comicId,
        chapterId,
        generation,
        state,
        error,
        _dateTimeConverter.encode(completedAt),
      ],
    );
  }

  @override
  Future<void> deleteChapter(
    String sourceId,
    String comicId,
    String chapterId,
  ) async {
    await _queryAdapter.queryNoReturn(
      'DELETE FROM OfflineChapterEntity WHERE sourceId = ?1 AND comicId = ?2 AND chapterId = ?3',
      arguments: [sourceId, comicId, chapterId],
    );
  }

  @override
  Future<void> deleteComicIfEmpty(String sourceId, String comicId) async {
    await _queryAdapter.queryNoReturn(
      'DELETE FROM OfflineComicEntity WHERE sourceId = ?1 AND comicId = ?2 AND NOT EXISTS (SELECT 1 FROM OfflineChapterEntity WHERE sourceId = ?1 AND comicId = ?2)',
      arguments: [sourceId, comicId],
    );
  }

  @override
  Future<void> insertComic(OfflineComicEntity comic) async {
    await _offlineComicEntityInsertionAdapter.insert(
      comic,
      OnConflictStrategy.ignore,
    );
  }

  @override
  Future<void> upsertChapter(OfflineChapterEntity chapter) async {
    await _offlineChapterEntityInsertionAdapter.insert(
      chapter,
      OnConflictStrategy.replace,
    );
  }

  @override
  Future<void> upsertPages(List<OfflinePageEntity> pages) async {
    await _offlinePageEntityInsertionAdapter.insertList(
      pages,
      OnConflictStrategy.replace,
    );
  }

  @override
  Future<void> updateComic(OfflineComicEntity comic) async {
    await _offlineComicEntityUpdateAdapter.update(
      comic,
      OnConflictStrategy.abort,
    );
  }

  @override
  Future<OfflineChapterEntity> beginResolution(
    String sourceId,
    String comicId,
    String chapterId,
    int operationGeneration,
  ) async {
    if (database is sqflite.Transaction) {
      return super.beginResolution(
        sourceId,
        comicId,
        chapterId,
        operationGeneration,
      );
    } else {
      return (database as sqflite.Database).transaction<OfflineChapterEntity>((
        transaction,
      ) async {
        final transactionDatabase = _$DComicDatabase(changeListener)
          ..database = transaction;
        return transactionDatabase.offlineComicDao.beginResolution(
          sourceId,
          comicId,
          chapterId,
          operationGeneration,
        );
      });
    }
  }

  @override
  Future<bool> replaceManifestIfCurrent(
    OfflineComicEntity comic,
    OfflineChapterEntity chapter,
    List<OfflinePageEntity> pages,
    int operationGeneration,
  ) async {
    if (database is sqflite.Transaction) {
      return super.replaceManifestIfCurrent(
        comic,
        chapter,
        pages,
        operationGeneration,
      );
    } else {
      return (database as sqflite.Database).transaction<bool>((
        transaction,
      ) async {
        final transactionDatabase = _$DComicDatabase(changeListener)
          ..database = transaction;
        return transactionDatabase.offlineComicDao.replaceManifestIfCurrent(
          comic,
          chapter,
          pages,
          operationGeneration,
        );
      });
    }
  }

  @override
  Future<void> replaceManifest(
    OfflineComicEntity comic,
    OfflineChapterEntity chapter,
    List<OfflinePageEntity> pages,
  ) async {
    if (database is sqflite.Transaction) {
      await super.replaceManifest(comic, chapter, pages);
    } else {
      await (database as sqflite.Database).transaction<void>((
        transaction,
      ) async {
        final transactionDatabase = _$DComicDatabase(changeListener)
          ..database = transaction;
        await transactionDatabase.offlineComicDao.replaceManifest(
          comic,
          chapter,
          pages,
        );
      });
    }
  }

  @override
  Future<void> removeChapterAndOrphanedComic(
    String sourceId,
    String comicId,
    String chapterId,
  ) async {
    if (database is sqflite.Transaction) {
      await super.removeChapterAndOrphanedComic(sourceId, comicId, chapterId);
    } else {
      await (database as sqflite.Database).transaction<void>((
        transaction,
      ) async {
        final transactionDatabase = _$DComicDatabase(changeListener)
          ..database = transaction;
        await transactionDatabase.offlineComicDao.removeChapterAndOrphanedComic(
          sourceId,
          comicId,
          chapterId,
        );
      });
    }
  }
}

// ignore_for_file: unused_element
final _dateTimeConverter = DateTimeConverter();
final _dateTimeNullableConverter = DateTimeNullableConverter();
final _imageTypeConverter = ImageTypeConverter();
final _imageTypeNullableConverter = ImageTypeNullableConverter();
