part of 'sync_store.dart';
const _maximumSyncTimestamp = 8640000000000000;

class _KeyParts {
  const _KeyParts(this.key1, [this.key2 = '', this.key3 = '']);

  final String key1;
  final String key2;
  final String key3;
}

Future<String> _activeAccount(sqflite.DatabaseExecutor database) async {
  final rows = await database.query(
    _stateTable,
    columns: ['active_account'],
    where: 'id = 1',
    limit: 1,
  );
  return rows.single['active_account']! as String;
}

Future<void> _setSuppressed(
  sqflite.DatabaseExecutor database,
  bool suppressed,
) =>
    database.update(
      _stateTable,
      {'suppress': suppressed ? 1 : 0},
      where: 'id = 1',
    );

Future<void> _bootstrapMetadata(
  sqflite.DatabaseExecutor database,
  String account, {
  bool accountBaseline = false,
}) async {
  final history = await database.rawQuery(
    'SELECT DISTINCT providerName, comicId FROM ComicHistoryEntity',
  );
  for (final row in history) {
    await _insertBaseline(
      database,
      account,
      SyncCategory.history,
      _KeyParts(
        'history',
        row['providerName']! as String,
        row['comicId']! as String,
      ),
      accountBaseline: accountBaseline,
    );
  }
  final subscriptions = await database.rawQuery(
    'SELECT DISTINCT providerName, comicId FROM ComicSubscribeStateEntity',
  );
  for (final row in subscriptions) {
    await _insertBaseline(
      database,
      account,
      SyncCategory.history,
      _KeyParts(
        'subscribe',
        row['providerName']! as String,
        row['comicId']! as String,
      ),
      accountBaseline: accountBaseline,
    );
  }
  final settings = await database.query(
    'ConfigEntity',
    distinct: true,
    columns: ['key'],
    where: _settingsSql,
  );
  for (final row in settings) {
    await _insertBaseline(
      database,
      account,
      SyncCategory.settings,
      _KeyParts(row['key']! as String),
      accountBaseline: accountBaseline,
    );
  }
  final modelSettings = await database.query(
    'ModelConfigEntity',
    distinct: true,
    columns: ['sourceModel', 'key'],
  );
  for (final row in modelSettings) {
    final key = row['key']! as String;
    final sourceModel = (row['sourceModel'] as String?) ?? '';
    if (sourceModel.isEmpty || !_isSourceSettingKey(key)) continue;
    await _insertBaseline(
      database,
      account,
      SyncCategory.sourceSettings,
      _KeyParts(sourceModel, key),
      accountBaseline: accountBaseline,
    );
  }
  await _insertBaseline(
    database,
    account,
    SyncCategory.bindings,
    const _KeyParts('graph'),
    accountBaseline: accountBaseline,
  );
  await _insertBaseline(
    database,
    account,
    SyncCategory.chapterRules,
    const _KeyParts('rules'),
    accountBaseline: accountBaseline,
  );
  await _insertBaseline(
    database,
    account,
    SyncCategory.credentials,
    const _KeyParts('accounts'),
    accountBaseline: accountBaseline,
  );
}

Future<void> _saveAccountSnapshot(
  sqflite.DatabaseExecutor database,
  String account,
) async {
  final rows = await _metadataRows(
    database,
    account,
    SyncCategory.values.toSet(),
    pendingOnly: false,
  );
  final records = await _hydrateRows(database, rows);
  await database.insert(
    _accountSnapshotTable,
    {
      'account': account,
      'records_json': jsonEncode([
        for (final record in records) record.toJson(),
      ]),
    },
    conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
  );
}

Future<bool> _restoreAccountSnapshot(
  sqflite.DatabaseExecutor database,
  String account,
) async {
  final rows = await database.query(
    _accountSnapshotTable,
    columns: ['records_json'],
    where: 'account = ?',
    whereArgs: [account],
    limit: 1,
  );
  if (rows.isEmpty) return false;
  final decoded = jsonDecode(rows.single['records_json']! as String);
  if (decoded is! List) {
    throw const FormatException('stored account snapshot is invalid');
  }
  final records = <SyncRecord>[];
  for (final raw in decoded) {
    if (raw is! Map) {
      throw const FormatException('stored account snapshot is invalid');
    }
    records.add(
      _validateRecord(
        SyncRecord.fromJson(Map<String, dynamic>.from(raw)),
      ),
    );
  }
  await _clearSyncBusinessData(database);
  for (final record in records) {
    await _applyBusinessRecord(database, record);
  }
  return true;
}

