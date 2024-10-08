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
    database.database = await database.open(
      path,
      _migrations,
      _callback,
    );
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

  Future<sqflite.Database> open(
    String path,
    List<Migration> migrations, [
    Callback? callback,
  ]) async {
    final databaseOptions = sqflite.OpenDatabaseOptions(
      version: 5,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
        await callback?.onConfigure?.call(database);
      },
      onOpen: (database) async {
        await callback?.onOpen?.call(database);
      },
      onUpgrade: (database, startVersion, endVersion) async {
        await MigrationAdapter.runMigrations(
            database, startVersion, endVersion, migrations);

        await callback?.onUpgrade?.call(database, startVersion, endVersion);
      },
      onCreate: (database, version) async {
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `ConfigEntity` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `key` TEXT NOT NULL, `value` TEXT)');
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `ComicHistoryEntity` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `comicId` TEXT NOT NULL, `title` TEXT NOT NULL, `cover` TEXT NOT NULL, `coverType` INTEGER NOT NULL, `lastChapterTitle` TEXT NOT NULL, `lastChapterId` TEXT NOT NULL, `timestamp` INTEGER, `providerName` TEXT NOT NULL)');
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `CookieEntity` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `key` TEXT NOT NULL, `value` TEXT NOT NULL)');
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `ModelConfigEntity` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `key` TEXT NOT NULL, `value` TEXT, `sourceModel` TEXT)');
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `ComicMappingEntity` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `comicId` TEXT NOT NULL, `sourceProviderName` TEXT NOT NULL, `targetProviderName` TEXT NOT NULL, `resultComicId` TEXT NOT NULL)');
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `ComicSubscribeStateEntity` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `comicId` TEXT NOT NULL, `timestamp` INTEGER, `providerName` TEXT NOT NULL)');

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
    return _comicHistoryDaoInstance ??=
        _$ComicHistoryDao(database, changeListener);
  }

  @override
  CookieDao get cookieDao {
    return _cookieDaoInstance ??= _$CookieDao(database, changeListener);
  }

  @override
  ModelConfigDao get modelConfigDao {
    return _modelConfigDaoInstance ??=
        _$ModelConfigDao(database, changeListener);
  }

  @override
  ComicMappingDao get comicMappingDao {
    return _comicMappingDaoInstance ??=
        _$ComicMappingDao(database, changeListener);
  }

  @override
  ComicSubscribeStateDao get comicSubscribeStateDao {
    return _comicSubscribeStateDaoInstance ??=
        _$ComicSubscribeStateDao(database, changeListener);
  }
}

class _$ConfigDao extends ConfigDao {
  _$ConfigDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _configEntityInsertionAdapter = InsertionAdapter(
            database,
            'ConfigEntity',
            (ConfigEntity item) => <String, Object?>{
                  'id': item.id,
                  'key': item.key,
                  'value': item.value
                }),
        _configEntityUpdateAdapter = UpdateAdapter(
            database,
            'ConfigEntity',
            ['id'],
            (ConfigEntity item) => <String, Object?>{
                  'id': item.id,
                  'key': item.key,
                  'value': item.value
                });

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<ConfigEntity> _configEntityInsertionAdapter;

  final UpdateAdapter<ConfigEntity> _configEntityUpdateAdapter;

  @override
  Future<List<ConfigEntity>> getAllConfig() async {
    return _queryAdapter.queryList('SELECT * FROM ConfigEntity',
        mapper: (Map<String, Object?> row) => ConfigEntity(
            row['id'] as int?, row['key'] as String, row['value'] as String?));
  }

  @override
  Future<ConfigEntity?> getConfigByKey(String key) async {
    return _queryAdapter.query('SELECT * FROM ConfigEntity WHERE `key` = ?1',
        mapper: (Map<String, Object?> row) => ConfigEntity(
            row['id'] as int?, row['key'] as String, row['value'] as String?),
        arguments: [key]);
  }

  @override
  Future<void> insertConfig(ConfigEntity configEntity) async {
    await _configEntityInsertionAdapter.insert(
        configEntity, OnConflictStrategy.abort);
  }

  @override
  Future<void> updateConfig(ConfigEntity configEntity) async {
    await _configEntityUpdateAdapter.update(
        configEntity, OnConflictStrategy.replace);
  }
}

