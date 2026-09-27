// ignore_for_file: deprecated_member_use, prefer_initializing_formals

part of 'sync_store.dart';

class _SyncDatabase implements sqflite.Database {
  _SyncDatabase(
    this._delegate, {
    required int? Function() estimatedAnchor,
    required Future<void> Function() onClose,
    required void Function() afterWrite,
  })  : _estimatedAnchor = estimatedAnchor,
        _afterWrite = afterWrite,
        _onClose = onClose;

  final sqflite.Database _delegate;
  final int? Function() _estimatedAnchor;
  final void Function() _afterWrite;
  final Future<void> Function() _onClose;

  Future<void> _stamp(sqflite.DatabaseExecutor executor) async {
    final anchor = _estimatedAnchor();
    if (anchor == null) return;
    await executor.update(
      _stateTable,
      {'trusted': 1, 'anchor_wall': anchor},
      where: 'id = 1',
    );
  }

  Future<T> _write<T>(
    Future<T> Function(sqflite.Transaction transaction) operation,
  ) async {
    final result = await _delegate.transaction((transaction) async {
      await _stamp(transaction);
      return operation(transaction);
    });
    _afterWrite();
    return result;
  }

  @override
  String get path => _delegate.path;

  @override
  bool get isOpen => _delegate.isOpen;

  @override
  sqflite.Database get database => this;

  @override
  Future<void> close() async {
    await _onClose();
    await _delegate.close();
  }

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) =>
      _write((transaction) => transaction.execute(sql, arguments));

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) =>
      _write((transaction) => transaction.rawInsert(sql, arguments));

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    sqflite.ConflictAlgorithm? conflictAlgorithm,
  }) =>
      _write(
        (transaction) => transaction.insert(
          table,
          values,
          nullColumnHack: nullColumnHack,
          conflictAlgorithm: conflictAlgorithm,
        ),
      );

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) =>
      _write((transaction) => transaction.rawUpdate(sql, arguments));

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    sqflite.ConflictAlgorithm? conflictAlgorithm,
  }) =>
      _write(
        (transaction) => transaction.update(
          table,
          values,
          where: where,
          whereArgs: whereArgs,
          conflictAlgorithm: conflictAlgorithm,
        ),
      );

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) =>
      _write((transaction) => transaction.rawDelete(sql, arguments));

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) =>
      _write(
        (transaction) => transaction.delete(
          table,
          where: where,
          whereArgs: whereArgs,
        ),
      );

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) =>
      _delegate.query(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) =>
      _delegate.rawQuery(sql, arguments);

  @override
  Future<sqflite.QueryCursor> queryCursor(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
    int? bufferSize,
  }) =>
      _delegate.queryCursor(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
        bufferSize: bufferSize,
      );

  @override
  Future<sqflite.QueryCursor> rawQueryCursor(
    String sql,
    List<Object?>? arguments, {
    int? bufferSize,
  }) =>
      _delegate.rawQueryCursor(sql, arguments, bufferSize: bufferSize);

  @override
  Future<T> transaction<T>(
    Future<T> Function(sqflite.Transaction transaction) action, {
    bool? exclusive,
  }) async {
    late _SyncTransaction wrapped;
    final result = await _delegate.transaction((transaction) {
      wrapped = _SyncTransaction(
        transaction,
        root: this,
        estimatedAnchor: _estimatedAnchor,
      );
      return action(wrapped);
    }, exclusive: exclusive);
    if (wrapped.wrote) _afterWrite();
    return result;
  }

  @override
  Future<T> readTransaction<T>(
    Future<T> Function(sqflite.Transaction transaction) action,
  ) =>
      _delegate.readTransaction(action);

  @override
  sqflite.Batch batch() => _SyncBatch(
        newBatch: _delegate.batch,
        estimatedAnchor: _estimatedAnchor,
        afterWrite: _afterWrite,
        commit: (
          operations,
          hasWrites, {
          exclusive,
          noResult,
          continueOnError,
        }) async {
          final result = await _delegate.transaction((transaction) async {
            if (hasWrites) await _stamp(transaction);
            final batch = transaction.batch();
            for (final operation in operations) {
              operation(batch);
            }
            return batch.apply(
              noResult: noResult,
              continueOnError: continueOnError,
            );
          }, exclusive: exclusive);
          if (hasWrites) _afterWrite();
          return result;
        },
      );

  @override
  Future<T> devInvokeMethod<T>(String method, [Object? arguments]) =>
      _delegate.devInvokeMethod<T>(method, arguments);

  @override
  Future<T> devInvokeSqlMethod<T>(
    String method,
    String sql, [
    List<Object?>? arguments,
  ]) =>
      _delegate.devInvokeSqlMethod<T>(method, sql, arguments);
}