Future<void> _clearSyncBusinessData(
  sqflite.DatabaseExecutor database,
) async {
  await database.delete('ComicHistoryEntity');
  await database.delete('ComicSubscribeStateEntity');
  await database.delete('ComicMappingEntity');
  await database.delete('ChapterRulePatternEntity');
  await database.delete('ChapterRuleGroupEntity');
  await database.delete('CookieEntity');
  await database.delete('ConfigEntity', where: _settingsSql);
  final modelRows = await database.query(
    'ModelConfigEntity',
    columns: ['id', 'key'],
  );
  for (final row in modelRows) {
    final key = row['key']! as String;
    if (_isCredentialKey(key) || _isSourceSettingKey(key)) {
      await database.delete(
        'ModelConfigEntity',
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }
}

Future<void> _insertBaseline(
  sqflite.DatabaseExecutor database,
  String account,
  SyncCategory category,
  _KeyParts key, {
  bool accountBaseline = false,
}) async {
  final state = (await database.query(
    _stateTable,
    columns: ['device_id'],
    where: 'id = 1',
    limit: 1,
  )).single;
  await database.insert(
    _recordTable,
    {
      'account': account,
      'category': category.name,
      'key1': key.key1,
      'key2': key.key2,
      'key3': key.key3,
      'deleted': 0,
      'wall': 0,
      'logical': 0,
      'device': state['device_id'],
      'uncertain': 1,
      'base_wall': null,
      'base_logical': null,
      'base_device': null,
      'pending': 0,
      'baseline': accountBaseline ? 1 : 0,
    },
    conflictAlgorithm: sqflite.ConflictAlgorithm.ignore,
  );
}

Future<List<Map<String, Object?>>> _metadataRows(
  sqflite.DatabaseExecutor database,
  String account,
  Set<SyncCategory> categories, {
  required bool pendingOnly,
  int? limit,
}) async {
  final names = categories.map((category) => category.name).toList()..sort();
  final placeholders = List.filled(names.length, '?').join(',');
  final pendingClause = pendingOnly
      ? ' AND r.pending = 1 '
          'AND NOT EXISTS (SELECT 1 FROM $_resolutionTable q '
          'WHERE q.account = r.account AND q.wall = r.wall '
          'AND q.logical = r.logical AND q.device = r.device)'
      : '';
  return database.rawQuery(
    'SELECT r.* FROM $_recordTable r '
    'WHERE r.account = ? AND r.category IN ($placeholders)$pendingClause '
    'ORDER BY r.wall ASC, r.logical ASC, r.device ASC, r.category ASC, '
    'r.key1 ASC, r.key2 ASC, r.key3 ASC'
    '${limit == null ? '' : ' LIMIT $limit'}',
    [account, ...names],
  );
}

Future<Map<String, Object?>?> _metadataRow(
  sqflite.DatabaseExecutor database,
  String account,
  SyncCategory category,
  _KeyParts key,
) async {
  final rows = await database.query(
    _recordTable,
    where:
        'account = ? AND category = ? AND key1 = ? AND key2 = ? AND key3 = ?',
    whereArgs: [account, category.name, key.key1, key.key2, key.key3],
    limit: 1,
  );
  return rows.isEmpty ? null : rows.single;
}

Future<List<SyncRecord>> _hydrateRows(
  sqflite.DatabaseExecutor database,
  List<Map<String, Object?>> rows,
) async {
  final result = <SyncRecord>[];
  for (final row in rows) {
    result.add(await _hydrateRow(database, row));
  }
  return result;
}

Future<SyncRecord> _hydrateRow(
  sqflite.DatabaseExecutor database,
  Map<String, Object?> row,
) async {
  final category = _categoryFromName(row['category']! as String);
  final key = _KeyParts(
    row['key1']! as String,
    row['key2']! as String,
    row['key3']! as String,
  );
  final deleted = row['deleted'] == 1;
  final value = deleted ? null : await _loadValue(database, category, key);
  return SyncRecord(
    category: category,
    key: _externalKey(category, key),
    value: value,
    deleted: deleted,
    version: _versionFromRow(row),
    uncertain: row['uncertain'] == 1,
    baseVersion: _baseVersionFromRow(row),
  );
}

SyncCategory _categoryFromName(String name) => SyncCategory.values.firstWhere(
      (category) => category.name == name,
      orElse: () => throw FormatException('unknown stored category: $name'),
    );

SyncVersion _versionFromRow(Map<String, Object?> row) => SyncVersion(
      wall: row['wall']! as int,
      logical: row['logical']! as int,
      device: row['device']! as String,
    );

SyncVersion? _baseVersionFromRow(Map<String, Object?> row) {
  final wall = row['base_wall'];
  if (wall == null) return null;
  return SyncVersion(
    wall: wall as int,
    logical: row['base_logical']! as int,
    device: row['base_device']! as String,
  );
}

String _externalKey(SyncCategory category, _KeyParts key) {
  switch (category) {
    case SyncCategory.history:
      return jsonEncode([key.key1, key.key2, key.key3]);
    case SyncCategory.sourceSettings:
      return jsonEncode([key.key1, key.key2]);
    case SyncCategory.bindings:
    case SyncCategory.chapterRules:
    case SyncCategory.settings:
    case SyncCategory.credentials:
      return key.key1;
  }
}

_KeyParts _parseKey(SyncCategory category, String key) {
  switch (category) {
    case SyncCategory.history:
      final decoded = _decodeListKey(key, 3);
      if (decoded[0] != 'history' && decoded[0] != 'subscribe') {
        throw const FormatException('invalid history record kind');
      }
      if (decoded[1].isEmpty || decoded[2].isEmpty) {
        throw const FormatException('history natural key parts must not be empty');
      }
      return _KeyParts(decoded[0], decoded[1], decoded[2]);
    case SyncCategory.sourceSettings:
      final decoded = _decodeListKey(key, 2);
      if (decoded[0].isEmpty || !_isSourceSettingKey(decoded[1])) {
        throw const FormatException('invalid source setting natural key');
      }
      return _KeyParts(decoded[0], decoded[1]);
    case SyncCategory.settings:
      if (!_settingsAllowlist.contains(key)) {
        throw FormatException('setting is not syncable: $key');
      }
      return _KeyParts(key);
    case SyncCategory.bindings:
      if (key != 'graph') {
        throw const FormatException('bindings key must be graph');
      }
      return const _KeyParts('graph');
    case SyncCategory.chapterRules:
      if (key != 'rules') {
        throw const FormatException('chapterRules key must be rules');
      }
      return const _KeyParts('rules');
    case SyncCategory.credentials:
      if (key != 'accounts') {
        throw const FormatException('credentials key must be accounts');
      }
      return const _KeyParts('accounts');
  }
}

List<String> _decodeListKey(String key, int length) {
  Object? decoded;
  try {
    decoded = jsonDecode(key);
  } on FormatException {
    throw const FormatException('record key is not valid JSON');
  }
  if (decoded is! List ||
      decoded.length != length ||
      decoded.any((value) => value is! String)) {
    throw const FormatException('record key has an invalid natural key');
  }
  return decoded.cast<String>();
}

Future<Map<String, dynamic>?> _loadValue(
  sqflite.DatabaseExecutor database,
  SyncCategory category,
  _KeyParts key,
) async {
  switch (category) {
    case SyncCategory.history:
      if (key.key1 == 'history') {
        final rows = await database.query(
          'ComicHistoryEntity',
          where: 'providerName = ? AND comicId = ?',
          whereArgs: [key.key2, key.key3],
          orderBy: 'id DESC',
          limit: 1,
        );
        if (rows.isEmpty) return null;
        final row = rows.single;
        return {
          'comicId': row['comicId'],
          'title': row['title'],
          'cover': row['cover'],
          'coverType': row['coverType'],
          'lastChapterTitle': row['lastChapterTitle'],
          'lastChapterId': row['lastChapterId'],
          'lastPage': row['lastPage'],
          'timestamp': row['timestamp'],
          'providerName': row['providerName'],
        };
      }
      final rows = await database.query(
        'ComicSubscribeStateEntity',
        where: 'providerName = ? AND comicId = ?',
        whereArgs: [key.key2, key.key3],
        orderBy: 'id DESC',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final row = rows.single;
      return {
        'comicId': row['comicId'],
        'timestamp': row['timestamp'],
        'providerName': row['providerName'],
      };
    case SyncCategory.settings:
      final rows = await database.query(
        'ConfigEntity',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [key.key1],
        orderBy: 'id DESC',
        limit: 1,
      );
      return rows.isEmpty ? null : {'value': rows.single['value']};
    case SyncCategory.sourceSettings:
      final rows = await database.query(
        'ModelConfigEntity',
        columns: ['value'],
        where: "COALESCE(sourceModel, '') = ? AND key = ?",
        whereArgs: [key.key1, key.key2],
        orderBy: 'id DESC',
        limit: 1,
      );
      return rows.isEmpty ? null : {'value': rows.single['value']};
    case SyncCategory.bindings:
      final rows = await database.query(
        'ComicMappingEntity',
        columns: ['providerA', 'comicA', 'providerB', 'comicB', 'blocked'],
        orderBy: 'providerA, comicA, providerB, comicB',
      );
      return {
        'edges': [
          for (final row in rows)
            {
              'providerA': row['providerA'],
              'comicA': row['comicA'],
              'providerB': row['providerB'],
              'comicB': row['comicB'],
              'blocked': row['blocked'] == 1,
            },
        ],
      };
    case SyncCategory.chapterRules:
      final groups = await database.query(
        'ChapterRuleGroupEntity',
        columns: ['id', 'name'],
        orderBy: 'id ASC',
      );
      final result = <Map<String, dynamic>>[];
      for (final group in groups) {
        final patterns = await database.query(
          'ChapterRulePatternEntity',
          columns: ['pattern'],
          where: 'groupId = ?',
          whereArgs: [group['id']],
          orderBy: 'id ASC',
        );
        result.add({
          'name': group['name'],
          'patterns': [for (final row in patterns) row['pattern']],
        });
      }
      return {'groups': result};
    case SyncCategory.credentials:
      final cookieRows = await database.query(
        'CookieEntity',
        columns: ['id', 'key', 'value'],
        orderBy: 'key ASC, id DESC',
      );
      final configRows = await database.query(
        'ModelConfigEntity',
        columns: ['id', 'sourceModel', 'key', 'value'],
        orderBy: 'sourceModel ASC, key ASC, id DESC',
      );
      final cookieKeys = <String>{};
      final configKeys = <String>{};
      return {
        'cookies': [
          for (final row in cookieRows)
            if (cookieKeys.add(row['key']! as String))
              {'key': row['key'], 'value': row['value']},
        ],
        'configs': [
          for (final row in configRows)
            if (_isCredentialKey(row['key']! as String) &&
                configKeys.add(jsonEncode([
                  (row['sourceModel'] as String?) ?? '',
                  row['key'],
                ])))
              {
                'sourceModel': (row['sourceModel'] as String?) ?? '',
                'key': row['key'],
                'value': row['value'],
              },
        ],
      };
  }
}

SyncRecord _validateRecord(SyncRecord record) {
  _validateSyncVersion(record.version, 'version');
  final baseVersion = record.baseVersion;
  if (baseVersion != null) {
    _validateSyncVersion(baseVersion, 'baseVersion');
  }
  _parseKey(record.category, record.key);
  final value = record.deleted
      ? null
      : _validateValue(record.category, record.key, record.value);
  return SyncRecord(
    category: record.category,
    key: record.key,
    value: value,
    deleted: record.deleted,
    version: record.version,
    uncertain: record.uncertain,
    baseVersion: record.baseVersion,
  );
}

void _validateSyncVersion(SyncVersion version, String field) {
  if (version.wall < 0 || version.wall > _maximumSyncTimestamp) {
    throw FormatException('$field.wall is outside the supported date range');
  }
  if (version.logical < 0 || version.device.isEmpty) {
    throw FormatException('$field is invalid');
  }
}

Map<String, dynamic> _validateValue(
  SyncCategory category,
  String key,
  Map<String, dynamic>? value,
) {
  if (value == null) {
    throw const FormatException('non-deleted sync record requires an object');
  }
  switch (category) {
    case SyncCategory.history:
      final parts = _parseKey(category, key);
      return parts.key1 == 'history'
          ? _validateHistoryValue(value, parts)
          : _validateSubscribeValue(value, parts);
    case SyncCategory.settings:
      return _validateSettingValue(key, value);
    case SyncCategory.sourceSettings:
      final parts = _parseKey(category, key);
      return _validateSourceSettingValue(parts.key2, value);
    case SyncCategory.bindings:
      return _validateBindings(value);
    case SyncCategory.chapterRules:
      return _validateChapterRules(value);
    case SyncCategory.credentials:
      return _validateCredentials(value);
  }
}

Map<String, dynamic> _validateHistoryValue(
  Map<String, dynamic> value,
  _KeyParts key,
) {
  final checked = Map<String, dynamic>.from(value);
  checked.putIfAbsent('lastPage', () => 1);
  _requireExactKeys(checked, const {
    'comicId',
    'title',
    'cover',
    'coverType',
    'lastChapterTitle',
    'lastChapterId',
    'lastPage',
    'timestamp',
    'providerName',
  });
  if (checked['comicId'] != key.key3 ||
      checked['providerName'] != key.key2) {
    throw const FormatException('history payload does not match its key');
  }
  for (final field in const [
    'comicId',
    'title',
    'cover',
    'lastChapterTitle',
    'lastChapterId',
    'providerName',
  ]) {
    if (checked[field] is! String) {
      throw FormatException('history.$field must be a string');
    }
  }
  final coverType = checked['coverType'];
  if (coverType is! int || coverType < 0 || coverType > 3) {
    throw const FormatException('history.coverType is invalid');
  }
  final lastPage = checked['lastPage'];
  if (lastPage is! int || lastPage < 1) {
    throw const FormatException('history.lastPage must be a positive integer');
  }
  _validateNullableTimestamp(checked['timestamp'], 'history.timestamp');
  return checked;
}

Map<String, dynamic> _validateSubscribeValue(
  Map<String, dynamic> value,
  _KeyParts key,
) {
  _requireExactKeys(value, const {'comicId', 'timestamp', 'providerName'});
  if (value['comicId'] != key.key3 || value['providerName'] != key.key2) {
    throw const FormatException('subscribe payload does not match its key');
  }
  _validateNullableTimestamp(value['timestamp'], 'subscribe.timestamp');
  return Map<String, dynamic>.from(value);
}

void _validateNullableTimestamp(Object? value, String field) {
  if (value != null &&
      (value is! int || value < 0 || value > _maximumSyncTimestamp)) {
    throw FormatException(
      '$field must be null or a timestamp in the supported date range',
    );
  }
}

Map<String, dynamic> _validateSettingValue(
  String key,
  Map<String, dynamic> value,
) {
  _requireExactKeys(value, const {'value'});
  final raw = value['value'];
  if (raw is! String) {
    throw FormatException('$key must have a persisted string value');
  }
  switch (key) {
    case 'ThemeMode':
    case 'ReadDirection':
      _parseBoundedInt(raw, key, 0, 2);
      break;
    case 'UseMaterial3Design':
    case 'AggregateSubscribeBadges':
    case 'AggregateReadingProgress':
    case 'ResumeLastReadPage':
    case 'AutoMapMissingComics':
    case 'AutoMapRetryEveryLaunch':
      _validateStoredBool(raw, key);
      break;
    case 'ThemeColor':
      const colors = {
        'Blue', 'Red', 'Pink', 'Purple', 'DeepPurple', 'Indigo',
        'LightBlue', 'Cyan', 'Teal', 'LightGreen', 'Lime', 'Yellow',
        'Amber', 'Orange', 'DeepOrange', 'Brown', 'Grey', 'BlueGrey',
      };
      if (!colors.contains(raw)) throw FormatException('invalid $key');
      break;
    case 'ReaderTheme':
      if (!const {'app', 'white', 'light', 'dark', 'black'}.contains(raw)) {
        throw FormatException('invalid $key');
      }
      break;
    case 'ReaderEndAction':
      if (!const {'nextChapter', 'comments'}.contains(raw)) {
        throw FormatException('invalid $key');
      }
      break;
    case 'HorizontalImageFit':
      if (!const {
        'original',
        'actualSize',
        'contain',
        'cover',
        'stretch',
        'fitHeight',
      }.contains(raw)) {
        throw FormatException('invalid $key');
      }
      break;
    case 'VerticalImageFit':
      if (!const {
        'original',
        'actualSize',
        'contain',
        'cover',
        'stretch',
        'fitWidth',
      }.contains(raw)) {
        throw FormatException('invalid $key');
      }
      break;
    case 'HorizontalClickAreaPercent':
    case 'VerticalClickAreaPercent':
      final number = double.tryParse(raw);
      if (number == null || !number.isFinite || number < 5 || number > 40) {
        throw FormatException('invalid $key');
      }
      break;
    // Legacy wire records and deletion acknowledgements remain readable while
    // ConfigProvider migrates pixel settings to the percentage keys.
    case 'HorizontalClickAreaSize':
    case 'VerticalClickAreaSize':
      final number = double.tryParse(raw);
      if (number == null || !number.isFinite || number < 1 || number > 1000) {
        throw FormatException('invalid $key');
      }
      break;
    case 'AutoMapIntervalSeconds':
      _parseBoundedInt(raw, key, 1, 86400);
      break;
    case 'AutoMapMaxAttempts':
      _parseBoundedInt(raw, key, 1, 1000);
      break;
    case 'activeHomeModelIndex':
      _parseBoundedInt(raw, key, 0, 1000);
      break;
    case 'sourceModelSortOrder':
      Object? decoded;
      try {
        decoded = jsonDecode(raw);
      } on FormatException {
        throw const FormatException('invalid sourceModelSortOrder JSON');
      }
      if (decoded is! Map || decoded.length > 100) {
        throw const FormatException('invalid sourceModelSortOrder map');
      }
      final positions = <int>{};
      for (final entry in decoded.entries) {
        if (entry.key is! String ||
            (entry.key as String).isEmpty ||
            entry.value is! int ||
            (entry.value as int) < 0 ||
            (entry.value as int) > 1000 ||
            !positions.add(entry.value as int)) {
          throw const FormatException('invalid sourceModelSortOrder entry');
        }
      }
      break;
    default:
      throw FormatException('setting is not syncable: $key');
  }
  return {'value': raw};
}

Map<String, dynamic> _validateSourceSettingValue(
  String key,
  Map<String, dynamic> value,
) {
  _requireExactKeys(value, const {'value'});
  final raw = value['value'];
  if (raw is! String) {
    throw FormatException('$key must have a persisted string value');
  }
  switch (key) {
    case 'chineseDisplayLanguage':
      if (!const {'traditional', 'simplified'}.contains(raw)) {
        throw const FormatException('invalid Chinese display language');
      }
      break;
    case 'apiDomain':
    case 'chapterCommentApiDomain':
      const domains = {
        'api.mangacopy.com',
        'mapi.copy20.com',
        'mapi.copy2000.site',
        'api.2026copy.com',
        'api.copy3000.com',
        'api.copy4000.com',
        'mapi.hotmangasd.com',
        'api.manga2025.com',
        'mapi.hotmangasf.com',
        'mapi.hotmangasg.com',
        'mapi.elfgjfghkk.club',
        'mapi.fgjfghkk.club',
        'mapi.fgjfghkkcenter.club',
      };
      if (raw.isNotEmpty && !domains.contains(raw)) {
        throw const FormatException('invalid API domain');
      }
      break;
    case 'autoSignInEnabled':
      _validateStoredBool(raw, key);
      break;
    default:
      throw FormatException('source setting is not syncable: $key');
  }
  return {'value': raw};
}

Map<String, dynamic> _validateBindings(Map<String, dynamic> value) {
  _requireExactKeys(value, const {'edges'});
  final rawEdges = value['edges'];
  if (rawEdges is! List || rawEdges.length > 100000) {
    throw const FormatException('bindings.edges must be a bounded array');
  }
  final result = <Map<String, dynamic>>[];
  final exact = <String>{};
  final activeEndpoints = <String>{};
  for (final raw in rawEdges) {
    if (raw is! Map) throw const FormatException('binding edge must be an object');
    final edge = Map<String, dynamic>.from(raw);
    _requireExactKeys(edge, const {
      'providerA', 'comicA', 'providerB', 'comicB', 'blocked',
    });
    final providerA = edge['providerA'];
    final comicA = edge['comicA'];
    final providerB = edge['providerB'];
    final comicB = edge['comicB'];
    final blocked = edge['blocked'];
    if (providerA is! String ||
        providerA.isEmpty ||
        providerB is! String ||
        providerB.isEmpty ||
        comicA is! String ||
        comicB is! String ||
        blocked is! bool ||
        (providerA == providerB && comicA == comicB) ||
        (!blocked && (comicA.isEmpty || comicB.isEmpty)) ||
        (comicA.isEmpty && comicB.isEmpty)) {
      throw const FormatException('binding edge fields are invalid');
    }
    final order = providerA.compareTo(providerB);
    if (order > 0 || (order == 0 && comicA.compareTo(comicB) > 0)) {
      throw const FormatException('binding edge is not canonical');
    }
    final identity = jsonEncode([providerA, comicA, providerB, comicB]);
    if (!exact.add(identity)) {
      throw const FormatException('duplicate binding edge');
    }
    if (!blocked) {
      final left = jsonEncode([providerA, comicA, providerB]);
      final right = jsonEncode([providerB, comicB, providerA]);
      if (!activeEndpoints.add(left) || !activeEndpoints.add(right)) {
        throw const FormatException('conflicting active binding endpoints');
      }
    }
    result.add({
      'providerA': providerA,
      'comicA': comicA,
      'providerB': providerB,
      'comicB': comicB,
      'blocked': blocked,
    });
  }
  result.sort((left, right) => jsonEncode(left).compareTo(jsonEncode(right)));
  return {'edges': result};
}

Map<String, dynamic> _validateChapterRules(Map<String, dynamic> value) {
  _requireExactKeys(value, const {'groups'});
  final rawGroups = value['groups'];
  if (rawGroups is! List || rawGroups.length > 1000) {
    throw const FormatException('chapter rule groups must be a bounded array');
  }
  final groups = <Map<String, dynamic>>[];
  var patternCount = 0;
  for (final raw in rawGroups) {
    if (raw is! Map) throw const FormatException('chapter rule group is invalid');
    final group = Map<String, dynamic>.from(raw);
    _requireExactKeys(group, const {'name', 'patterns'});
    final name = group['name'];
    final patterns = group['patterns'];
    if (name is! String ||
        name.trim().isEmpty ||
        name.length > 200 ||
        patterns is! List) {
      throw const FormatException('chapter rule group fields are invalid');
    }
    final checkedPatterns = <String>[];
    for (final pattern in patterns) {
      patternCount++;
      if (patternCount > 10000 || pattern is! String || pattern.length > 4000) {
        throw const FormatException('chapter rule pattern is invalid');
      }
      final error = validateChapterPattern(pattern);
      if (error != null) throw FormatException(error);
      checkedPatterns.add(pattern);
    }
    groups.add({'name': name, 'patterns': checkedPatterns});
  }
  return {'groups': groups};
}

Map<String, dynamic> _validateCredentials(Map<String, dynamic> value) {
  _requireExactKeys(value, const {'cookies', 'configs'});
  final rawCookies = value['cookies'];
  final rawConfigs = value['configs'];
  if (rawCookies is! List ||
      rawConfigs is! List ||
      rawCookies.length + rawConfigs.length > 100000) {
    throw const FormatException('credentials collections are invalid');
  }
  final cookies = <Map<String, dynamic>>[];
  final cookieKeys = <String>{};
  for (final raw in rawCookies) {
    if (raw is! Map) throw const FormatException('cookie must be an object');
    final cookie = Map<String, dynamic>.from(raw);
    _requireExactKeys(cookie, const {'key', 'value'});
    final key = cookie['key'];
    final cookieValue = cookie['value'];
    if (key is! String ||
        key.isEmpty ||
        cookieValue is! String ||
        !cookieKeys.add(key)) {
      throw const FormatException('cookie fields are invalid');
    }
    cookies.add({'key': key, 'value': cookieValue});
  }
  final configs = <Map<String, dynamic>>[];
  final configKeys = <String>{};
  for (final raw in rawConfigs) {
    if (raw is! Map) {
      throw const FormatException('credential config must be an object');
    }
    final config = Map<String, dynamic>.from(raw);
    _requireExactKeys(config, const {'sourceModel', 'key', 'value'});
    final source = config['sourceModel'];
    final key = config['key'];
    final configValue = config['value'];
    if (source is! String ||
        key is! String ||
        !_isCredentialKey(key) ||
        (configValue != null && configValue is! String) ||
        !configKeys.add(jsonEncode([source, key]))) {
      throw const FormatException('credential config fields are invalid');
    }
    configs.add({'sourceModel': source, 'key': key, 'value': configValue});
  }
  cookies.sort((left, right) =>
      (left['key']! as String).compareTo(right['key']! as String));
  configs.sort((left, right) => jsonEncode(left).compareTo(jsonEncode(right)));
  return {'cookies': cookies, 'configs': configs};
}

void _requireExactKeys(Map<String, dynamic> value, Set<String> expected) {
  if (value.length != expected.length || !value.keys.toSet().containsAll(expected)) {
    throw const FormatException('sync payload contains missing or unknown fields');
  }
}

void _validateStoredBool(String raw, String key) {
  if (raw != '0' && raw != '1') throw FormatException('invalid $key');
}

int _parseBoundedInt(String raw, String key, int minimum, int maximum) {
  final value = int.tryParse(raw);
  if (value == null || value < minimum || value > maximum) {
    throw FormatException('invalid $key');
  }
  return value;
}

Future<void> _applyBusinessRecord(
  sqflite.DatabaseExecutor database,
  SyncRecord record,
) async {
  final key = _parseKey(record.category, record.key);
  final value = record.value;
  switch (record.category) {
    case SyncCategory.history:
      final table = key.key1 == 'history'
          ? 'ComicHistoryEntity'
          : 'ComicSubscribeStateEntity';
      await database.delete(
        table,
        where: 'providerName = ? AND comicId = ?',
        whereArgs: [key.key2, key.key3],
      );
      if (!record.deleted) {
        await database.insert(table, Map<String, Object?>.from(value!));
      }
      break;
    case SyncCategory.settings:
      await database.delete(
        'ConfigEntity',
        where: 'key = ?',
        whereArgs: [key.key1],
      );
      if (!record.deleted) {
        await database.insert(
          'ConfigEntity',
          {'key': key.key1, 'value': value!['value']},
        );
      }
      break;
    case SyncCategory.sourceSettings:
      await database.delete(
        'ModelConfigEntity',
        where: "COALESCE(sourceModel, '') = ? AND key = ?",
        whereArgs: [key.key1, key.key2],
      );
      if (!record.deleted) {
        await database.insert('ModelConfigEntity', {
          'sourceModel': key.key1,
          'key': key.key2,
          'value': value!['value'],
        });
      }
      break;
    case SyncCategory.bindings:
      await database.delete('ComicMappingEntity');
      if (!record.deleted) {
        for (final raw in value!['edges']! as List) {
          final edge = Map<String, dynamic>.from(raw as Map);
          await database.insert('ComicMappingEntity', {
            ...edge,
            'blocked': edge['blocked'] == true ? 1 : 0,
          });
        }
      }
      break;
    case SyncCategory.chapterRules:
      await database.delete('ChapterRulePatternEntity');
      await database.delete('ChapterRuleGroupEntity');
      if (!record.deleted) {
        for (final raw in value!['groups']! as List) {
          final group = Map<String, dynamic>.from(raw as Map);
          final groupId = await database.insert(
            'ChapterRuleGroupEntity',
            {'name': group['name']},
          );
          for (final pattern in group['patterns']! as List) {
            await database.insert('ChapterRulePatternEntity', {
              'groupId': groupId,
              'pattern': pattern,
            });
          }
        }
      }
      break;
    case SyncCategory.credentials:
      await database.delete('CookieEntity');
      final credentialRows = await database.query(
        'ModelConfigEntity',
        columns: ['id', 'key'],
      );
      for (final row in credentialRows) {
        if (_isCredentialKey(row['key']! as String)) {
          await database.delete(
            'ModelConfigEntity',
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }
      if (!record.deleted) {
        for (final raw in value!['cookies']! as List) {
          final cookie = Map<String, dynamic>.from(raw as Map);
          await database.insert('CookieEntity', cookie);
        }
        for (final raw in value['configs']! as List) {
          final config = Map<String, dynamic>.from(raw as Map);
          await database.insert('ModelConfigEntity', config);
        }
      }
      break;
  }
}

Future<void> _putMetadata(
  sqflite.DatabaseExecutor database,
  String account,
  SyncRecord record, {
  required bool pending,
}) async {
  final key = _parseKey(record.category, record.key);
  await database.insert(
    _recordTable,
    {
      'account': account,
      'category': record.category.name,
      'key1': key.key1,
      'key2': key.key2,
      'key3': key.key3,
      'deleted': record.deleted ? 1 : 0,
      'wall': record.version.wall,
      'logical': record.version.logical,
      'device': record.version.device,
      'uncertain': record.uncertain ? 1 : 0,
      'base_wall': record.baseVersion?.wall,
      'base_logical': record.baseVersion?.logical,
      'base_device': record.baseVersion?.device,
      'pending': pending ? 1 : 0,
      'baseline': 0,
    },
    conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
  );
}

Future<void> _setPending(
  sqflite.DatabaseExecutor database,
  String account,
  SyncCategory category,
  _KeyParts key,
  bool pending,
) =>
    database.update(
      _recordTable,
      {'pending': pending ? 1 : 0},
      where:
          'account = ? AND category = ? AND key1 = ? AND key2 = ? AND key3 = ?',
      whereArgs: [account, category.name, key.key1, key.key2, key.key3],
    );

Future<SyncVersion> _nextVersion(
  sqflite.DatabaseExecutor database, {
  bool requireTrusted = false,
}) async {
  final row = (await database.query(
    _stateTable,
    where: 'id = 1',
    limit: 1,
  )).single;
  final trusted = row['trusted'] == 1;
  if (requireTrusted && !trusted) {
    throw StateError('clock calibration is required to resolve conflicts');
  }
  final oldWall = row['wall']! as int;
  final anchor = trusted ? row['anchor_wall']! as int : 0;
  final wall = max(oldWall, anchor);
  final logical = anchor > oldWall ? 0 : (row['logical']! as int) + 1;
  await database.update(
    _stateTable,
    {'wall': wall, 'logical': logical},
    where: 'id = 1',
  );
  return SyncVersion(
    wall: wall,
    logical: logical,
    device: row['device_id']! as String,
  );
}

Future<(SyncVersion, bool)> _nextVersionAfter(
  sqflite.DatabaseExecutor database,
  SyncVersion? floor,
) async {
  final next = await _nextVersion(database);
  if (floor == null || next.compareTo(floor) > 0) return (next, false);
  return (
    SyncVersion(
      wall: floor.wall,
      logical: floor.logical + 1,
      device: next.device,
    ),
    true,
  );
}

Future<void> _observeVersion(
  sqflite.DatabaseExecutor database,
  SyncVersion remote,
) async {
  final row = (await database.query(
    _stateTable,
    columns: ['wall', 'logical'],
    where: 'id = 1',
    limit: 1,
  )).single;
  final wall = row['wall']! as int;
  final logical = row['logical']! as int;
  if (remote.wall > wall) {
    await database.update(
      _stateTable,
      {'wall': remote.wall, 'logical': remote.logical + 1},
      where: 'id = 1',
    );
  } else if (remote.wall == wall) {
    await database.update(
      _stateTable,
      {'logical': max(logical, remote.logical) + 1},
      where: 'id = 1',
    );
  } else {
    await database.update(
      _stateTable,
      {'logical': logical + 1},
      where: 'id = 1',
    );
  }
}

Future<void> _insertConflict(
  sqflite.DatabaseExecutor database,
  String account,
  SyncRecord local,
  SyncRecord remote,
) async {
  final identity = jsonEncode({
    'category': local.category.name,
    'key': local.key,
    'local': local.version.toJson(),
    'remote': remote.version.toJson(),
  });
  final id = sha256.convert(utf8.encode(identity)).toString();
  await database.insert(
    _conflictTable,
    {
      'account': account,
      'id': id,
      'local_record': jsonEncode(local.toJson()),
      'remote_record': jsonEncode(remote.toJson()),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    },
    conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
  );
}

bool _sameRecordContent(SyncRecord left, SyncRecord right) =>
    left.deleted == right.deleted &&
    jsonEncode(_canonicalSyncJson(left.value)) ==
        jsonEncode(_canonicalSyncJson(right.value));

Object? _canonicalSyncJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _canonicalSyncJson(value[key])};
  }
  if (value is List) {
    return value.map(_canonicalSyncJson).toList(growable: false);
  }
  return value;
}

bool _emptyAggregate(SyncRecord record) {
  if (record.deleted) return false;
  final value = record.value;
  return switch (record.category) {
    SyncCategory.bindings => (value?['edges'] as List?)?.isEmpty == true,
    SyncCategory.chapterRules => (value?['groups'] as List?)?.isEmpty == true,
    SyncCategory.credentials =>
      (value?['cookies'] as List?)?.isEmpty == true &&
          (value?['configs'] as List?)?.isEmpty == true,
    _ => false,
  };
}

Map<String, dynamic> _validatedJsonMap(
  Map<String, dynamic> value,
  String field,
) {
  try {
    final decoded = jsonDecode(jsonEncode(value));
    if (decoded is! Map) throw const FormatException();
    return Map<String, dynamic>.from(decoded);
  } on Object {
    throw FormatException('$field must contain only JSON values');
  }
}