class _$ComicHistoryDao extends ComicHistoryDao {
  _$ComicHistoryDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
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
                  'timestamp':
                      _dateTimeNullableConverter.encode(item.timestamp),
                  'providerName': item.providerName
                }),
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
                  'timestamp':
                      _dateTimeNullableConverter.encode(item.timestamp),
                  'providerName': item.providerName
                });

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<ComicHistoryEntity>
      _comicHistoryEntityInsertionAdapter;

  final UpdateAdapter<ComicHistoryEntity> _comicHistoryEntityUpdateAdapter;

  @override
  Future<List<ComicHistoryEntity>> getAllComicHistoryEntity() async {
    return _queryAdapter.queryList('SELECT * FROM ComicHistoryEntity',
        mapper: (Map<String, Object?> row) => ComicHistoryEntity(
            row['id'] as int?,
            row['comicId'] as String,
            row['title'] as String,
            row['cover'] as String,
            _imageTypeConverter.decode(row['coverType'] as int),
            row['lastChapterTitle'] as String,
            row['lastChapterId'] as String,
            _dateTimeNullableConverter.decode(row['timestamp'] as int?),
            row['providerName'] as String));
  }

  @override
  Future<ComicHistoryEntity?> getComicHistoryByComicId(
    String comicId,
    String providerName,
  ) async {
    return _queryAdapter.query(
        'SELECT * FROM ComicHistoryEntity WHERE `comicId`= ?1 AND `providerName`= ?2',
        mapper: (Map<String, Object?> row) => ComicHistoryEntity(row['id'] as int?, row['comicId'] as String, row['title'] as String, row['cover'] as String, _imageTypeConverter.decode(row['coverType'] as int), row['lastChapterTitle'] as String, row['lastChapterId'] as String, _dateTimeNullableConverter.decode(row['timestamp'] as int?), row['providerName'] as String),
        arguments: [comicId, providerName]);
  }

  @override
  Future<List<ComicHistoryEntity>> getComicHistoryByProvider(
      String providerName) async {
    return _queryAdapter.queryList(
        'SELECT * FROM ComicHistoryEntity WHERE `providerName`= ?1 GROUP BY comicId',
        mapper: (Map<String, Object?> row) => ComicHistoryEntity(row['id'] as int?, row['comicId'] as String, row['title'] as String, row['cover'] as String, _imageTypeConverter.decode(row['coverType'] as int), row['lastChapterTitle'] as String, row['lastChapterId'] as String, _dateTimeNullableConverter.decode(row['timestamp'] as int?), row['providerName'] as String),
        arguments: [providerName]);
  }

  @override
  Future<void> insertComicHistory(ComicHistoryEntity comicHistoryEntity) async {
    await _comicHistoryEntityInsertionAdapter.insert(
        comicHistoryEntity, OnConflictStrategy.replace);
  }

  @override
  Future<void> updateComicHistory(ComicHistoryEntity comicHistoryEntity) async {
    await _comicHistoryEntityUpdateAdapter.update(
        comicHistoryEntity, OnConflictStrategy.replace);
  }
}

class _$CookieDao extends CookieDao {
  _$CookieDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _cookieEntityInsertionAdapter = InsertionAdapter(
            database,
            'CookieEntity',
            (CookieEntity item) => <String, Object?>{
                  'id': item.id,
                  'key': item.key,
                  'value': item.value
                }),
        _cookieEntityUpdateAdapter = UpdateAdapter(
            database,
            'CookieEntity',
            ['id'],
            (CookieEntity item) => <String, Object?>{
                  'id': item.id,
                  'key': item.key,
                  'value': item.value
                });

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<CookieEntity> _cookieEntityInsertionAdapter;

  final UpdateAdapter<CookieEntity> _cookieEntityUpdateAdapter;

  @override
  Future<List<CookieEntity>> getAllCookies() async {
    return _queryAdapter.queryList('SELECT * FROM CookieEntity',
        mapper: (Map<String, Object?> row) => CookieEntity(
            row['id'] as int?, row['key'] as String, row['value'] as String));
  }

  @override
  Future<CookieEntity?> getCookieByKey(String key) async {
    return _queryAdapter.query('SELECT * FROM CookieEntity WHERE `key` = ?1',
        mapper: (Map<String, Object?> row) => CookieEntity(
            row['id'] as int?, row['key'] as String, row['value'] as String),
        arguments: [key]);
  }

