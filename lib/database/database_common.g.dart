// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_common.dart';

// **************************************************************************
// FloorGenerator
// **************************************************************************

// ignore: avoid_classes_with_only_static_members
class $FloorDComicDatabase {
  /// Creates a database builder for a persistent database.
  /// Once a database is built, you should keep a reference to it and re-use it.
  static _$DComicDatabaseBuilder databaseBuilder(String name) =>
      _$DComicDatabaseBuilder(name);

  /// Creates a database builder for an in memory database.
  /// Information stored in an in memory database disappears when the process is killed.
  /// Once a database is built, you should keep a reference to it and re-use it.
  static _$DComicDatabaseBuilder inMemoryDatabaseBuilder() =>
      _$DComicDatabaseBuilder(null);
}

class _$DComicDatabaseBuilder {
  _$DComicDatabaseBuilder(this.name);

  final String? name;

  final List<Migration> _migrations = [];

  Callback? _callback;

  /// Adds migrations to the builder.
  _$DComicDatabaseBuilder addMigrations(List<Migration> migrations) {
    _migrations.addAll(migrations);
    return this;
  }

  /// Adds a database [Callback] to the builder.
  _$DComicDatabaseBuilder addCallback(Callback callback) {
    _callback = callback;
    return this;
  }

  /// Creates the database and initializes it.
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

  Future<sqflite.Database> open(
    String path,
    List<Migration> migrations, [
    Callback? callback,
  ]) async {
    final databaseOptions = sqflite.OpenDatabaseOptions(
      version: 3,
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
            'CREATE TABLE IF NOT EXISTS `ComicHistoryEntity` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `comicId` TEXT NOT NULL, `title` TEXT, `cover` TEXT, `coverType` INTEGER, `lastChapterTitle` TEXT, `lastChapterId` TEXT, `timestamp` INTEGER, `providerName` TEXT)');
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `CookieEntity` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `key` TEXT NOT NULL, `value` TEXT NOT NULL)');
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `ModelConfigEntity` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `key` TEXT NOT NULL, `value` TEXT, `sourceModel` TEXT)');

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
    return _queryAdapter.query('SELECT * FROM ConfigEntity WHERE key = ?1',
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
        configEntity, OnConflictStrategy.abort);
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
                  'coverType':
                      _imageTypeNullableConverter.encode(item.coverType),
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
                  'coverType':
                      _imageTypeNullableConverter.encode(item.coverType),
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
            row['title'] as String?,
            row['cover'] as String?,
            _imageTypeNullableConverter.decode(row['coverType'] as int?),
            row['lastChapterTitle'] as String?,
            row['lastChapterId'] as String?,
            _dateTimeNullableConverter.decode(row['timestamp'] as int?),
            row['providerName'] as String?));
  }

  @override
  Future<ComicHistoryEntity?> getComicHistoryByComicId(String comicId) async {
    return _queryAdapter.query(
        'SELECT * FROM ComicHistoryEntity WHERE comicId= ?1',
        mapper: (Map<String, Object?> row) => ComicHistoryEntity(
            row['id'] as int?,
            row['comicId'] as String,
            row['title'] as String?,
            row['cover'] as String?,
            _imageTypeNullableConverter.decode(row['coverType'] as int?),
            row['lastChapterTitle'] as String?,
            row['lastChapterId'] as String?,
            _dateTimeNullableConverter.decode(row['timestamp'] as int?),
            row['providerName'] as String?),
        arguments: [comicId]);
  }

  @override
  Future<List<ComicHistoryEntity>> getComicHistoryByProvider(
      String providerName) async {
    return _queryAdapter.queryList(
        'SELECT * FROM ComicHistoryEntity WHERE providerName= ?1',
        mapper: (Map<String, Object?> row) => ComicHistoryEntity(
            row['id'] as int?,
            row['comicId'] as String,
            row['title'] as String?,
            row['cover'] as String?,
            _imageTypeNullableConverter.decode(row['coverType'] as int?),
            row['lastChapterTitle'] as String?,
            row['lastChapterId'] as String?,
            _dateTimeNullableConverter.decode(row['timestamp'] as int?),
            row['providerName'] as String?),
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
    return _queryAdapter.query('SELECT * FROM CookieEntity WHERE key = ?1',
        mapper: (Map<String, Object?> row) => CookieEntity(
            row['id'] as int?, row['key'] as String, row['value'] as String),
        arguments: [key]);
  }

  @override
  Future<void> deleteCookie(String key) async {
    await _queryAdapter.queryNoReturn('DELETE FROM CookieEntity WHERE key = ?1',
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
        'SELECT * FROM ModelConfigEntity WHERE `key` = ?1 AND `sourceModel` = ?2 LIMIT 1',
        mapper: (Map<String, Object?> row) => ModelConfigEntity(row['id'] as int?, row['key'] as String, row['value'] as String?, row['sourceModel'] as String?),
        arguments: [key, sourceModel]);
  }

  @override
  Future<void> insertConfig(ModelConfigEntity configEntity) async {
    await _modelConfigEntityInsertionAdapter.insert(
        configEntity, OnConflictStrategy.abort);
  }

  @override
  Future<void> updateConfig(ModelConfigEntity configEntity) async {
    await _modelConfigEntityUpdateAdapter.update(
        configEntity, OnConflictStrategy.abort);
  }
}

// ignore_for_file: unused_element
final _dateTimeConverter = DateTimeConverter();
final _dateTimeNullableConverter = DateTimeNullableConverter();
final _imageTypeConverter = ImageTypeConverter();
final _imageTypeNullableConverter = ImageTypeNullableConverter();
