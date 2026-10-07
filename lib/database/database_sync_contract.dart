import 'dart:collection';

import 'package:sqflite/sqflite.dart' as sqflite;

/// The synchronization behavior assigned to a database table.
enum TableSyncStrategy {
  history,
  subscription,
  settings,
  sourceSettingsAndCredentials,
  credentials,
  bindings,
  chapterRuleGroups,
  chapterRulePatterns,
  localOnly,
}

/// How one physical database column participates in synchronization.
enum FieldSyncDisposition { transmitted, identity, localOnly, localRelation }

/// Converts one persisted database value to its wire representation.
typedef SyncValueProjector = Object? Function(Object? value);

/// An immutable declaration for one physical database column.
final class TableSyncFieldDefinition {
  /// Physical SQLite column name.
  final String column;

  /// The column's synchronization role.
  final FieldSyncDisposition disposition;

  /// The payload property emitted for this column, or `null` when the column is
  /// an identity used only to address the record.
  final String? wireName;

  /// Why a local-only or local-relation field is not transmitted.
  final String? localReason;
  final SyncValueProjector? _projector;

  TableSyncFieldDefinition._({
    required this.column,
    required this.disposition,
    required this.wireName,
    required this.localReason,
    required SyncValueProjector? projector,
  }) : _projector = projector {
    if (column.isEmpty) {
      throw StateError('A database sync field must have a column name');
    }
    final isProjected = wireName != null;
    if (isProjected && wireName!.isEmpty) {
      throw StateError('$column has an empty sync wire name');
    }
    if (isProjected && wireName != column) {
      throw StateError(
        '$column cannot use unsupported renamed payload field $wireName',
      );
    }
    switch (disposition) {
      case FieldSyncDisposition.transmitted:
        if (!isProjected || localReason != null) {
          throw StateError('$column has an invalid transmitted-field policy');
        }
        break;
      case FieldSyncDisposition.identity:
        if (localReason != null || (!isProjected && projector != null)) {
          throw StateError('$column has an invalid identity-field policy');
        }
        break;
      case FieldSyncDisposition.localOnly:
      case FieldSyncDisposition.localRelation:
        if (isProjected ||
            projector != null ||
            localReason?.trim().isEmpty != false) {
          throw StateError('$column requires an explicit local-only reason');
        }
        break;
    }
  }

  /// Declares a value copied into every payload under [wireName].
  factory TableSyncFieldDefinition.transmitted({
    required String column,
    required String wireName,
    SyncValueProjector? projector,
  }) => TableSyncFieldDefinition._(
    column: column,
    disposition: FieldSyncDisposition.transmitted,
    wireName: wireName,
    localReason: null,
    projector: projector,
  );

  /// Declares a record identity. A null [wireName] keeps it out of the payload.
  factory TableSyncFieldDefinition.identity({
    required String column,
    String? wireName,
    SyncValueProjector? projector,
  }) => TableSyncFieldDefinition._(
    column: column,
    disposition: FieldSyncDisposition.identity,
    wireName: wireName,
    localReason: null,
    projector: projector,
  );

  /// Declares a column that exists only in the local database.
  factory TableSyncFieldDefinition.localOnly({
    required String column,
    required String reason,
  }) => TableSyncFieldDefinition._(
    column: column,
    disposition: FieldSyncDisposition.localOnly,
    wireName: null,
    localReason: reason,
    projector: null,
  );

  /// Declares a local relationship used to construct an aggregate payload.
  factory TableSyncFieldDefinition.localRelation({
    required String column,
    required String reason,
  }) => TableSyncFieldDefinition._(
    column: column,
    disposition: FieldSyncDisposition.localRelation,
    wireName: null,
    localReason: reason,
    projector: null,
  );

  /// Applies the declared database-to-wire value conversion.
  Object? projectValue(Object? value) {
    final projector = _projector;
    return projector == null ? value : projector(value);
  }
}

/// The immutable synchronization contract for one physical database table.
final class TableSyncDefinition {
  /// Table-level synchronization behavior.
  final TableSyncStrategy strategy;