  @override
  Future<void> deleteCookie(String key) async {
    await _queryAdapter.queryNoReturn(
        'DELETE FROM CookieEntity WHERE `key` = ?1',
        arguments: [key]);
  }

  @override
  Future<void> insertCookie(CookieEntity cookieEntity) async {
    await _cookieEntityInsertionAdapter.insert(
        cookieEntity, OnConflictStrategy.replace);
  }

  @override
  Future<void> updateCookie(CookieEntity cookieEntity) async {
    await _cookieEntityUpdateAdapter.update(
        cookieEntity, OnConflictStrategy.replace);
  }
}

class _$ModelConfigDao extends ModelConfigDao {
  _$ModelConfigDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _modelConfigEntityInsertionAdapter = InsertionAdapter(
            database,
            'ModelConfigEntity',
            (ModelConfigEntity item) => <String, Object?>{
                  'id': item.id,
                  'key': item.key,
                  'value': item.value,
                  'sourceModel': item.sourceModel
                }),
        _modelConfigEntityUpdateAdapter = UpdateAdapter(
            database,
            'ModelConfigEntity',
            ['id'],
            (ModelConfigEntity item) => <String, Object?>{
                  'id': item.id,
                  'key': item.key,
                  'value': item.value,
                  'sourceModel': item.sourceModel
                });

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<ModelConfigEntity> _modelConfigEntityInsertionAdapter;

  final UpdateAdapter<ModelConfigEntity> _modelConfigEntityUpdateAdapter;

  @override
  Future<List<ModelConfigEntity>> getAllConfig() async {
    return _queryAdapter.queryList('SELECT * FROM ModelConfigEntity',
        mapper: (Map<String, Object?> row) => ModelConfigEntity(
            row['id'] as int?,
            row['key'] as String,
            row['value'] as String?,
            row['sourceModel'] as String?));
  }

  @override
  Future<ModelConfigEntity?> getConfigByKeyAndModel(
    String key,
    String sourceModel,
  ) async {
    return _queryAdapter.query(
        'SELECT * FROM ModelConfigEntity WHERE `key` = ?1 AND `sourceModel` = ?2',
        mapper: (Map<String, Object?> row) => ModelConfigEntity(row['id'] as int?, row['key'] as String, row['value'] as String?, row['sourceModel'] as String?),
        arguments: [key, sourceModel]);
  }

  @override
  Future<void> insertConfig(ModelConfigEntity configEntity) async {
    await _modelConfigEntityInsertionAdapter.insert(
        configEntity, OnConflictStrategy.replace);
  }

  @override
  Future<void> updateConfig(ModelConfigEntity configEntity) async {
    await _modelConfigEntityUpdateAdapter.update(
        configEntity, OnConflictStrategy.replace);
  }
}

class _$ComicMappingDao extends ComicMappingDao {
  _$ComicMappingDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _comicMappingEntityInsertionAdapter = InsertionAdapter(
            database,
            'ComicMappingEntity',
            (ComicMappingEntity item) => <String, Object?>{
                  'id': item.id,
                  'comicId': item.comicId,
                  'sourceProviderName': item.sourceProviderName,
                  'targetProviderName': item.targetProviderName,
                  'resultComicId': item.resultComicId
                }),
        _comicMappingEntityUpdateAdapter = UpdateAdapter(
            database,
            'ComicMappingEntity',
            ['id'],
            (ComicMappingEntity item) => <String, Object?>{
                  'id': item.id,
                  'comicId': item.comicId,
                  'sourceProviderName': item.sourceProviderName,
                  'targetProviderName': item.targetProviderName,
                  'resultComicId': item.resultComicId
                });

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<ComicMappingEntity>
      _comicMappingEntityInsertionAdapter;

  final UpdateAdapter<ComicMappingEntity> _comicMappingEntityUpdateAdapter;

  @override
  Future<List<ComicMappingEntity>> getAllComicMappingEntity() async {
    return _queryAdapter.queryList('SELECT * FROM ComicMappingEntity',
        mapper: (Map<String, Object?> row) => ComicMappingEntity(
            row['id'] as int?,
            row['comicId'] as String,
            row['sourceProviderName'] as String,
            row['targetProviderName'] as String,
            row['resultComicId'] as String));
  }

