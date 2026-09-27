library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dcomic/database/database_common.dart';
import 'package:dcomic/database/sync/sync_models.dart';
import 'package:dcomic/utils/chapter_matching_rules.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

part 'sync_schema.dart';
part 'sync_database_wrapper.dart';
part 'sync_store_records.dart';

class SyncStore {
  SyncStore._(this._rawDatabase, this.deviceId);

  static const int _maximumFutureSkewMilliseconds = 5 * 60 * 1000;
  static final Expando<Future<SyncStore>> _attached =
      Expando<Future<SyncStore>>('dcomic-sync-store');

  final sqflite.Database _rawDatabase;

  final String deviceId;

  final StreamController<Set<SyncCategory>> _changesController =
      StreamController<Set<SyncCategory>>.broadcast();
  final StreamController<Set<SyncCategory>> _pendingChangesController =
      StreamController<Set<SyncCategory>>.broadcast();

  int _lastNotificationId = 0;
  bool _polling = false;
  bool _pollRequested = false;
  bool _closed = false;
  bool _trusted = false;
  Stopwatch? _calibrationClock;
  int _calibrationWall = 0;

  Stream<Set<SyncCategory>> get changes => _changesController.stream;

  /// Local mutations that made one or more records pending for upload.
  Stream<Set<SyncCategory>> get pendingChanges =>
      _pendingChangesController.stream;

  static Future<void> installSchema(sqflite.Database database) =>
      _installSyncSchema(database);

  static Future<SyncStore> attach(DComicDatabase database) {
    final existing = _attached[database];
    if (existing != null) return existing;
    final future = _attach(database);
    _attached[database] = future;
    return future;
  }

  static Future<SyncStore> _attach(DComicDatabase database) async {
    final raw = database.database;
    if (raw is! sqflite.Database) {
      throw StateError('SyncStore requires a root sqflite Database');
    }
    await _installSyncSchema(raw);
    final state = (await raw.query(
      _stateTable,
      columns: ['device_id'],
      where: 'id = 1',
      limit: 1,
    )).single;
    final store = SyncStore._(raw, state['device_id']! as String);
    await raw.transaction((transaction) async {
      await transaction.update(
        _stateTable,
        {'trusted': 0, 'anchor_wall': 0, 'suppress': 0},
        where: 'id = 1',
      );
      final account = await _activeAccount(transaction);
      await _bootstrapMetadata(transaction, account);
    });
    final notification = await raw.rawQuery(
      'SELECT COALESCE(MAX(id), 0) AS id FROM $_notificationTable',
    );
    store._lastNotificationId = notification.single['id']! as int;
    database.installDatabaseProxy(
      _SyncDatabase(
        raw,
        estimatedAnchor: store._estimatedAnchor,
        afterWrite: store._afterWrite,
        onClose: store.close,
      ),
    );
    return store;
  }

  Future<void> calibrate(
    int serverTime, {
    required Duration roundTrip,
  }) async {
    _checkOpen();
    if (serverTime < 0 || roundTrip.isNegative) {
      throw ArgumentError('serverTime and roundTrip must not be negative');
    }
    final midpoint = serverTime + roundTrip.inMilliseconds ~/ 2;
    _calibrationWall = midpoint;
    _calibrationClock = Stopwatch()..start();
    _trusted = true;
    await _rawDatabase.transaction((transaction) async {
      final row = (await transaction.query(
        _stateTable,
        columns: ['wall', 'logical'],
        where: 'id = 1',
        limit: 1,
      )).single;
      final oldWall = row['wall']! as int;
      final oldLogical = row['logical']! as int;
      await transaction.update(
        _stateTable,
        {
          'trusted': 1,
          'anchor_wall': midpoint,
          'wall': max(oldWall, midpoint),
          'logical': midpoint > oldWall ? 0 : oldLogical,
        },
        where: 'id = 1',
      );
    });
  }