  /// Field declarations indexed by physical SQLite column name.
  final Map<String, TableSyncFieldDefinition> fields;

  /// Why the entire table is device-local. Required only for local-only tables.
  final String? localReason;
  final List<TableSyncFieldDefinition> _projectedFields;

  /// Database columns that [projectPayload] reads, including projected identity
  /// columns. Identity columns with no wire name are intentionally absent.
  final Set<String> payloadColumns;

  /// Exact wire-object keys emitted and accepted for this table's payload.
  final Set<String> payloadKeys;

  factory TableSyncDefinition({
    required TableSyncStrategy strategy,
    required Iterable<TableSyncFieldDefinition> fields,
    String? localReason,
  }) {
    if (strategy == TableSyncStrategy.localOnly) {
      if (localReason?.trim().isEmpty != false) {
        throw StateError('A local-only table requires an explicit reason');
      }
    } else if (localReason != null) {
      throw StateError('$strategy cannot have a table-local reason');
    }

    final byColumn = <String, TableSyncFieldDefinition>{};
    final projected = <TableSyncFieldDefinition>[];
    final wireNames = <String>{};
    for (final field in fields) {
      if (byColumn.containsKey(field.column)) {
        throw StateError('Duplicate database sync field: ${field.column}');
      }
      if (strategy == TableSyncStrategy.localOnly &&
          field.disposition != FieldSyncDisposition.localOnly) {
        throw StateError(
          'A local-only table cannot declare ${field.column} as ${field.disposition}',
        );
      }
      byColumn[field.column] = field;
      final wireName = field.wireName;
      if (wireName != null) {
        if (!wireNames.add(wireName)) {
          throw StateError('Duplicate payload field: $wireName');
        }
        projected.add(field);
      }
    }
    if (byColumn.isEmpty) {
      throw StateError('A database sync table must declare at least one field');
    }

    return TableSyncDefinition._(
      strategy: strategy,
      fields: UnmodifiableMapView(byColumn),
      localReason: localReason,
      projectedFields: List.unmodifiable(projected),
      payloadColumns: Set.unmodifiable(projected.map((field) => field.column)),
      payloadKeys: Set.unmodifiable(wireNames),
    );
  }

  TableSyncDefinition._({
    required this.strategy,
    required this.fields,
    required this.localReason,
    required this._projectedFields,
    required this.payloadColumns,
    required this.payloadKeys,
  });

  /// Selects and renames this table's wire fields from a database row.
  Map<String, dynamic> projectPayload(Map<String, Object?> row) {
    final payload = <String, dynamic>{};
    for (final field in _projectedFields) {
      if (!row.containsKey(field.column)) {
        throw StateError('Payload row is missing ${field.column}');
      }
      payload[field.wireName!] = field.projectValue(row[field.column]);
    }
    return payload;
  }
}

final class _DatabaseSyncRegistry {
  final Map<String, TableSyncDefinition> tables;
  final Map<TableSyncStrategy, String> tableNamesByStrategy;

  _DatabaseSyncRegistry._(this.tables, this.tableNamesByStrategy);
}

Object? _projectSqliteBoolean(Object? value) =>
    value is bool ? value : value == 1;

TableSyncFieldDefinition _generatedId() => TableSyncFieldDefinition.localOnly(
  column: 'id',
  reason:
      'Locally generated row identifier; wire identity is declared separately.',
);

TableSyncFieldDefinition _syncInternalField(String column) =>
    TableSyncFieldDefinition.localOnly(
      column: column,
      reason: 'Synchronization bookkeeping is device-local.',
    );

TableSyncFieldDefinition _sqliteSequenceField(String column) =>
    TableSyncFieldDefinition.localOnly(
      column: column,
      reason: 'SQLite owns AUTOINCREMENT sequence state locally.',
    );