class _SyncTransaction implements sqflite.Transaction {
  _SyncTransaction(
    this._delegate, {
    required _SyncDatabase root,
    required int? Function() estimatedAnchor,
  })  : _root = root,
        _estimatedAnchor = estimatedAnchor;

  final sqflite.Transaction _delegate;
  final _SyncDatabase _root;
  final int? Function() _estimatedAnchor;
  bool wrote = false;

  Future<void> _beforeWrite() async {
    final anchor = _estimatedAnchor();
    if (anchor != null) {
      await _delegate.update(
        _stateTable,
        {'trusted': 1, 'anchor_wall': anchor},
        where: 'id = 1',
      );
    }
  }

  Future<T> _write<T>(Future<T> Function() operation) async {
    await _beforeWrite();
    final result = await operation();
    wrote = true;
    return result;
  }

  @override
  sqflite.Database get database => _root;

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) =>
      _write(() => _delegate.execute(sql, arguments));

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) =>
      _write(() => _delegate.rawInsert(sql, arguments));

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    sqflite.ConflictAlgorithm? conflictAlgorithm,
  }) =>
      _write(
        () => _delegate.insert(
          table,
          values,
          nullColumnHack: nullColumnHack,
          conflictAlgorithm: conflictAlgorithm,
        ),
      );

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) =>
      _write(() => _delegate.rawUpdate(sql, arguments));

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    sqflite.ConflictAlgorithm? conflictAlgorithm,
  }) =>
      _write(
        () => _delegate.update(
          table,
          values,
          where: where,
          whereArgs: whereArgs,
          conflictAlgorithm: conflictAlgorithm,
        ),
      );

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) =>
      _write(() => _delegate.rawDelete(sql, arguments));

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) =>
      _write(
        () => _delegate.delete(table, where: where, whereArgs: whereArgs),
      );

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) =>
      _delegate.query(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) =>
      _delegate.rawQuery(sql, arguments);

  @override
  Future<sqflite.QueryCursor> queryCursor(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
    int? bufferSize,
  }) =>
      _delegate.queryCursor(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
        bufferSize: bufferSize,
      );

  @override
  Future<sqflite.QueryCursor> rawQueryCursor(
    String sql,
    List<Object?>? arguments, {
    int? bufferSize,
  }) =>
      _delegate.rawQueryCursor(sql, arguments, bufferSize: bufferSize);

  @override
  sqflite.Batch batch() => _SyncBatch(
        newBatch: _delegate.batch,
        estimatedAnchor: _estimatedAnchor,
        markWrite: () => wrote = true,
      );
}

typedef _BatchOperation = void Function(sqflite.Batch batch);
typedef _BatchCommit = Future<List<Object?>> Function(
  List<_BatchOperation> operations,
  bool hasWrites, {
  bool? exclusive,
  bool? noResult,
  bool? continueOnError,
});

class _SyncBatch implements sqflite.Batch {
  _SyncBatch({
    required sqflite.Batch Function() newBatch,
    required int? Function() estimatedAnchor,
    void Function()? afterWrite,
    void Function()? markWrite,
    _BatchCommit? commit,
  })  : _newBatch = newBatch,
        _estimatedAnchor = estimatedAnchor,
        _afterWrite = afterWrite,
        _markWrite = markWrite,
        _commit = commit;

  final sqflite.Batch Function() _newBatch;
  final int? Function() _estimatedAnchor;
  final void Function()? _afterWrite;
  final void Function()? _markWrite;
  final _BatchCommit? _commit;
  final List<_BatchOperation> _operations = <_BatchOperation>[];
  bool _hasWrites = false;
  bool _applied = false;

