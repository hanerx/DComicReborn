import 'dart:convert';

const _maximumSyncVersionWall = 8640000000000000;

/// Logical database areas exposed by the synchronization protocol.

enum SyncCategory {
  history('阅读历史'),
  bindings('漫画绑定'),
  chapterRules('章节规则'),
  settings('应用设置'),
  sourceSettings('漫画源设置'),
  credentials('登录凭据');

  const SyncCategory(this.label);

  final String label;

  bool get sensitive => this == SyncCategory.credentials;

  static final Set<SyncCategory> defaults = Set.unmodifiable(
    values.where((category) => !category.sensitive),
  );
}

class SyncVersion implements Comparable<SyncVersion> {
  const SyncVersion({
    required this.wall,
    required this.logical,
    required this.device,
  });

  final int wall;
  final int logical;
  final String device;

  factory SyncVersion.fromJson(Map<String, dynamic> json) {
    final wall = json['wall'];
    final logical = json['logical'];
    final device = json['device'];
    if (wall is! int || wall < 0 || wall > _maximumSyncVersionWall) {
      throw const FormatException(
        'version.wall must be within the supported Unix millisecond range',
      );
    }
    if (logical is! int || logical < 0) {
      throw const FormatException(
        'version.logical must be a non-negative integer',
      );
    }
    if (device is! String || device.isEmpty) {
      throw const FormatException('version.device must be a non-empty string');
    }
    return SyncVersion(wall: wall, logical: logical, device: device);
  }

  Map<String, dynamic> toJson() => {
        'wall': wall,
        'logical': logical,
        'device': device,
      };

  @override
  int compareTo(SyncVersion other) {
    var result = wall.compareTo(other.wall);
    if (result != 0) return result;
    result = logical.compareTo(other.logical);
    if (result != 0) return result;
    return device.compareTo(other.device);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncVersion &&
          wall == other.wall &&
          logical == other.logical &&
          device == other.device;

  @override
  int get hashCode => Object.hash(wall, logical, device);

  @override
  String toString() => jsonEncode(toJson());
}

class SyncRecord {
  SyncRecord({
    required this.category,
    required this.key,
    required Map<String, dynamic>? value,
    required this.deleted,
    required this.version,
    required this.uncertain,
    this.baseVersion,
  }) : value = value == null
            ? null
            : Map<String, dynamic>.unmodifiable(
                _copyJsonMap(value, field: 'value'),
              ) {
    if (key.isEmpty) {
      throw ArgumentError.value(key, 'key', 'must not be empty');
    }
    if (deleted && value != null) {
      throw ArgumentError.value(value, 'value', 'must be null when deleted');
    }
  }

  final SyncCategory category;
  final String key;
  final Map<String, dynamic>? value;
  final bool deleted;
  final SyncVersion version;
  final bool uncertain;
  final SyncVersion? baseVersion;

  factory SyncRecord.fromJson(Map<String, dynamic> json) {
    final categoryName = json['category'];
    final key = json['key'];
    final value = json['value'];
    final deleted = json['deleted'];
    final version = json['version'];
    final uncertain = json['uncertain'];
    final baseVersion = json['baseVersion'];
    if (categoryName is! String) {
      throw const FormatException('record.category must be a string');
    }
    final category = SyncCategory.values.where(
      (candidate) => candidate.name == categoryName,
    );
    if (category.isEmpty) {
      throw FormatException('unknown sync category: $categoryName');
    }
    if (key is! String || key.isEmpty) {
      throw const FormatException('record.key must be a non-empty string');
    }
    if (value != null && value is! Map) {
      throw const FormatException('record.value must be an object or null');
    }
    if (deleted is! bool || uncertain is! bool || version is! Map) {
      throw const FormatException('record has invalid protocol field types');
    }
    if (deleted && value != null) {
      throw const FormatException('deleted record value must be null');
    }
    if (baseVersion != null && baseVersion is! Map) {
      throw const FormatException('record.baseVersion must be an object or null');
    }
    try {
      return SyncRecord(
        category: category.single,
        key: key,
        value: value == null
            ? null
            : _copyJsonMap(value, field: 'record.value'),
        deleted: deleted,
        version: SyncVersion.fromJson(
          Map<String, dynamic>.from(version),
        ),
        uncertain: uncertain,
        baseVersion: baseVersion == null
            ? null
            : SyncVersion.fromJson(
                Map<String, dynamic>.from(baseVersion),
              ),
      );
    } on ArgumentError catch (error) {
      throw FormatException(error.message?.toString() ?? 'invalid record');
    }
  }

  Map<String, dynamic> toJson() => {
        'category': category.name,
        'key': key,
        'value': value,
        'deleted': deleted,
        'version': version.toJson(),
        'uncertain': uncertain,
        'baseVersion': baseVersion?.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncRecord &&
          category == other.category &&
          key == other.key &&
          deleted == other.deleted &&
          uncertain == other.uncertain &&
          version == other.version &&
          baseVersion == other.baseVersion &&
          _jsonEquals(value, other.value);

  @override
  int get hashCode => Object.hash(
        category,
        key,
        deleted,
        uncertain,
        version,
        baseVersion,
        _canonicalJson(value),
      );

  @override
  String toString() => jsonEncode(toJson());
}

class SyncConflict {
  const SyncConflict({
    required this.id,
    required this.local,
    required this.remote,
  });

  final String id;
  final SyncRecord local;
  final SyncRecord remote;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncConflict &&
          id == other.id &&
          local == other.local &&
          remote == other.remote;

  @override
  int get hashCode => Object.hash(id, local, remote);
}

Map<String, dynamic> _copyJsonMap(Map<dynamic, dynamic> source, {
  required String field,
}) {
  try {
    final encoded = jsonEncode(source);
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) throw const FormatException();
    return Map<String, dynamic>.from(decoded);
  } on Object {
    throw FormatException('$field must contain only JSON values');
  }
}

bool _jsonEquals(Object? left, Object? right) =>
    _canonicalJson(left) == _canonicalJson(right);

String _canonicalJson(Object? value) => jsonEncode(_canonicalize(value));

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return {
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is List) return value.map(_canonicalize).toList(growable: false);
  return value;
}
