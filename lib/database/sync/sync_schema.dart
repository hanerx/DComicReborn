part of 'sync_store.dart';

const _schemaTable = '_dcomic_sync_schema';
const _stateTable = '_dcomic_sync_state';
const _recordTable = '_dcomic_sync_records';
const _preferenceTable = '_dcomic_sync_preferences';
const _conflictTable = '_dcomic_sync_conflicts';
const _resolutionTable = '_dcomic_sync_resolutions';
const _accountSnapshotTable = '_dcomic_sync_account_snapshots';
const _notificationTable = '_dcomic_sync_notifications';

bool _isCredentialKey(String key) =>
    modelSettingDefinition(key).mode == SettingSyncMode.credential;

bool _isSourceSettingKey(String key) =>
    modelSettingDefinition(key).mode == SettingSyncMode.synced;

String get _settingsSql => settingPolicySql(
      'ConfigEntity', 'key', mode: SettingSyncMode.synced,
    );
String get _newSettingsSql => settingPolicySql(
      'ConfigEntity', 'NEW.key', mode: SettingSyncMode.synced,
    );
String get _oldSettingsSql => settingPolicySql(
      'ConfigEntity', 'OLD.key', mode: SettingSyncMode.synced,
    );
String get _newSourceSettingSql => settingPolicySql(
      'ModelConfigEntity', 'NEW.key', mode: SettingSyncMode.synced,
    );
String get _oldSourceSettingSql => settingPolicySql(
      'ModelConfigEntity', 'OLD.key', mode: SettingSyncMode.synced,
    );

String _credentialSql(String prefix) => settingPolicySql(
      'ModelConfigEntity', '$prefix.key', mode: SettingSyncMode.credential,
    );

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
    await validateDatabaseSyncContract(transaction);
    await validateStoredSettingPolicies(transaction);
    await _createCaptureTriggers(transaction);
    await installSettingPolicyGuards(transaction);
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

  for (final entry in databaseSyncTables.entries) {
    final table = entry.key;
    switch (entry.value.strategy) {
      case TableSyncStrategy.history:
      case TableSyncStrategy.subscription:
        final kind = entry.value.strategy == TableSyncStrategy.history
            ? 'history'
            : 'subscribe';
        await _createRecordTriggers(
          database,
          table: table,
          stem: 'dcomic_sync_$kind',
          category: SyncCategory.history,
          newKeys: ["'$kind'", 'NEW.providerName', 'NEW.comicId'],
          oldKeys: ["'$kind'", 'OLD.providerName', 'OLD.comicId'],
          changed: 'OLD.providerName <> NEW.providerName OR OLD.comicId <> NEW.comicId',
          oldIdentity: 'providerName = OLD.providerName AND comicId = OLD.comicId',
        );
        break;
      case TableSyncStrategy.settings:
        await _createRecordTriggers(
          database,
          table: table,
          stem: 'dcomic_sync_settings',
          category: SyncCategory.settings,
          newKeys: ['NEW.key', "''", "''"],
          oldKeys: ['OLD.key', "''", "''"],
          changed: 'OLD.key <> NEW.key',
          oldIdentity: 'key = OLD.key',
          newWhen: _newSettingsSql,
          oldWhen: _oldSettingsSql,
        );
        break;
      case TableSyncStrategy.sourceSettingsAndCredentials:
        await _createRecordTriggers(
          database,
          table: table,
          stem: 'dcomic_sync_source',
          category: SyncCategory.sourceSettings,
          newKeys: ["COALESCE(NEW.sourceModel, '')", 'NEW.key', "''"],
          oldKeys: ["COALESCE(OLD.sourceModel, '')", 'OLD.key', "''"],
          changed: "COALESCE(OLD.sourceModel, '') <> COALESCE(NEW.sourceModel, '') OR OLD.key <> NEW.key",
          oldIdentity: "COALESCE(sourceModel, '') = COALESCE(OLD.sourceModel, '') AND key = OLD.key",
          newWhen: "COALESCE(NEW.sourceModel, '') <> '' AND ($_newSourceSettingSql)",
          oldWhen: "COALESCE(OLD.sourceModel, '') <> '' AND ($_oldSourceSettingSql)",
        );
        final newCredential = _credentialSql('NEW');
        final oldCredential = _credentialSql('OLD');
        await _createAggregateTriggers(
          database,
          table: table,
          stem: 'dcomic_sync_credentials_model',
          category: SyncCategory.credentials,
          key: 'accounts',
          insertWhen: newCredential,
          updateWhen: '($oldCredential) OR ($newCredential)',
          deleteWhen: oldCredential,
        );
        break;
      case TableSyncStrategy.credentials:
        await _createAggregateTriggers(
          database,
          table: table,
          stem: 'dcomic_sync_credentials_cookie',
          category: SyncCategory.credentials,
          key: 'accounts',
        );
        break;
      case TableSyncStrategy.bindings:
        await _createAggregateTriggers(
          database,
          table: table,
          stem: 'dcomic_sync_bindings',
          category: SyncCategory.bindings,
          key: 'graph',
        );
        break;
      case TableSyncStrategy.chapterRuleGroups:
      case TableSyncStrategy.chapterRulePatterns:
        await _createAggregateTriggers(
          database,
          table: table,
          stem: entry.value.strategy == TableSyncStrategy.chapterRuleGroups
              ? 'dcomic_sync_rules_group'
              : 'dcomic_sync_rules_pattern',
          category: SyncCategory.chapterRules,
          key: 'rules',
        );
        break;
      case TableSyncStrategy.localOnly:
        break;
    }
  }
}

Future<void> _createRecordTriggers(
  sqflite.DatabaseExecutor database, {
  required String table,
  required String stem,
  required SyncCategory category,
  required List<String> newKeys,
  required List<String> oldKeys,
  required String changed,
  required String oldIdentity,
  String newWhen = '1',
  String oldWhen = '1',
}) async {
  final live = _captureBody(category, newKeys[0], newKeys[1], newKeys[2], '0');
  final retired = _captureBody(
    category, oldKeys[0], oldKeys[1], oldKeys[2],
    'CASE WHEN EXISTS (SELECT 1 FROM $table WHERE $oldIdentity) THEN 0 ELSE 1 END',
  );
  await _createTrigger(database, '${stem}_insert',
      'AFTER INSERT ON $table', live, when: newWhen);
  await _createTrigger(database, '${stem}_update_old',
      'AFTER UPDATE ON $table', retired,
      when: '($oldWhen) AND (NOT ($newWhen) OR ($changed))');
  await _createTrigger(database, '${stem}_update_new',
      'AFTER UPDATE ON $table', live, when: newWhen);
  await _createTrigger(database, '${stem}_delete',
      'AFTER DELETE ON $table', retired, when: oldWhen);
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
