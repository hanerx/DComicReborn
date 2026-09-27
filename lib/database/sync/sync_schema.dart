part of 'sync_store.dart';

const _schemaTable = '_dcomic_sync_schema';
const _stateTable = '_dcomic_sync_state';
const _recordTable = '_dcomic_sync_records';
const _preferenceTable = '_dcomic_sync_preferences';
const _conflictTable = '_dcomic_sync_conflicts';
const _resolutionTable = '_dcomic_sync_resolutions';
const _accountSnapshotTable = '_dcomic_sync_account_snapshots';
const _notificationTable = '_dcomic_sync_notifications';

const _settingsAllowlist = <String>{
  'ThemeMode',
  'ReadDirection',
  'HorizontalClickAreaSize',
  'VerticalClickAreaSize',
  'ThemeColor',
  'UseMaterial3Design',
  'ReaderTheme',
  'AggregateSubscribeBadges',
  'AggregateReadingProgress',
  'AutoMapMissingComics',
  'AutoMapIntervalSeconds',
  'AutoMapRetryEveryLaunch',
  'AutoMapMaxAttempts',
  'sourceModelSortOrder',
  'activeHomeModelIndex',
};

const _sourceSettingsAllowlist = <String>{
  'chineseDisplayLanguage',
  'apiDomain',
  'chapterCommentApiDomain',
  'autoSignInEnabled',
};

const _credentialKeyNames = <String>{
  'token',
  'islogin',
  'username',
  'password',
  'userid',
  'uid',
  'refreshtoken',
  'accesstoken',
};

bool _isCredentialKey(String key) {
  final lower = key.toLowerCase();
  return _credentialKeyNames.contains(lower) ||
      lower.contains('password') ||
      lower.contains('token') ||
      lower.contains('secret') ||
      lower.contains('cookie');
}

bool _isSourceSettingKey(String key) =>
    _sourceSettingsAllowlist.contains(key) && !_isCredentialKey(key);