_DatabaseSyncRegistry _buildDatabaseSyncRegistry() {
  final definitions = <String, TableSyncDefinition>{
    'ConfigEntity': TableSyncDefinition(
      strategy: TableSyncStrategy.settings,
      fields: [
        _generatedId(),
        TableSyncFieldDefinition.identity(column: 'key'),
        TableSyncFieldDefinition.transmitted(
          column: 'value',
          wireName: 'value',
        ),
      ],
    ),
    'ComicHistoryEntity': TableSyncDefinition(
      strategy: TableSyncStrategy.history,
      fields: [
        _generatedId(),
        TableSyncFieldDefinition.identity(
          column: 'comicId',
          wireName: 'comicId',
        ),
        TableSyncFieldDefinition.transmitted(
          column: 'title',
          wireName: 'title',
        ),
        TableSyncFieldDefinition.transmitted(
          column: 'cover',
          wireName: 'cover',
        ),
        TableSyncFieldDefinition.transmitted(
          column: 'coverType',
          wireName: 'coverType',
        ),
        TableSyncFieldDefinition.transmitted(
          column: 'lastChapterTitle',
          wireName: 'lastChapterTitle',
        ),
        TableSyncFieldDefinition.transmitted(
          column: 'lastChapterId',
          wireName: 'lastChapterId',
        ),
        TableSyncFieldDefinition.transmitted(
          column: 'lastPage',
          wireName: 'lastPage',
        ),
        TableSyncFieldDefinition.transmitted(
          column: 'timestamp',
          wireName: 'timestamp',
        ),
        TableSyncFieldDefinition.identity(
          column: 'providerName',
          wireName: 'providerName',
        ),
      ],
    ),
    'CookieEntity': TableSyncDefinition(
      strategy: TableSyncStrategy.credentials,
      fields: [
        _generatedId(),
        TableSyncFieldDefinition.identity(column: 'key', wireName: 'key'),
        TableSyncFieldDefinition.transmitted(
          column: 'value',
          wireName: 'value',
        ),
      ],
    ),
    'ModelConfigEntity': TableSyncDefinition(
      strategy: TableSyncStrategy.sourceSettingsAndCredentials,
      fields: [
        _generatedId(),
        TableSyncFieldDefinition.identity(column: 'key'),
        TableSyncFieldDefinition.transmitted(
          column: 'value',
          wireName: 'value',
        ),
        TableSyncFieldDefinition.identity(column: 'sourceModel'),
      ],
    ),
    'ComicMappingEntity': TableSyncDefinition(
      strategy: TableSyncStrategy.bindings,
      fields: [
        TableSyncFieldDefinition.identity(
          column: 'providerA',
          wireName: 'providerA',
        ),
        TableSyncFieldDefinition.identity(column: 'comicA', wireName: 'comicA'),
        TableSyncFieldDefinition.identity(
          column: 'providerB',
          wireName: 'providerB',
        ),
        TableSyncFieldDefinition.identity(column: 'comicB', wireName: 'comicB'),
        TableSyncFieldDefinition.transmitted(
          column: 'blocked',
          wireName: 'blocked',
          projector: _projectSqliteBoolean,
        ),
      ],
    ),
    'ComicSubscribeStateEntity': TableSyncDefinition(
      strategy: TableSyncStrategy.subscription,
      fields: [
        _generatedId(),
        TableSyncFieldDefinition.identity(
          column: 'comicId',
          wireName: 'comicId',
        ),
        TableSyncFieldDefinition.transmitted(
          column: 'timestamp',
          wireName: 'timestamp',
        ),
        TableSyncFieldDefinition.identity(
          column: 'providerName',
          wireName: 'providerName',
        ),
      ],
    ),
    'ChapterRuleGroupEntity': TableSyncDefinition(
      strategy: TableSyncStrategy.chapterRuleGroups,
      fields: [
        _generatedId(),
        TableSyncFieldDefinition.transmitted(column: 'name', wireName: 'name'),
      ],
    ),
    'ChapterRulePatternEntity': TableSyncDefinition(
      strategy: TableSyncStrategy.chapterRulePatterns,
      fields: [
        _generatedId(),
        TableSyncFieldDefinition.localRelation(
          column: 'groupId',
          reason: 'Local group row id joins patterns while building the grouped wire payload.',
        ),
        TableSyncFieldDefinition.transmitted(
          column: 'pattern',
          wireName: 'pattern',
        ),
      ],
    ),
    '_dcomic_sync_schema': TableSyncDefinition(
      strategy: TableSyncStrategy.localOnly,
      localReason:
          'Tracks the locally installed synchronization schema version.',
      fields: [_syncInternalField('version')],
    ),
    '_dcomic_sync_state': TableSyncDefinition(
      strategy: TableSyncStrategy.localOnly,
      localReason: 'Stores this device clock, identity, and capture state.',
      fields: [
        _syncInternalField('id'),
        _syncInternalField('device_id'),
        _syncInternalField('wall'),
        _syncInternalField('logical'),
        _syncInternalField('trusted'),
        _syncInternalField('anchor_wall'),
        _syncInternalField('active_account'),
        _syncInternalField('suppress'),
      ],
    ),
    '_dcomic_sync_records': TableSyncDefinition(
      strategy: TableSyncStrategy.localOnly,
      localReason:
          'Stores local synchronization record state and pending work.',
      fields: [
        _syncInternalField('account'),
        _syncInternalField('category'),
        _syncInternalField('key1'),
        _syncInternalField('key2'),
        _syncInternalField('key3'),
        _syncInternalField('deleted'),
        _syncInternalField('wall'),
        _syncInternalField('logical'),
        _syncInternalField('device'),
        _syncInternalField('uncertain'),
        _syncInternalField('base_wall'),
        _syncInternalField('base_logical'),
        _syncInternalField('base_device'),
        _syncInternalField('pending'),
        _syncInternalField('baseline'),
      ],
    ),
    '_dcomic_sync_preferences': TableSyncDefinition(
      strategy: TableSyncStrategy.localOnly,
      localReason: 'Caches per-account synchronization preferences locally.',
      fields: [_syncInternalField('account'), _syncInternalField('value')],
    ),
    '_dcomic_sync_conflicts': TableSyncDefinition(
      strategy: TableSyncStrategy.localOnly,
      localReason: 'Stores unresolved synchronization conflicts locally.',
      fields: [
        _syncInternalField('account'),
        _syncInternalField('id'),
        _syncInternalField('local_record'),
        _syncInternalField('remote_record'),
        _syncInternalField('created_at'),
      ],
    ),
    '_dcomic_sync_resolutions': TableSyncDefinition(
      strategy: TableSyncStrategy.localOnly,
      localReason: 'Stores local conflict-resolution bookkeeping.',
      fields: [
        _syncInternalField('account'),
        _syncInternalField('wall'),
        _syncInternalField('logical'),
        _syncInternalField('device'),
        _syncInternalField('conflict_id'),
        _syncInternalField('record_json'),
      ],
    ),
    '_dcomic_sync_account_snapshots': TableSyncDefinition(
      strategy: TableSyncStrategy.localOnly,
      localReason: 'Caches an account snapshot used by the local sync engine.',
      fields: [
        _syncInternalField('account'),
        _syncInternalField('records_json'),
      ],
    ),
    '_dcomic_sync_notifications': TableSyncDefinition(
      strategy: TableSyncStrategy.localOnly,
      localReason:
          'Queues in-process notifications for locally captured changes.',
      fields: [_syncInternalField('id'), _syncInternalField('category')],
    ),
    'sqlite_sequence': TableSyncDefinition(
      strategy: TableSyncStrategy.localOnly,
      localReason: 'SQLite owns AUTOINCREMENT sequence state on each database.',
      fields: [_sqliteSequenceField('name'), _sqliteSequenceField('seq')],
    ),
  };

  final tableNamesByStrategy = <TableSyncStrategy, String>{};
  for (final entry in definitions.entries) {
    final strategy = entry.value.strategy;
    if (strategy == TableSyncStrategy.localOnly) continue;
    final previous = tableNamesByStrategy[strategy];
    if (previous != null) {
      throw StateError(
        'Sync strategy $strategy is assigned to both $previous and ${entry.key}',
      );
    }
    tableNamesByStrategy[strategy] = entry.key;
  }
  for (final strategy in TableSyncStrategy.values) {
    if (strategy != TableSyncStrategy.localOnly &&
        !tableNamesByStrategy.containsKey(strategy)) {
      throw StateError('Sync strategy $strategy has no database table');
    }
  }

  return _DatabaseSyncRegistry._(
    UnmodifiableMapView(definitions),
    UnmodifiableMapView(tableNamesByStrategy),
  );
}

