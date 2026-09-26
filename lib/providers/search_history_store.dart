import 'dart:async';
import 'dart:convert';

import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/entity/config.dart';

class SearchHistoryStore {
  SearchHistoryStore({Future<ConfigDao> Function()? daoLoader})
    : _daoLoader = daoLoader ?? _loadDefaultDao;

  static const _configKey = 'SearchHistory';
  static const _maximumEntries = 20;
  static Future<void> _queue = Future<void>.value();

  final Future<ConfigDao> Function() _daoLoader;

  Future<List<String>> load() => _serialize(() async {
    final dao = await _daoLoader();
    final stored = await _read(dao);
    return _snapshot(stored.entries);
  });

  Future<List<String>> record(String query) => _serialize(() async {
    final dao = await _daoLoader();
    final stored = await _read(dao);
    final normalized = query.trim();
    if (normalized.isEmpty) return _snapshot(stored.entries);

    final updated = <String>[
      normalized,
      for (final entry in stored.entries)
        if (entry != normalized) entry,
    ];
    if (updated.length > _maximumEntries) {
      updated.removeRange(_maximumEntries, updated.length);
    }
    await _persist(dao, stored.entity, updated);
    return _snapshot(updated);
  });

  Future<List<String>> remove(String query) => _serialize(() async {
    final dao = await _daoLoader();
    final stored = await _read(dao);
    final normalized = query.trim();
    if (normalized.isEmpty || !stored.entries.contains(normalized)) {
      return _snapshot(stored.entries);
    }

    final updated = stored.entries
        .where((entry) => entry != normalized)
        .toList(growable: false);
    await _persist(dao, stored.entity, updated);
    return _snapshot(updated);
  });

  Future<List<String>> clear() => _serialize(() async {
    final dao = await _daoLoader();
    final stored = await _read(dao);
    if (stored.entity == null || stored.entries.isNotEmpty) {
      await _persist(dao, stored.entity, const []);
    }
    return const <String>[];
  });

  static Future<ConfigDao> _loadDefaultDao() async =>
      (await DatabaseInstance.instance).configDao;

  static Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        result.complete(await operation());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  static Future<_StoredHistory> _read(ConfigDao dao) async {
    final entity = await dao.getConfigByKey(_configKey);
    if (entity == null) return const _StoredHistory(null, []);

    final value = entity.value;
    if (value == null) {
      throw const FormatException('Search history is null');
    }
    final decoded = jsonDecode(value);
    if (decoded is! List) {
      throw const FormatException('Search history is not a JSON list');
    }

    final entries = <String>[];
    final seen = <String>{};
    for (final item in decoded) {
      if (item is! String ||
          item.isEmpty ||
          item.trim() != item ||
          !seen.add(item)) {
        throw const FormatException('Search history contains an invalid entry');
      }
      entries.add(item);
    }
    if (entries.length > _maximumEntries) {
      throw const FormatException('Search history exceeds its entry limit');
    }
    return _StoredHistory(entity, entries);
  }

  static Future<void> _persist(
    ConfigDao dao,
    ConfigEntity? entity,
    List<String> entries,
  ) async {
    final encoded = jsonEncode(entries);
    if (entity == null) {
      await dao.insertConfig(
        ConfigEntity.createConfigEntity(_configKey, encoded),
      );
      return;
    }

    entity.set(encoded);
    await dao.updateConfig(entity);
  }

  static List<String> _snapshot(Iterable<String> entries) =>
      List<String>.unmodifiable(entries);
}

class _StoredHistory {
  const _StoredHistory(this.entity, this.entries);

  final ConfigEntity? entity;
  final List<String> entries;
}