String _sqlList(Iterable<String> values) =>
    values.map((value) => "'${value.replaceAll("'", "''")}'").join(',');

String get _settingsSql => 'key IN (${_sqlList(_settingsAllowlist)})';
String get _newSettingsSql => 'NEW.key IN (${_sqlList(_settingsAllowlist)})';
String get _oldSettingsSql => 'OLD.key IN (${_sqlList(_settingsAllowlist)})';
String get _newSourceSettingSql =>
    'NEW.key IN (${_sqlList(_sourceSettingsAllowlist)})';
String get _oldSourceSettingSql =>
    'OLD.key IN (${_sqlList(_sourceSettingsAllowlist)})';

String _credentialSql(String prefix) {
  final key = '$prefix.key';
  final lower = 'lower($key)';
  return '($lower IN (${_sqlList(_credentialKeyNames)}) '
      "OR $lower LIKE '%password%' OR $lower LIKE '%token%' "
      "OR $lower LIKE '%secret%' OR $lower LIKE '%cookie%')";
}

Future<void> _installSyncSchema(sqflite.Database database) async {
  await database.transaction((transaction) async {
    await transaction.execute(
      'CREATE TABLE IF NOT EXISTS $_schemaTable ('
      'version INTEGER NOT NULL PRIMARY KEY)',
    );
    await transaction.insert(
      _schemaTable,
      {'version': 1},
      conflictAlgorithm: sqflite.ConflictAlgorithm.ignore,
    );
    await transaction.execute(
      'CREATE TABLE IF NOT EXISTS $_stateTable ('
      'id INTEGER NOT NULL PRIMARY KEY CHECK (id = 1), '
      'device_id TEXT NOT NULL, wall INTEGER NOT NULL, logical INTEGER NOT NULL, '
      'trusted INTEGER NOT NULL, anchor_wall INTEGER NOT NULL, '
      "active_account TEXT NOT NULL DEFAULT '', suppress INTEGER NOT NULL DEFAULT 0)",
    );
    await transaction.insert(
      _stateTable,
      {
        'id': 1,
        'device_id': _randomDeviceId(),
        'wall': 0,
        'logical': 0,
        'trusted': 0,
        'anchor_wall': 0,
        'active_account': '',
        'suppress': 0,
      },
      conflictAlgorithm: sqflite.ConflictAlgorithm.ignore,
    );
    await transaction.execute(
      'CREATE TABLE IF NOT EXISTS $_recordTable ('
      'account TEXT NOT NULL, category TEXT NOT NULL, '
      "key1 TEXT NOT NULL, key2 TEXT NOT NULL DEFAULT '', key3 TEXT NOT NULL DEFAULT '', "
      'deleted INTEGER NOT NULL, wall INTEGER NOT NULL, logical INTEGER NOT NULL, '
      'device TEXT NOT NULL, uncertain INTEGER NOT NULL, '
      'base_wall INTEGER, base_logical INTEGER, base_device TEXT, '
      'pending INTEGER NOT NULL, baseline INTEGER NOT NULL DEFAULT 0, '
      'PRIMARY KEY (account, category, key1, key2, key3))',
    );
    final recordColumns = await transaction.rawQuery(
      'PRAGMA table_info($_recordTable)',
    );
    if (!recordColumns.any((row) => row['name'] == 'baseline')) {
      await transaction.execute(
        'ALTER TABLE $_recordTable '
        'ADD COLUMN baseline INTEGER NOT NULL DEFAULT 0',
      );
    }
    await transaction.execute(
      'CREATE TABLE IF NOT EXISTS $_resolutionTable ('
      'account TEXT NOT NULL, wall INTEGER NOT NULL, logical INTEGER NOT NULL, '
      'device TEXT NOT NULL, conflict_id TEXT NOT NULL, record_json TEXT NOT NULL, '
      'PRIMARY KEY (account, wall, logical, device))',
    );
    final resolutionColumns = await transaction.rawQuery(
      'PRAGMA table_info($_resolutionTable)',
    );
    if (!resolutionColumns.any((row) => row['name'] == 'record_json')) {
      await transaction.execute(
        'ALTER TABLE $_resolutionTable ADD COLUMN record_json TEXT',
      );
    }
    await transaction.execute(
      'CREATE INDEX IF NOT EXISTS dcomic_sync_pending '
      'ON $_recordTable (account, pending, category, wall, logical)',
    );
    await transaction.execute(
      'CREATE TABLE IF NOT EXISTS $_preferenceTable ('
      'account TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL)',
    );
    await transaction.execute(
      'CREATE TABLE IF NOT EXISTS $_conflictTable ('
      'account TEXT NOT NULL, id TEXT NOT NULL, local_record TEXT NOT NULL, '
      'remote_record TEXT NOT NULL, created_at INTEGER NOT NULL, '
      'PRIMARY KEY (account, id))',
    );
    await transaction.execute(
      'CREATE TABLE IF NOT EXISTS $_accountSnapshotTable ('
      'account TEXT NOT NULL PRIMARY KEY, records_json TEXT NOT NULL)',
    );
    await transaction.execute(
      'CREATE TABLE IF NOT EXISTS $_notificationTable ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, category TEXT NOT NULL)',
    );
    await _createCaptureTriggers(transaction);
  });
}

String _randomDeviceId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

Future<void> _createCaptureTriggers(sqflite.DatabaseExecutor database) async {
  const triggerNames = <String>[
    'dcomic_sync_history_insert',
    'dcomic_sync_history_update_old',
    'dcomic_sync_history_update_new',
    'dcomic_sync_history_delete',
    'dcomic_sync_subscribe_insert',
    'dcomic_sync_subscribe_update_old',
    'dcomic_sync_subscribe_update_new',
    'dcomic_sync_subscribe_delete',
    'dcomic_sync_settings_insert',
    'dcomic_sync_settings_update_old',
    'dcomic_sync_settings_update_new',
    'dcomic_sync_settings_delete',
    'dcomic_sync_source_insert',
    'dcomic_sync_source_update_old',
    'dcomic_sync_source_update_new',
    'dcomic_sync_source_delete',
    'dcomic_sync_credentials_model_insert',
    'dcomic_sync_credentials_model_update',
    'dcomic_sync_credentials_model_delete',
    'dcomic_sync_credentials_cookie_insert',
    'dcomic_sync_credentials_cookie_update',
    'dcomic_sync_credentials_cookie_delete',
    'dcomic_sync_bindings_insert',
    'dcomic_sync_bindings_update',
    'dcomic_sync_bindings_delete',
    'dcomic_sync_rules_group_insert',
    'dcomic_sync_rules_group_update',
    'dcomic_sync_rules_group_delete',
    'dcomic_sync_rules_pattern_insert',
    'dcomic_sync_rules_pattern_update',
    'dcomic_sync_rules_pattern_delete',
  ];
  for (final name in triggerNames) {
    await database.execute('DROP TRIGGER IF EXISTS $name');
  }

  await _createTrigger(
    database,
    'dcomic_sync_history_insert',
    'AFTER INSERT ON ComicHistoryEntity',
    _captureBody(
      SyncCategory.history,
      "'history'",
      'NEW.providerName',
      'NEW.comicId',
      '0',
    ),
  );
  await _createTrigger(
    database,
    'dcomic_sync_history_update_old',
    'AFTER UPDATE ON ComicHistoryEntity',
    _captureBody(
      SyncCategory.history,
      "'history'",
      'OLD.providerName',
      'OLD.comicId',
      "CASE WHEN EXISTS (SELECT 1 FROM ComicHistoryEntity WHERE providerName = OLD.providerName AND comicId = OLD.comicId) THEN 0 ELSE 1 END",
    ),
    when:
        'OLD.providerName <> NEW.providerName OR OLD.comicId <> NEW.comicId',
  );
  await _createTrigger(
    database,
    'dcomic_sync_history_update_new',
    'AFTER UPDATE ON ComicHistoryEntity',
    _captureBody(
      SyncCategory.history,
      "'history'",
      'NEW.providerName',
      'NEW.comicId',
      '0',
    ),
  );
  await _createTrigger(
    database,
    'dcomic_sync_history_delete',
    'AFTER DELETE ON ComicHistoryEntity',
    _captureBody(
      SyncCategory.history,
      "'history'",
      'OLD.providerName',
      'OLD.comicId',
      "CASE WHEN EXISTS (SELECT 1 FROM ComicHistoryEntity WHERE providerName = OLD.providerName AND comicId = OLD.comicId) THEN 0 ELSE 1 END",
    ),
  );

  await _createTrigger(
    database,
    'dcomic_sync_subscribe_insert',
    'AFTER INSERT ON ComicSubscribeStateEntity',
    _captureBody(
      SyncCategory.history,
      "'subscribe'",
      'NEW.providerName',
      'NEW.comicId',
      '0',
    ),
  );
  await _createTrigger(
    database,
    'dcomic_sync_subscribe_update_old',
    'AFTER UPDATE ON ComicSubscribeStateEntity',
    _captureBody(
      SyncCategory.history,
      "'subscribe'",
      'OLD.providerName',
      'OLD.comicId',
      "CASE WHEN EXISTS (SELECT 1 FROM ComicSubscribeStateEntity WHERE providerName = OLD.providerName AND comicId = OLD.comicId) THEN 0 ELSE 1 END",
    ),
    when:
        'OLD.providerName <> NEW.providerName OR OLD.comicId <> NEW.comicId',
  );
  await _createTrigger(
    database,
    'dcomic_sync_subscribe_update_new',
    'AFTER UPDATE ON ComicSubscribeStateEntity',
    _captureBody(
      SyncCategory.history,
      "'subscribe'",
      'NEW.providerName',
      'NEW.comicId',
      '0',
    ),
  );
  await _createTrigger(
    database,
    'dcomic_sync_subscribe_delete',
    'AFTER DELETE ON ComicSubscribeStateEntity',
    _captureBody(
      SyncCategory.history,
      "'subscribe'",
      'OLD.providerName',
      'OLD.comicId',
      "CASE WHEN EXISTS (SELECT 1 FROM ComicSubscribeStateEntity WHERE providerName = OLD.providerName AND comicId = OLD.comicId) THEN 0 ELSE 1 END",
    ),
  );

  await _createTrigger(
    database,
    'dcomic_sync_settings_insert',
    'AFTER INSERT ON ConfigEntity',
    _captureBody(
      SyncCategory.settings,
      'NEW.key',
      "''",
      "''",
      '0',
    ),
    when: _newSettingsSql,
  );
  await _createTrigger(
    database,
    'dcomic_sync_settings_update_old',
    'AFTER UPDATE ON ConfigEntity',
    _captureBody(
      SyncCategory.settings,
      'OLD.key',
      "''",
      "''",
      "CASE WHEN EXISTS (SELECT 1 FROM ConfigEntity WHERE key = OLD.key) THEN 0 ELSE 1 END",
    ),
    when:
        '$_oldSettingsSql AND (NOT ($_newSettingsSql) OR OLD.key <> NEW.key)',
  );
  await _createTrigger(
    database,
    'dcomic_sync_settings_update_new',
    'AFTER UPDATE ON ConfigEntity',
    _captureBody(
      SyncCategory.settings,
      'NEW.key',
      "''",
      "''",
      '0',
    ),
    when: _newSettingsSql,
  );
  await _createTrigger(
    database,
    'dcomic_sync_settings_delete',
    'AFTER DELETE ON ConfigEntity',
    _captureBody(
      SyncCategory.settings,
      'OLD.key',
      "''",
      "''",
      "CASE WHEN EXISTS (SELECT 1 FROM ConfigEntity WHERE key = OLD.key) THEN 0 ELSE 1 END",
    ),
    when: _oldSettingsSql,
  );

  final newCredential = _credentialSql('NEW');
  final oldCredential = _credentialSql('OLD');
  await _createTrigger(
    database,
    'dcomic_sync_source_insert',
    'AFTER INSERT ON ModelConfigEntity',
    _captureBody(
      SyncCategory.sourceSettings,
      "COALESCE(NEW.sourceModel, '')",
      'NEW.key',
      "''",
      '0',
    ),
    when:
        "COALESCE(NEW.sourceModel, '') <> '' AND "
        '$_newSourceSettingSql AND NOT $newCredential',
  );
  await _createTrigger(
    database,
    'dcomic_sync_source_update_old',
    'AFTER UPDATE ON ModelConfigEntity',
    _captureBody(
      SyncCategory.sourceSettings,
      "COALESCE(OLD.sourceModel, '')",
      'OLD.key',
      "''",
      "CASE WHEN EXISTS (SELECT 1 FROM ModelConfigEntity WHERE COALESCE(sourceModel, '') = COALESCE(OLD.sourceModel, '') AND key = OLD.key) THEN 0 ELSE 1 END",
    ),
    when:
        "COALESCE(OLD.sourceModel, '') <> '' AND "
        '$_oldSourceSettingSql AND NOT $oldCredential AND '
        '($newCredential OR NOT ($_newSourceSettingSql) OR '
        "COALESCE(OLD.sourceModel, '') <> COALESCE(NEW.sourceModel, '') OR OLD.key <> NEW.key)",
  );
  await _createTrigger(
    database,
    'dcomic_sync_source_update_new',
    'AFTER UPDATE ON ModelConfigEntity',
    _captureBody(
      SyncCategory.sourceSettings,
      "COALESCE(NEW.sourceModel, '')",
      'NEW.key',
      "''",
      '0',
    ),
    when:
        "COALESCE(NEW.sourceModel, '') <> '' AND "
        '$_newSourceSettingSql AND NOT $newCredential',
  );
  await _createTrigger(
    database,
    'dcomic_sync_source_delete',
    'AFTER DELETE ON ModelConfigEntity',
    _captureBody(
      SyncCategory.sourceSettings,
      "COALESCE(OLD.sourceModel, '')",
      'OLD.key',
      "''",
      "CASE WHEN EXISTS (SELECT 1 FROM ModelConfigEntity WHERE COALESCE(sourceModel, '') = COALESCE(OLD.sourceModel, '') AND key = OLD.key) THEN 0 ELSE 1 END",
    ),
    when:
        "COALESCE(OLD.sourceModel, '') <> '' AND "
        '$_oldSourceSettingSql AND NOT $oldCredential',
  );

  await _createAggregateTriggers(
    database,
    table: 'ModelConfigEntity',
    stem: 'dcomic_sync_credentials_model',
    category: SyncCategory.credentials,
    key: 'accounts',
    insertWhen: newCredential,
    updateWhen: '$oldCredential OR $newCredential',
    deleteWhen: oldCredential,
  );
  await _createAggregateTriggers(
    database,
    table: 'CookieEntity',
    stem: 'dcomic_sync_credentials_cookie',
    category: SyncCategory.credentials,
    key: 'accounts',
  );
  await _createAggregateTriggers(
    database,
    table: 'ComicMappingEntity',
    stem: 'dcomic_sync_bindings',
    category: SyncCategory.bindings,
    key: 'graph',
  );
  await _createAggregateTriggers(
    database,
    table: 'ChapterRuleGroupEntity',
    stem: 'dcomic_sync_rules_group',
    category: SyncCategory.chapterRules,
    key: 'rules',
  );
  await _createAggregateTriggers(
    database,
    table: 'ChapterRulePatternEntity',
    stem: 'dcomic_sync_rules_pattern',
    category: SyncCategory.chapterRules,
    key: 'rules',
  );
}

Future<void> _createAggregateTriggers(
  sqflite.DatabaseExecutor database, {
  required String table,
  required String stem,
  required SyncCategory category,
  required String key,
  String? insertWhen,
  String? updateWhen,
  String? deleteWhen,
}) async {
  final body = _captureBody(category, "'$key'", "''", "''", '0');
  await _createTrigger(
    database,
    '${stem}_insert',
    'AFTER INSERT ON $table',
    body,
    when: insertWhen,
  );
  await _createTrigger(
    database,
    '${stem}_update',
    'AFTER UPDATE ON $table',
    body,
    when: updateWhen,
  );
  await _createTrigger(
    database,
    '${stem}_delete',
    'AFTER DELETE ON $table',
    body,
    when: deleteWhen,
  );
}

Future<void> _createTrigger(
  sqflite.DatabaseExecutor database,
  String name,
  String timing,
  String body, {
  String? when,
}) =>
    database.execute(
      'CREATE TRIGGER $name $timing '
      '${when == null ? '' : 'WHEN $when '}BEGIN $body END',
    );

String _captureBody(
  SyncCategory category,
  String key1,
  String key2,
  String key3,
  String deleted,
) {
  final name = category.name;
  return '''
UPDATE $_stateTable
SET logical = CASE WHEN trusted = 1 AND anchor_wall > wall THEN 0 ELSE logical + 1 END,
    wall = CASE WHEN trusted = 1 AND anchor_wall > wall THEN anchor_wall ELSE wall END
WHERE id = 1 AND suppress = 0;
UPDATE $_recordTable
SET base_wall = CASE WHEN pending = 0 AND baseline = 0 THEN wall ELSE base_wall END,
    base_logical = CASE WHEN pending = 0 AND baseline = 0 THEN logical ELSE base_logical END,
    base_device = CASE WHEN pending = 0 AND baseline = 0 THEN device ELSE base_device END,
    deleted = $deleted,
    wall = CASE
      WHEN wall > (SELECT wall FROM $_stateTable WHERE id = 1) THEN wall
      ELSE (SELECT wall FROM $_stateTable WHERE id = 1) END,
    logical = CASE
      WHEN wall > (SELECT wall FROM $_stateTable WHERE id = 1)
        OR (wall = (SELECT wall FROM $_stateTable WHERE id = 1)
            AND logical >= (SELECT logical FROM $_stateTable WHERE id = 1))
      THEN logical + 1
      ELSE (SELECT logical FROM $_stateTable WHERE id = 1) END,
    device = (SELECT device_id FROM $_stateTable WHERE id = 1),
    uncertain = CASE
      WHEN (SELECT trusted FROM $_stateTable WHERE id = 1) = 1
       AND wall <= (SELECT wall FROM $_stateTable WHERE id = 1)
      THEN 0 ELSE 1 END,
    pending = 1,
    baseline = 0
WHERE account = (SELECT active_account FROM $_stateTable WHERE id = 1)
  AND category = '$name'
  AND key1 = $key1 AND key2 = $key2 AND key3 = $key3
  AND EXISTS (SELECT 1 FROM $_stateTable WHERE id = 1 AND suppress = 0);
INSERT INTO $_recordTable
(account, category, key1, key2, key3, deleted, wall, logical, device,
 uncertain, base_wall, base_logical, base_device, pending, baseline)
SELECT s.active_account, '$name', $key1, $key2, $key3, $deleted,
       s.wall, s.logical, s.device_id, CASE WHEN s.trusted = 1 THEN 0 ELSE 1 END,
       NULL, NULL, NULL, 1, 0
FROM $_stateTable s
WHERE s.id = 1 AND s.suppress = 0
  AND NOT EXISTS (
    SELECT 1 FROM $_recordTable r
    WHERE r.account = s.active_account AND r.category = '$name'
      AND r.key1 = $key1 AND r.key2 = $key2 AND r.key3 = $key3
  );
INSERT INTO $_notificationTable(category)
SELECT '$name' FROM $_stateTable WHERE id = 1 AND suppress = 0;
''';
}