  @override
  Future<ComicMappingEntity?> getComicMappingByComicId(
    String comicId,
    String sourceProviderName,
    String targetProviderName,
  ) async {
    return _queryAdapter.query(
        'SELECT * FROM ComicMappingEntity WHERE `comicId` = ?1 AND `sourceProviderName` = ?2 AND `targetProviderName` = ?3',
        mapper: (Map<String, Object?> row) => ComicMappingEntity(row['id'] as int?, row['comicId'] as String, row['sourceProviderName'] as String, row['targetProviderName'] as String, row['resultComicId'] as String),
        arguments: [comicId, sourceProviderName, targetProviderName]);
  }

  @override
  Future<void> insertComicMapping(ComicMappingEntity comicMappingEntity) async {
    await _comicMappingEntityInsertionAdapter.insert(
        comicMappingEntity, OnConflictStrategy.replace);
  }

  @override
  Future<void> updateComicMapping(ComicMappingEntity comicMappingEntity) async {
    await _comicMappingEntityUpdateAdapter.update(
        comicMappingEntity, OnConflictStrategy.replace);
  }
}

class _$ComicSubscribeStateDao extends ComicSubscribeStateDao {
  _$ComicSubscribeStateDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _comicSubscribeStateEntityInsertionAdapter = InsertionAdapter(
            database,
            'ComicSubscribeStateEntity',
            (ComicSubscribeStateEntity item) => <String, Object?>{
                  'id': item.id,
                  'comicId': item.comicId,
                  'timestamp':
                      _dateTimeNullableConverter.encode(item.timestamp),
                  'providerName': item.providerName
                }),
        _comicSubscribeStateEntityUpdateAdapter = UpdateAdapter(
            database,
            'ComicSubscribeStateEntity',
            ['id'],
            (ComicSubscribeStateEntity item) => <String, Object?>{
                  'id': item.id,
                  'comicId': item.comicId,
                  'timestamp':
                      _dateTimeNullableConverter.encode(item.timestamp),
                  'providerName': item.providerName
                });

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
    return _queryAdapter.queryList('SELECT * FROM ComicSubscribeStateEntity',
        mapper: (Map<String, Object?> row) => ComicSubscribeStateEntity(
            row['id'] as int?,
            row['comicId'] as String,
            _dateTimeNullableConverter.decode(row['timestamp'] as int?),
            row['providerName'] as String));
  }

  @override
  Future<ComicSubscribeStateEntity?> getComicSubscribeStateByComicId(
    String comicId,
    String providerName,
  ) async {
    return _queryAdapter.query(
        'SELECT * FROM ComicSubscribeStateEntity WHERE `comicId`= ?1 AND `providerName`= ?2',
        mapper: (Map<String, Object?> row) => ComicSubscribeStateEntity(row['id'] as int?, row['comicId'] as String, _dateTimeNullableConverter.decode(row['timestamp'] as int?), row['providerName'] as String),
        arguments: [comicId, providerName]);
  }

  @override
  Future<List<ComicSubscribeStateEntity>> getComicSubscribeStateByProvider(
      String providerName) async {
    return _queryAdapter.queryList(
        'SELECT * FROM ComicSubscribeStateEntity WHERE `providerName`= ?1 GROUP BY comicId',
        mapper: (Map<String, Object?> row) => ComicSubscribeStateEntity(row['id'] as int?, row['comicId'] as String, _dateTimeNullableConverter.decode(row['timestamp'] as int?), row['providerName'] as String),
        arguments: [providerName]);
  }

  @override
  Future<void> insertComicSubscribeState(
      ComicSubscribeStateEntity comicSubscribeStateEntity) async {
    await _comicSubscribeStateEntityInsertionAdapter.insert(
        comicSubscribeStateEntity, OnConflictStrategy.replace);
  }

  @override
  Future<void> updateComicSubscribeState(
      ComicSubscribeStateEntity comicSubscribeStateEntity) async {
    await _comicSubscribeStateEntityUpdateAdapter.update(
        comicSubscribeStateEntity, OnConflictStrategy.replace);
  }
}

// ignore_for_file: unused_element
final _dateTimeConverter = DateTimeConverter();
final _dateTimeNullableConverter = DateTimeNullableConverter();
final _imageTypeConverter = ImageTypeConverter();
final _imageTypeNullableConverter = ImageTypeNullableConverter();