final _DatabaseSyncRegistry _databaseSyncRegistry =
    _buildDatabaseSyncRegistry();

/// Exhaustive policy for application, synchronization, and SQLite sequence
/// tables expected after the synchronization schema has been installed.
final Map<String, TableSyncDefinition> databaseSyncTables =
    _databaseSyncRegistry.tables;

/// Returns the declared policy for [table], rejecting unknown tables.
TableSyncDefinition tableSyncDefinition(String table) =>
    databaseSyncTables[table] ??
    (throw StateError('No database sync policy is declared for table $table'));

/// Returns the one table assigned to a transport strategy.
///
/// [TableSyncStrategy.localOnly] intentionally has multiple tables and is not a
/// transport strategy, so asking for it is an error.
String tableNameForStrategy(TableSyncStrategy strategy) {
  final table = _databaseSyncRegistry.tableNamesByStrategy[strategy];
  if (table == null) {
    throw StateError('$strategy does not identify one synchronized table');
  }
  return table;
}

bool _isIgnoredEngineTable(String table) =>
    table == 'android_metadata' ||
    (table.startsWith('sqlite_') && table != 'sqlite_sequence');

String _quotedPragmaArgument(String value) => value.replaceAll("'", "''");

Future<List<Map<String, Object?>>> _tableColumnRows(
  sqflite.DatabaseExecutor database,
  String escapedTable,
) async {
  final rows = await database.rawQuery("PRAGMA table_xinfo('$escapedTable')");
  if (rows.isNotEmpty) return rows;
  return database.rawQuery("PRAGMA table_info('$escapedTable')");
}