  void _add(_BatchOperation operation, {required bool write}) {
    if (_applied) throw StateError('batch has already been applied');
    _operations.add(operation);
    _hasWrites = _hasWrites || write;
  }

  @override
  int get length => _operations.length;

  @override
  void execute(String sql, [List<Object?>? arguments]) =>
      _add((batch) => batch.execute(sql, arguments), write: true);

  @override
  void rawInsert(String sql, [List<Object?>? arguments]) =>
      _add((batch) => batch.rawInsert(sql, arguments), write: true);

  @override
  void insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    sqflite.ConflictAlgorithm? conflictAlgorithm,
  }) =>
      _add(
        (batch) => batch.insert(
          table,
          values,
          nullColumnHack: nullColumnHack,
          conflictAlgorithm: conflictAlgorithm,
        ),
        write: true,
      );

  @override
  void rawUpdate(String sql, [List<Object?>? arguments]) =>
      _add((batch) => batch.rawUpdate(sql, arguments), write: true);

  @override
  void update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    sqflite.ConflictAlgorithm? conflictAlgorithm,
  }) =>
      _add(
        (batch) => batch.update(
          table,
          values,
          where: where,
          whereArgs: whereArgs,
          conflictAlgorithm: conflictAlgorithm,
        ),
        write: true,
      );

  @override
  void rawDelete(String sql, [List<Object?>? arguments]) =>
      _add((batch) => batch.rawDelete(sql, arguments), write: true);

  @override
  void delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) =>
      _add(
        (batch) => batch.delete(table, where: where, whereArgs: whereArgs),
        write: true,
      );

  @override
  void query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) =>
      _add(
        (batch) => batch.query(
          table,
          distinct: distinct,
          columns: columns,
          where: where,
          whereArgs: whereArgs,
          groupBy: groupBy,
          having: having,
          orderBy: orderBy,
          limit: limit,
          offset: offset,
        ),
        write: false,
      );

  @override
  void rawQuery(String sql, [List<Object?>? arguments]) =>
      _add((batch) => batch.rawQuery(sql, arguments), write: false);

  sqflite.Batch _build(int? anchor) {
    if (_applied) throw StateError('batch has already been applied');
    _applied = true;
    final batch = _newBatch();
    if (anchor != null) {
      batch.update(
        _stateTable,
        {'trusted': 1, 'anchor_wall': anchor},
        where: 'id = 1',
      );
    }
    for (final operation in _operations) {
      operation(batch);
    }
    return batch;
  }

  Future<List<Object?>> _finish(
    Future<List<Object?>> Function(sqflite.Batch batch) apply, {
    required bool? noResult,
  }) async {
    final anchor = _hasWrites ? _estimatedAnchor() : null;
    final hasSyntheticResult = anchor != null;
    final result = await apply(_build(anchor));
    if (_hasWrites) {
      _markWrite?.call();
      _afterWrite?.call();
    }
    if (noResult == true || !hasSyntheticResult || result.isEmpty) return result;
    return result.sublist(1);
  }

  @override
  Future<List<Object?>> commit({
    bool? exclusive,
    bool? noResult,
    bool? continueOnError,
  }) {
    final commit = _commit;
    if (commit == null) {
      return _finish(
        (batch) => batch.commit(
          exclusive: exclusive,
          noResult: noResult,
          continueOnError: continueOnError,
        ),
        noResult: noResult,
      );
    }
    if (_applied) throw StateError('batch has already been applied');
    _applied = true;
    return commit(
      List<_BatchOperation>.unmodifiable(_operations),
      _hasWrites,
      exclusive: exclusive,
      noResult: noResult,
      continueOnError: continueOnError,
    );
  }

  @override
  Future<List<Object?>> apply({
    bool? noResult,
    bool? continueOnError,
  }) {
    final commit = _commit;
    if (commit == null) {
      return _finish(
        (batch) => batch.apply(
          noResult: noResult,
          continueOnError: continueOnError,
        ),
        noResult: noResult,
      );
    }
    if (_applied) throw StateError('batch has already been applied');
    _applied = true;
    return commit(
      List<_BatchOperation>.unmodifiable(_operations),
      _hasWrites,
      noResult: noResult,
      continueOnError: continueOnError,
    );
  }
}