  Future<Map<String, dynamic>> readPreferences() async {
    _checkOpen();
    final account = await _readActiveAccount();
    final rows = await _rawDatabase.query(
      _preferenceTable,
      columns: ['value'],
      where: 'account = ?',
      whereArgs: [account],
      limit: 1,
    );
    if (rows.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(rows.single['value']! as String);
    if (decoded is! Map) {
      throw const FormatException('stored sync preferences are invalid');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> writePreferences(Map<String, dynamic> preferences) async {
    _checkOpen();
    final copied = _validatedJsonMap(preferences, 'preferences');
    final encoded = jsonEncode(copied);
    await _rawDatabase.transaction((transaction) async {
      final account = await _activeAccount(transaction);
      await transaction.insert(
        _preferenceTable,
        {'account': account, 'value': encoded},
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );
    });
  }

  Future<List<SyncRecord>> pending(
    Set<SyncCategory> categories, {
    int limit = 200,
  }) async {
    _checkOpen();
    if (limit < 1 || limit > 200) {
      throw RangeError.range(limit, 1, 200, 'limit');
    }
    if (categories.isEmpty) return const [];
    return _rawDatabase.transaction((transaction) async {
      final account = await _activeAccount(transaction);
      final rows = await _metadataRows(
        transaction,
        account,
        categories,
        pendingOnly: true,
        limit: limit,
      );
      return _hydrateRows(transaction, rows);
    });
  }

  Future<SyncRecord?> pendingRecord(
    SyncCategory category,
    String key,
  ) async {
    _checkOpen();
    final parts = _parseKey(category, key);
    return _rawDatabase.transaction((transaction) async {
      final account = await _activeAccount(transaction);
      final row = await _metadataRow(transaction, account, category, parts);
      if (row == null || row['pending'] != 1) return null;
      return _hydrateRow(transaction, row);
    });
  }
  /// Returns a resolution record that must be sent to /conflicts/resolve.
  ///
  /// Resolution records are deliberately excluded from the normal sync outbox.
  Future<SyncRecord?> pendingResolution(String conflictId) async {
    _checkOpen();
    if (conflictId.isEmpty) {
      throw ArgumentError.value(conflictId, 'conflictId', 'must not be empty');
    }
    return _rawDatabase.transaction((transaction) async {
      final account = await _activeAccount(transaction);
      final resolutions = await transaction.query(
        _resolutionTable,
        where: 'account = ? AND conflict_id = ?',
        whereArgs: [account, conflictId],
        orderBy: 'wall DESC, logical DESC',
        limit: 1,
      );
      if (resolutions.isEmpty) return null;
      final resolution = resolutions.single;
      final storedRecord = resolution['record_json'];
      if (storedRecord is String) {
        final decoded = jsonDecode(storedRecord);
        if (decoded is! Map) {
          throw const FormatException('stored resolution is invalid');
        }
        return _validateRecord(
          SyncRecord.fromJson(Map<String, dynamic>.from(decoded)),
        );
      }
      final rows = await transaction.query(
        _recordTable,
        where:
            'account = ? AND wall = ? AND logical = ? AND device = ? AND pending = 1',
        whereArgs: [
          account,
          resolution['wall'],
          resolution['logical'],
          resolution['device'],
        ],
        limit: 1,
      );
      return rows.isEmpty ? null : _hydrateRow(transaction, rows.single);
    });
  }

  Future<int> pendingCount(Set<SyncCategory> categories) async {
    _checkOpen();
    if (categories.isEmpty) return 0;
    final account = await _readActiveAccount();
    final names = categories.map((category) => category.name).toList();
    final placeholders = List.filled(names.length, '?').join(',');
    final rows = await _rawDatabase.rawQuery(
      'SELECT COUNT(*) AS count FROM $_recordTable r '
      'WHERE r.account = ? AND r.pending = 1 '
      'AND r.category IN ($placeholders) '
      'AND NOT EXISTS (SELECT 1 FROM $_resolutionTable q '
      'WHERE q.account = r.account AND q.wall = r.wall '
      'AND q.logical = r.logical AND q.device = r.device)',
      [account, ...names],
    );
    return rows.single['count']! as int;
  }

  Future<List<SyncRecord>> snapshot(Set<SyncCategory> categories) async {
    _checkOpen();
    if (categories.isEmpty) return const [];
    return _rawDatabase.transaction((transaction) async {
      final account = await _activeAccount(transaction);
      await _bootstrapMetadata(transaction, account);
      final rows = await _metadataRows(
        transaction,
        account,
        categories,
        pendingOnly: false,
      );
      return _hydrateRows(transaction, rows);
    });
  }

  /// Validates identities and payloads without mutating the database.
  void validateRecords(Iterable<SyncRecord> records) {
    for (final record in records) {
      _validateRecord(record);
    }
  }

  Future<void> receive(List<SyncRecord> records) async {
    _checkOpen();
    if (records.isEmpty) return;
    final validated = records.map(_validateRecord).toList(growable: false);
    final changed = <SyncCategory>{};
    final newlyPending = <SyncCategory>{};
    await _refreshAnchor();
    final versionLimit = _trustedVersionLimit();
    _validateTrustedVersions(validated, versionLimit);
    await _rawDatabase.transaction((transaction) async {
      final account = await _activeAccount(transaction);
      await _setSuppressed(transaction, true);
      try {
        for (final incoming in validated) {
          if (versionLimit != null) {
            await _observeVersion(transaction, incoming.version);
          }
          final parts = _parseKey(incoming.category, incoming.key);
          final localRow = await _metadataRow(
            transaction,
            account,
            incoming.category,
            parts,
          );
          final local = localRow == null
              ? null
              : await _hydrateRow(transaction, localRow);
          if (local == null) {
            await _applyBusinessRecord(transaction, incoming);
            await _putMetadata(transaction, account, incoming, pending: false);
            changed.add(incoming.category);
            continue;
          }
          if (local.version == incoming.version) {
            if (!_sameRecordContent(local, incoming)) {
              throw const FormatException(
                'one sync version was reused for different content',
              );
            }
            if (localRow!['pending'] == 1) {
              await _putMetadata(
                transaction,
                account,
                incoming,
                pending: false,
              );
            }
            continue;
          }
          if (localRow!['pending'] == 0 && localRow['baseline'] == 1) {
            await _applyBusinessRecord(transaction, incoming);
            await _putMetadata(transaction, account, incoming, pending: false);
            changed.add(incoming.category);
            continue;
          }
          if (incoming.baseVersion == local.version) {
            await _applyBusinessRecord(transaction, incoming);
            await _putMetadata(transaction, account, incoming, pending: false);
            changed.add(incoming.category);
            continue;
          }
          if (local.baseVersion == incoming.version &&
              localRow['pending'] == 1) {
            continue;
          }
          if ((local.uncertain || incoming.uncertain) &&
              !_sameRecordContent(local, incoming) &&
              !(localRow['pending'] == 0 && _emptyAggregate(local))) {
            if (localRow['pending'] == 0) {
              await _setPending(
                transaction,
                account,
                local.category,
                _parseKey(local.category, local.key),
                true,
              );
              newlyPending.add(local.category);
            }
            continue;
          }
          if (incoming.version.compareTo(local.version) > 0) {
            await _applyBusinessRecord(transaction, incoming);
            await _putMetadata(transaction, account, incoming, pending: false);
            changed.add(incoming.category);
          }
        }
      } finally {
        await _setSuppressed(transaction, false);
      }
    });
    _emit(_changesController, changed);
    _emit(_pendingChangesController, newlyPending);
  }

  Future<void> acknowledge(
    SyncRecord sent,
    SyncRecord canonical,
  ) async {
    _checkOpen();
    final checkedSent = _validateRecord(sent);
    final checkedCanonical = _validateRecord(canonical);
    if (checkedSent.category != checkedCanonical.category ||
        checkedSent.key != checkedCanonical.key) {
      throw ArgumentError('acknowledged records must have the same identity');
    }
    await _refreshAnchor();
    final versionLimit = _trustedVersionLimit();
    _validateTrustedVersions([checkedCanonical], versionLimit);
    var changed = false;
    await _rawDatabase.transaction((transaction) async {
      final account = await _activeAccount(transaction);
      final resolutions = await transaction.query(
        _resolutionTable,
        columns: ['conflict_id'],
        where:
            'account = ? AND wall = ? AND logical = ? AND device = ?',
        whereArgs: [
          account,
          checkedSent.version.wall,
          checkedSent.version.logical,
          checkedSent.version.device,
        ],
      );
      Future<void> retireResolution() async {
        for (final resolution in resolutions) {
          await transaction.delete(
            _conflictTable,
            where: 'account = ? AND id = ?',
            whereArgs: [account, resolution['conflict_id']],
          );
        }
        await transaction.delete(
          _resolutionTable,
          where:
              'account = ? AND wall = ? AND logical = ? AND device = ?',
          whereArgs: [
            account,
            checkedSent.version.wall,
            checkedSent.version.logical,
            checkedSent.version.device,
          ],
        );
      }

      final parts = _parseKey(checkedSent.category, checkedSent.key);
      final row = await _metadataRow(
        transaction,
        account,
        checkedSent.category,
        parts,
      );
      if (row == null ||
          row['pending'] != 1 ||
          _versionFromRow(row) != checkedSent.version) {
        if (resolutions.isNotEmpty) {
          await retireResolution();
          if (versionLimit != null) {
            await _observeVersion(transaction, checkedCanonical.version);
          }
        }
        return;
      }
      final current = await _hydrateRow(transaction, row);
      changed = !_sameRecordContent(current, checkedCanonical);
      await _setSuppressed(transaction, true);
      try {
        if (changed) {
          await _applyBusinessRecord(transaction, checkedCanonical);
        }
        await _putMetadata(
          transaction,
          account,
          checkedCanonical,
          pending: false,
        );
        if (versionLimit != null) {
          await _observeVersion(transaction, checkedCanonical.version);
        }
        await retireResolution();
      } finally {
        await _setSuppressed(transaction, false);
      }
    });
    if (changed) {
      _emit(_changesController, {checkedCanonical.category});
    }
  }

  Future<void> addConflict(SyncRecord local, SyncRecord remote) async {
    _checkOpen();
    final checkedLocal = _validateRecord(local);
    final checkedRemote = _validateRecord(remote);
    if (checkedLocal.category != checkedRemote.category ||
        checkedLocal.key != checkedRemote.key) {
      throw ArgumentError('conflict records must have the same identity');
    }
    await _refreshAnchor();
    _validateTrustedVersions([checkedRemote], _trustedVersionLimit());
    var restoredCandidate = false;
    await _rawDatabase.transaction((transaction) async {
      final account = await _activeAccount(transaction);
      final parts = _parseKey(checkedLocal.category, checkedLocal.key);
      final existing = await transaction.query(
        _conflictTable,
        where: 'account = ?',
        whereArgs: [account],
      );
      for (final row in existing) {
        final candidate = SyncRecord.fromJson(
          Map<String, dynamic>.from(
            jsonDecode(row['local_record']! as String) as Map,
          ),
        );
        if (candidate.category != checkedLocal.category ||
            candidate.key != checkedLocal.key ||
            candidate.version != checkedLocal.version) {
          continue;
        }
        final conflictId = row['id']! as String;
        final resolutions = await transaction.query(
          _resolutionTable,
          where: 'account = ? AND conflict_id = ?',
          whereArgs: [account, conflictId],
        );
        for (final resolution in resolutions) {
          final current = await _metadataRow(
            transaction,
            account,
            checkedLocal.category,
            parts,
          );
          if (current != null &&
              current['pending'] == 1 &&
              current['wall'] == resolution['wall'] &&
              current['logical'] == resolution['logical'] &&
              current['device'] == resolution['device']) {
            await _setSuppressed(transaction, true);
            try {
              await _applyBusinessRecord(transaction, checkedLocal);
              await _putMetadata(
                transaction,
                account,
                checkedLocal,
                pending: false,
              );
              restoredCandidate = true;
            } finally {
              await _setSuppressed(transaction, false);
            }
          }
        }
        await transaction.delete(
          _resolutionTable,
          where: 'account = ? AND conflict_id = ?',
          whereArgs: [account, conflictId],
        );
        await transaction.delete(
          _conflictTable,
          where: 'account = ? AND id = ?',
          whereArgs: [account, conflictId],
        );
      }
      await _insertConflict(
        transaction,
        account,
        checkedLocal,
        checkedRemote,
      );
      final current = await _metadataRow(
        transaction,
        account,
        checkedLocal.category,
        parts,
      );
      if (current != null &&
          current['pending'] == 1 &&
          _versionFromRow(current) == checkedLocal.version) {
        await _setPending(
          transaction,
          account,
          checkedLocal.category,
          parts,
          false,
        );
      }
    });
    if (restoredCandidate) {
      _emit(_changesController, {checkedLocal.category});
    }
  }

  Future<List<SyncConflict>> conflicts() async {
    _checkOpen();
    final account = await _readActiveAccount();
    final rows = await _rawDatabase.query(
      _conflictTable,
      where: 'account = ?',
      whereArgs: [account],
      orderBy: 'created_at ASC, id ASC',
    );
    return [
      for (final row in rows)
        SyncConflict(
          id: row['id']! as String,
          local: SyncRecord.fromJson(
            Map<String, dynamic>.from(
              jsonDecode(row['local_record']! as String) as Map,
            ),
          ),
          remote: SyncRecord.fromJson(
            Map<String, dynamic>.from(
              jsonDecode(row['remote_record']! as String) as Map,
            ),
          ),
        ),
    ];
  }

  Future<void> removeConflict(String id) async {
    _checkOpen();
    if (id.isEmpty) throw ArgumentError.value(id, 'id', 'must not be empty');
    final versionLimit = _trustedVersionLimit();
    SyncCategory? changedCategory;
    await _rawDatabase.transaction((transaction) async {
      final account = await _activeAccount(transaction);
      final conflicts = await transaction.query(
        _conflictTable,
        where: 'account = ? AND id = ?',
        whereArgs: [account, id],
        limit: 1,
      );
      if (conflicts.isEmpty) return;
      final local = SyncRecord.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(conflicts.single['local_record']! as String) as Map,
        ),
      );
      final remote = SyncRecord.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(conflicts.single['remote_record']! as String) as Map,
        ),
      );
      _validateTrustedVersions([remote], versionLimit);
      final resolutions = await transaction.query(
        _resolutionTable,
        where: 'account = ? AND conflict_id = ?',
        whereArgs: [account, id],
      );
      final current = await _metadataRow(
        transaction,
        account,
        local.category,
        _parseKey(local.category, local.key),
      );
      final currentVersion = current == null ? null : _versionFromRow(current);
      final isResolution = resolutions.any(
        (row) =>
            currentVersion?.wall == row['wall'] &&
            currentVersion?.logical == row['logical'] &&
            currentVersion?.device == row['device'],
      );
      final shouldRestoreRemote =
          current == null || currentVersion == local.version || isResolution;
      if (shouldRestoreRemote) {
        await _setSuppressed(transaction, true);
        try {
          await _applyBusinessRecord(transaction, remote);
          await _putMetadata(transaction, account, remote, pending: false);
          if (versionLimit != null) {
            await _observeVersion(transaction, remote.version);
          }
          changedCategory = remote.category;
        } finally {
          await _setSuppressed(transaction, false);
        }
      }
      await transaction.delete(
        _resolutionTable,
        where: 'account = ? AND conflict_id = ?',
        whereArgs: [account, id],
      );
      await transaction.delete(
        _conflictTable,
        where: 'account = ? AND id = ?',
        whereArgs: [account, id],
      );
    });
    if (changedCategory != null) {
      _emit(_changesController, {changedCategory!});
    }
  }

  Future<void> resolveConflict(
    String id, {
    required bool useLocal,
  }) async {
    _checkOpen();
    if (id.isEmpty) throw ArgumentError.value(id, 'id', 'must not be empty');
    await _refreshAnchor();
    SyncCategory? changedCategory;
    await _rawDatabase.transaction((transaction) async {
      final account = await _activeAccount(transaction);
      final rows = await transaction.query(
        _conflictTable,
        where: 'account = ? AND id = ?',
        whereArgs: [account, id],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('sync conflict no longer exists');
      final local = SyncRecord.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(rows.single['local_record']! as String) as Map,
        ),
      );
      final remote = SyncRecord.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(rows.single['remote_record']! as String) as Map,
        ),
      );
      changedCategory = local.category;
      final currentRow = await _metadataRow(
        transaction,
        account,
        local.category,
        _parseKey(local.category, local.key),
      );
      if (currentRow != null &&
          currentRow['pending'] == 1 &&
          _versionFromRow(currentRow) != local.version) {
        throw StateError('record changed after this conflict was created');
      }
      final next = await _nextVersion(transaction, requireTrusted: true);
      final chosen = useLocal ? local : remote;
      final resolved = SyncRecord(
        category: chosen.category,
        key: chosen.key,
        value: chosen.value,
        deleted: chosen.deleted,
        version: next,
        uncertain: false,
        baseVersion: remote.version,
      );
      await _setSuppressed(transaction, true);
      try {
        await _applyBusinessRecord(transaction, resolved);
        await transaction.delete(
          _resolutionTable,
          where: 'account = ? AND conflict_id = ?',
          whereArgs: [account, id],
        );
        await _putMetadata(transaction, account, resolved, pending: true);
        await transaction.insert(
          _resolutionTable,
          {
            'account': account,
            'wall': next.wall,
            'logical': next.logical,
            'device': next.device,
            'conflict_id': id,
            'record_json': jsonEncode(resolved.toJson()),
          },
          conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
        );
      } finally {
        await _setSuppressed(transaction, false);
      }
    });
    if (changedCategory != null) {
      _emit(_changesController, {changedCategory!});
    }
  }

  Future<void> bindAccount(
    String account, {
    required bool migrateLocal,
  }) async {
    _checkOpen();
    final normalized = account.trim();
    if (normalized.isEmpty || normalized.length > 1024) {
      throw ArgumentError.value(account, 'account', 'invalid account identity');
    }
    var restored = false;
    await _rawDatabase.transaction((transaction) async {
      final previous = await _activeAccount(transaction);
      if (previous == normalized) return;
      await _bootstrapMetadata(transaction, previous);
      await _saveAccountSnapshot(transaction, previous);
      final previousRows = await transaction.query(
        _recordTable,
        where: 'account = ?',
        whereArgs: [previous],
      );
      final targetSnapshots = await transaction.query(
        _accountSnapshotTable,
        columns: ['account'],
        where: 'account = ?',
        whereArgs: [normalized],
        limit: 1,
      );
      if (!migrateLocal && targetSnapshots.isNotEmpty) {
        await _setSuppressed(transaction, true);
        try {
          restored = await _restoreAccountSnapshot(transaction, normalized);
        } finally {
          await _setSuppressed(transaction, false);
        }
      }
      await transaction.update(
        _stateTable,
        {'active_account': normalized},
        where: 'id = 1',
      );
      final existing = sqflite.Sqflite.firstIntValue(
            await transaction.rawQuery(
              'SELECT COUNT(*) FROM $_recordTable WHERE account = ?',
              [normalized],
            ),
          ) ??
          0;
      if (migrateLocal) {
        await transaction.delete(
          _recordTable,
          where: 'account = ?',
          whereArgs: [normalized],
        );
        await transaction.delete(
          _conflictTable,
          where: 'account = ?',
          whereArgs: [normalized],
        );
        await transaction.delete(
          _resolutionTable,
          where: 'account = ?',
          whereArgs: [normalized],
        );
        for (final row in previousRows) {
          final copied = Map<String, Object?>.from(row)
            ..['account'] = normalized
            ..['pending'] = 1
            ..['baseline'] = 0;
          await transaction.insert(
            _recordTable,
            copied,
            conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
          );
        }
        await _saveAccountSnapshot(transaction, normalized);
      } else if (existing == 0) {
        for (final row in previousRows) {
          final baseline = Map<String, Object?>.from(row)
            ..['account'] = normalized
            ..['pending'] = 0
            ..['baseline'] = 1;
          await transaction.insert(
            _recordTable,
            baseline,
            conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
          );
        }
        await _saveAccountSnapshot(transaction, normalized);
      }
    });
    if (restored) {
      _emit(_changesController, SyncCategory.values.toSet());
    }
  }

  Future<void> importRecords(
    List<SyncRecord> records,
    Set<SyncCategory> categories, {
    required bool replace,
  }) async {
    _checkOpen();
    final selected = Set<SyncCategory>.unmodifiable(categories);
    final validated = <SyncRecord>[];
    final identities = <String>{};
    for (final record in records) {
      final checked = _validateRecord(record);
      if (!selected.contains(checked.category)) continue;
      final identity = '${checked.category.name}\u0000${checked.key}';
      if (!identities.add(identity)) {
        throw FormatException('duplicate backup record ${checked.key}');
      }
      validated.add(checked);
    }
    if (selected.isEmpty) return;
    await _refreshAnchor();
    final versionLimit = _trustedVersionLimit();
    _validateTrustedVersions(validated, versionLimit);
    final importedVersionsAreTrusted = versionLimit != null;
    final changed = <SyncCategory>{};
    final madePending = <SyncCategory>{};
    await _rawDatabase.transaction((transaction) async {
      final account = await _activeAccount(transaction);
      await _bootstrapMetadata(transaction, account);
      await _setSuppressed(transaction, true);
      try {
        if (replace) {
          final incoming = {
            for (final record in validated)
              '${record.category.name}\u0000${record.key}': record,
          };
          final currentRows = await _metadataRows(
            transaction,
            account,
            selected,
            pendingOnly: false,
          );
          final current = <String, SyncRecord>{};
          for (final row in currentRows) {
            final record = await _hydrateRow(transaction, row);
            current['${record.category.name}\u0000${record.key}'] = record;
          }
          for (final entry in current.entries) {
            if (incoming.containsKey(entry.key)) continue;
            final (version, usedCausalFloor) = await _nextVersionAfter(
              transaction,
              entry.value.version,
            );
            final tombstone = SyncRecord(
              category: entry.value.category,
              key: entry.value.key,
              value: null,
              deleted: true,
              version: version,
              uncertain:
                  !importedVersionsAreTrusted || usedCausalFloor,
              baseVersion: entry.value.version,
            );
            await _applyBusinessRecord(transaction, tombstone);
            await _putMetadata(transaction, account, tombstone, pending: true);
            changed.add(tombstone.category);
            madePending.add(tombstone.category);
          }
          for (final source in validated) {
            final old = current['${source.category.name}\u0000${source.key}'];
            final (version, usedCausalFloor) = await _nextVersionAfter(
              transaction,
              old?.version,
            );
            final replacement = SyncRecord(
              category: source.category,
              key: source.key,
              value: source.value,
              deleted: source.deleted,
              version: version,
              uncertain:
                  !importedVersionsAreTrusted || usedCausalFloor,
              baseVersion: old?.version,
            );
            await _applyBusinessRecord(transaction, replacement);
            await _putMetadata(
              transaction,
              account,
              replacement,
              pending: true,
            );
            changed.add(replacement.category);
            madePending.add(replacement.category);
          }
        } else {
          for (final incoming in validated) {
            final parts = _parseKey(incoming.category, incoming.key);
            final localRow = await _metadataRow(
              transaction,
              account,
              incoming.category,
              parts,
            );
            final local = localRow == null
                ? null
                : await _hydrateRow(transaction, localRow);
            if (local != null && local.version == incoming.version) {
              if (!_sameRecordContent(local, incoming)) {
                throw const FormatException(
                  'backup reuses a version for different content',
                );
              }
              continue;
            }
            if (local != null &&
                (local.uncertain || incoming.uncertain) &&
                !_sameRecordContent(local, incoming) &&
                !(localRow!['pending'] == 0 && _emptyAggregate(local))) {
              throw const FormatException(
                'backup conflicts with uncertain local data',
              );
            }
            if (local != null &&
                incoming.version.compareTo(local.version) < 0) {
              continue;
            }
            await _applyBusinessRecord(transaction, incoming);
            await _putMetadata(transaction, account, incoming, pending: true);
            if (importedVersionsAreTrusted) {
              await _observeVersion(transaction, incoming.version);
            }
            changed.add(incoming.category);
            madePending.add(incoming.category);
          }
        }
      } finally {
        await _setSuppressed(transaction, false);
      }
    });
    _emit(_changesController, changed);
    _emit(_pendingChangesController, madePending);
  }

  void _afterWrite() {
    unawaited(_pollAfterWrite());
  }

  Future<void> _pollAfterWrite() async {
    try {
      await _poll();
    } on Object catch (error, stackTrace) {
      if (!_closed && !_pendingChangesController.isClosed) {
        _pendingChangesController.addError(error, stackTrace);
      }
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    while (_polling) {
      await Future<void>.delayed(Duration.zero);
    }
    await _changesController.close();
    await _pendingChangesController.close();
  }

  Future<void> _poll() async {
    if (_closed) return;
    _pollRequested = true;
    if (_polling) return;
    _polling = true;
    try {
      do {
        _pollRequested = false;
        final rows = await _rawDatabase.query(
          _notificationTable,
          where: 'id > ?',
          whereArgs: [_lastNotificationId],
          orderBy: 'id ASC',
        );
        final categories = <SyncCategory>{};
        for (final row in rows) {
          _lastNotificationId = row['id']! as int;
          final name = row['category']! as String;
          for (final category in SyncCategory.values) {
            if (category.name == name) categories.add(category);
          }
        }
        _emit(_pendingChangesController, categories);
        if (_lastNotificationId > 1000) {
          await _rawDatabase.delete(
            _notificationTable,
            where: 'id <= ?',
            whereArgs: [_lastNotificationId],
          );
        }
      } while (_pollRequested && !_closed);
    } finally {
      _polling = false;
    }
  }

  int? _estimatedAnchor() {
    if (!_trusted || _closed) return null;
    final clock = _calibrationClock;
    if (clock == null) return null;
    return _calibrationWall + clock.elapsedMilliseconds;
  }

  int? _trustedVersionLimit() {
    final anchor = _estimatedAnchor();
    return anchor == null ? null : anchor + _maximumFutureSkewMilliseconds;
  }

  void _validateTrustedVersions(
    Iterable<SyncRecord> records,
    int? latestAllowed,
  ) {
    if (latestAllowed == null) return;
    for (final record in records) {
      if (record.version.wall > latestAllowed ||
          (record.baseVersion?.wall ?? 0) > latestAllowed) {
        throw const FormatException(
          'sync record version is more than five minutes in the future',
        );
      }
    }
  }

  Future<void> _refreshAnchor() async {
    final estimate = _estimatedAnchor();
    if (estimate == null) return;
    await _rawDatabase.update(
      _stateTable,
      {'anchor_wall': estimate, 'trusted': 1},
      where: 'id = 1',
    );
  }

  Future<String> _readActiveAccount() async {
    final rows = await _rawDatabase.query(
      _stateTable,
      columns: ['active_account'],
      where: 'id = 1',
      limit: 1,
    );
    return rows.single['active_account']! as String;
  }

  void _checkOpen() {
    if (_closed) throw StateError('SyncStore is closed');
  }

  static void _emit(
    StreamController<Set<SyncCategory>> controller,
    Set<SyncCategory> categories,
  ) {
    if (categories.isNotEmpty && !controller.isClosed) {
      controller.add(Set<SyncCategory>.unmodifiable(categories));
    }
  }
}