/// Verifies that every installed table and physical/generated column has an
/// explicit synchronization policy, and that every declared table exists.
///
/// Call this only after the synchronization-internal schema is installed.
Future<void> validateDatabaseSyncContract(
  sqflite.DatabaseExecutor database,
) async {
  // Force registry construction and its one-table-per-transport validation.
  final definitions = databaseSyncTables;
  final tableRows = await database.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table'",
  );
  final actualTables = <String>{
    for (final row in tableRows)
      if (row['name'] case final String name) name,
  };

  final errors = <String>[];
  final unknownTables =
      actualTables
          .where(
            (table) =>
                !definitions.containsKey(table) &&
                !_isIgnoredEngineTable(table),
          )
          .toList()
        ..sort();
  for (final table in unknownTables) {
    errors.add('missing sync policy for table $table');
  }

  final missingTables =
      definitions.keys.where((table) => !actualTables.contains(table)).toList()
        ..sort();
  for (final table in missingTables) {
    errors.add('declared sync table is missing: $table');
  }

  final presentTables = definitions.keys.where(actualTables.contains).toList()
    ..sort();
  for (final table in presentTables) {
    final escapedTable = _quotedPragmaArgument(table);
    final columnRows = await _tableColumnRows(database, escapedTable);
    final actualColumns = <String>{
      for (final row in columnRows)
        if (row['name'] case final String name) name,
    };
    final declaredColumns = definitions[table]!.fields.keys.toSet();

    final unknownColumns = actualColumns.difference(declaredColumns).toList()
      ..sort();
    for (final column in unknownColumns) {
      errors.add('missing sync policy for $table.$column');
    }

    final missingColumns = declaredColumns.difference(actualColumns).toList()
      ..sort();
    for (final column in missingColumns) {
      errors.add('declared sync field is missing: $table.$column');
    }
  }

  if (errors.isNotEmpty) {
    throw StateError('Database sync contract mismatch: ${errors.join('; ')}');
  }
}
