import 'dart:convert';

import 'package:sqflite/sqflite.dart' as sqflite;

/// The synchronization treatment assigned to a persisted setting key.
enum SettingSyncMode {
  /// The setting is synchronized and its wire value is validated.
  synced,

  /// The setting remains on the device that created it.
  localOnly,

  /// The setting is synchronized only through the credentials category.
  credential,
}

/// Validates a non-null persisted setting value.
typedef SettingValueValidator = void Function(String key, String value);

/// Immutable policy and value contract for one persisted setting key.
class SettingSyncDefinition {
  SettingSyncDefinition._(this.mode, this._validator, this.localOnlyReason);

  /// Creates a synchronized setting policy with a mandatory value validator.
  factory SettingSyncDefinition.synced({
    required SettingValueValidator validator,
  }) => SettingSyncDefinition._(SettingSyncMode.synced, validator, null);

  /// Creates a local-only policy and records why synchronization is unsuitable.
  factory SettingSyncDefinition.localOnly({required String reason}) {
    if (reason.trim().isEmpty) {
      throw ArgumentError.value(reason, 'reason', 'must not be empty');
    }
    return SettingSyncDefinition._(SettingSyncMode.localOnly, null, reason);
  }

  /// Creates a credential policy whose nullable value uses the credential wire format.
  factory SettingSyncDefinition.credential() =>
      SettingSyncDefinition._(SettingSyncMode.credential, null, null);

  /// Explicit synchronization treatment for this definition.
  final SettingSyncMode mode;

  /// Explanation for a [SettingSyncMode.localOnly] policy, otherwise `null`.
  final String? localOnlyReason;

  final SettingValueValidator? _validator;

  /// Validates [value] according to this definition without exposing its contents.
  void validateValue(String key, String? value) {
    if (mode == SettingSyncMode.credential) return;
    if (value == null) {
      throw FormatException('$key must have a persisted string value');
    }
    _validator?.call(key, value);
  }
}

final class _SettingPolicyEntry {
  _SettingPolicyEntry.exact(this.pattern, this.definition)
    : caseInsensitive = false,
      namespace = false;

  _SettingPolicyEntry.caseInsensitive(this.pattern, this.definition)
    : caseInsensitive = true,
      namespace = false;

  _SettingPolicyEntry.namespace(this.pattern, this.definition)
    : caseInsensitive = false,
      namespace = true;

  final String pattern;
  final SettingSyncDefinition definition;
  final bool caseInsensitive;
  final bool namespace;
}

final class _SettingPolicyRegistry {
  _SettingPolicyRegistry(this.table, List<_SettingPolicyEntry> entries)
    : entries = List.unmodifiable(entries) {
    final exact = <String, SettingSyncDefinition>{};
    final caseInsensitive = <String, SettingSyncDefinition>{};
    final namespaces = <_SettingPolicyEntry>[];

    for (final entry in entries) {
      if (entry.namespace) {
        if (entry.pattern.isEmpty) {
          throw StateError('$table has an empty setting policy namespace');
        }
        for (final existing in namespaces) {
          if (entry.pattern.startsWith(existing.pattern) ||
              existing.pattern.startsWith(entry.pattern)) {
            throw StateError(
              '$table has overlapping setting policy namespaces '
              '"${existing.pattern}" and "${entry.pattern}"',
            );
          }
        }
        if (exact.keys.any((key) => key.startsWith(entry.pattern)) ||
            caseInsensitive.keys.any(
              (key) => key.startsWith(entry.pattern.toLowerCase()),
            )) {
          throw StateError(
            '$table setting policy namespace "${entry.pattern}" '
            'overlaps an exact key',
          );
        }
        namespaces.add(entry);
      } else if (entry.caseInsensitive) {
        final folded = entry.pattern.toLowerCase();
        if (caseInsensitive.containsKey(folded) ||
            exact.keys.any((key) => key.toLowerCase() == folded)) {
          throw StateError(
            '$table has a case-insensitive setting policy collision for '
            '"${entry.pattern}"',
          );
        }
        if (namespaces.any(
          (namespace) => folded.startsWith(namespace.pattern.toLowerCase()),
        )) {
          throw StateError(
            '$table setting policy key "${entry.pattern}" '
            'overlaps a namespace',
          );
        }
        caseInsensitive[folded] = entry.definition;
      } else {
        if (exact.containsKey(entry.pattern)) {
          throw StateError(
            '$table has duplicate setting policy key "${entry.pattern}"',
          );
        }
        final folded = entry.pattern.toLowerCase();
        if (caseInsensitive.containsKey(folded) ||
            exact.keys.any((key) => key.toLowerCase() == folded)) {
          throw StateError(
            '$table setting policy key "${entry.pattern}" '
            'collides case-insensitively',
          );
        }
        if (namespaces.any(
          (namespace) => entry.pattern.startsWith(namespace.pattern),
        )) {
          throw StateError(
            '$table setting policy key "${entry.pattern}" '
            'overlaps a namespace',
          );
        }
        exact[entry.pattern] = entry.definition;
      }
    }

    _exact = Map.unmodifiable(exact);
    _caseInsensitive = Map.unmodifiable(caseInsensitive);
    _namespaces = List.unmodifiable(namespaces);
  }

  final String table;
  final List<_SettingPolicyEntry> entries;
  late final Map<String, SettingSyncDefinition> _exact;
  late final Map<String, SettingSyncDefinition> _caseInsensitive;
  late final List<_SettingPolicyEntry> _namespaces;

  SettingSyncDefinition definition(String key) {
    final exact = _exact[key];
    if (exact != null) return exact;
    if (_caseInsensitive.isNotEmpty) {
      final caseInsensitive = _caseInsensitive[key.toLowerCase()];
      if (caseInsensitive != null) return caseInsensitive;
    }
    for (final namespace in _namespaces) {
      if (key.startsWith(namespace.pattern)) return namespace.definition;
    }
    throw StateError('Missing setting sync policy for $table key "$key"');
  }

  String sql(String column, SettingSyncMode? mode) {
    final exact = <String>[];
    final caseInsensitive = <String>[];
    final namespaces = <_SettingPolicyEntry>[];
    for (final entry in entries) {
      if (mode != null && entry.definition.mode != mode) continue;
      if (entry.namespace) {
        namespaces.add(entry);
      } else if (entry.caseInsensitive) {
        caseInsensitive.add(entry.pattern);
      } else {
        exact.add(entry.pattern);
      }
    }

    final predicates = <String>[];
    if (exact.isNotEmpty) {
      predicates.add('$column IN (${exact.map(_sqlLiteral).join(',')})');
    }
    if (caseInsensitive.isNotEmpty) {
      predicates.add(
        'lower($column) IN (${caseInsensitive.map(_sqlLiteral).join(',')})',
      );
    }
    for (final entry in namespaces) {
      predicates.add(
        'substr($column, 1, ${entry.pattern.length}) = '
        '${_sqlLiteral(entry.pattern)}',
      );
    }
    if (predicates.isEmpty) return '0';
    if (predicates.length == 1) return predicates.single;
    return '(${predicates.join(' OR ')})';
  }
}

SettingSyncDefinition _synced(SettingValueValidator validator) =>
    SettingSyncDefinition.synced(validator: validator);

final _appSettingRegistry = _SettingPolicyRegistry('ConfigEntity', [
  _SettingPolicyEntry.exact('ThemeMode', _synced(_zeroToTwo)),
  _SettingPolicyEntry.exact('ReadDirection', _synced(_zeroToTwo)),
  _SettingPolicyEntry.exact(
    'HorizontalClickAreaSize',
    _synced(_legacyClickAreaSize),
  ),
  _SettingPolicyEntry.exact(
    'VerticalClickAreaSize',
    _synced(_legacyClickAreaSize),
  ),
  _SettingPolicyEntry.exact(
    'HorizontalClickAreaPercent',
    _synced(_clickAreaPercent),
  ),
  _SettingPolicyEntry.exact(
    'VerticalClickAreaPercent',
    _synced(_clickAreaPercent),
  ),
  _SettingPolicyEntry.exact('HorizontalImageFit', _synced(_horizontalImageFit)),
  _SettingPolicyEntry.exact('VerticalImageFit', _synced(_verticalImageFit)),
  _SettingPolicyEntry.exact('ThemeColor', _synced(_themeColor)),
  _SettingPolicyEntry.exact('UseMaterial3Design', _synced(_storedBool)),
  _SettingPolicyEntry.exact('ReaderTheme', _synced(_readerTheme)),
  _SettingPolicyEntry.exact('ReaderPrecacheCount', _synced(_zeroToNine)),
  _SettingPolicyEntry.exact('ReaderEndAction', _synced(_readerEndAction)),
  _SettingPolicyEntry.exact('ReaderInfoEnabled', _synced(_storedBool)),
  _SettingPolicyEntry.exact('ReaderInfoPosition', _synced(_readerInfoPosition)),
  _SettingPolicyEntry.exact(
    'ReaderBatteryFormat',
    _synced(_readerBatteryFormat),
  ),
  _SettingPolicyEntry.exact('ReaderPageFormat', _synced(_readerPageFormat)),
  _SettingPolicyEntry.exact('ReaderInfoChapter', _synced(_storedBool)),
  _SettingPolicyEntry.exact('ReaderInfoTime', _synced(_storedBool)),
  _SettingPolicyEntry.exact('ResumeLastReadPage', _synced(_storedBool)),
  _SettingPolicyEntry.exact('AggregateSubscribeBadges', _synced(_storedBool)),
  _SettingPolicyEntry.exact('AggregateReadingProgress', _synced(_storedBool)),
  _SettingPolicyEntry.exact('AutoMapMissingComics', _synced(_storedBool)),
  _SettingPolicyEntry.exact(
    'AutoMapIntervalSeconds',
    _synced(_autoMapIntervalSeconds),
  ),
  _SettingPolicyEntry.exact('AutoMapRetryEveryLaunch', _synced(_storedBool)),
  _SettingPolicyEntry.exact('AutoMapMaxAttempts', _synced(_autoMapMaxAttempts)),
  _SettingPolicyEntry.exact(
    'sourceModelSortOrder',
    _synced(_sourceModelSortOrder),
  ),
  _SettingPolicyEntry.exact('activeHomeModelIndex', _synced(_zeroToThousand)),
  _SettingPolicyEntry.exact(
    'ExperimentalFeaturesUnlocked',
    SettingSyncDefinition.localOnly(
      reason: 'Unlock state is intentionally device-local.',
    ),
  ),
  _SettingPolicyEntry.exact(
    'SearchHistory',
    SettingSyncDefinition.localOnly(
      reason: 'Search history is private device-local activity.',
    ),
  ),
  _SettingPolicyEntry.exact(
    'UpdateChannel',
    SettingSyncDefinition.localOnly(
      reason: 'Release channel selection is device-specific.',
    ),
  ),
  _SettingPolicyEntry.exact(
    'LastTimeCheckVersion',
    SettingSyncDefinition.localOnly(
      reason: 'Update notification state is device-specific.',
    ),
  ),
  _SettingPolicyEntry.namespace(
    'AutomaticMappingAttempts:',
    SettingSyncDefinition.localOnly(
      reason: 'Automatic mapping attempt counters describe local work.',
    ),
  ),
]);

final _modelSettingRegistry = _SettingPolicyRegistry('ModelConfigEntity', [
  _SettingPolicyEntry.exact(
    'chineseDisplayLanguage',
    _synced(_chineseDisplayLanguage),
  ),
  _SettingPolicyEntry.exact('apiDomain', _synced(_apiDomain)),
  _SettingPolicyEntry.exact('chapterCommentApiDomain', _synced(_apiDomain)),
  _SettingPolicyEntry.exact('autoSignInEnabled', _synced(_storedBool)),
  for (final key in const [
    'token',
    'islogin',
    'username',
    'password',
    'userid',
    'uid',
    'refreshtoken',
    'accesstoken',
  ])
    _SettingPolicyEntry.caseInsensitive(
      key,
      SettingSyncDefinition.credential(),
    ),
]);

/// Returns the explicit policy for a `ConfigEntity` key.
///
/// Unknown keys throw a [StateError] rather than receiving a default policy.
SettingSyncDefinition appSettingDefinition(String key) =>
    _appSettingRegistry.definition(key);

/// Returns the explicit policy for a `ModelConfigEntity` key.
///
/// Credential key names are matched case-insensitively. All other names are
/// exact, and unknown keys throw a [StateError].
SettingSyncDefinition modelSettingDefinition(String key) =>
    _modelSettingRegistry.definition(key);

/// Builds a deterministic SQLite predicate from the explicit setting registry.
///
/// [table] must be `ConfigEntity` or `ModelConfigEntity`. [column] is a trusted
/// SQL expression such as `key` or `NEW.key`. Omitting [mode] matches every
/// explicitly registered policy for that table.
String settingPolicySql(String table, String column, {SettingSyncMode? mode}) {
  return switch (table) {
    'ConfigEntity' => _appSettingRegistry.sql(column, mode),
    'ModelConfigEntity' => _modelSettingRegistry.sql(column, mode),
    _ => throw ArgumentError.value(
      table,
      'table',
      'must be ConfigEntity or ModelConfigEntity',
    ),
  };
}

/// Checks every stored setting key has an explicit policy without reading values.
Future<void> validateStoredSettingPolicies(
  sqflite.DatabaseExecutor database,
) async {
  for (final registry in [_appSettingRegistry, _modelSettingRegistry]) {
    final rows = await database.rawQuery(
      'SELECT DISTINCT key FROM ${registry.table}',
    );
    for (final row in rows) {
      final key = row['key'];
      if (key is! String) {
        throw StateError(
          'Missing setting sync policy for ${registry.table} key "$key"',
        );
      }
      registry.definition(key);
    }
  }
}

/// Installs database guards that abort writes of keys missing an explicit policy.
///
/// The guards are independent of synchronization suppression and therefore also
/// protect raw SQL and batch writes.
Future<void> installSettingPolicyGuards(
  sqflite.DatabaseExecutor database,
) async {
  for (final registry in [_appSettingRegistry, _modelSettingRegistry]) {
    final insertTrigger = 'dcomic_setting_policy_${registry.table}_insert';
    final updateTrigger = 'dcomic_setting_policy_${registry.table}_update_key';
    await database.execute('DROP TRIGGER IF EXISTS $insertTrigger');
    await database.execute('DROP TRIGGER IF EXISTS $updateTrigger');

    final predicate = registry.sql('NEW.key', null);
    final error = '${registry.table} key missing setting sync policy';
    await database.execute(
      'CREATE TRIGGER $insertTrigger '
      'BEFORE INSERT ON ${registry.table} '
      'WHEN NOT ($predicate) '
      "BEGIN SELECT RAISE(ABORT, '$error'); END",
    );
    await database.execute(
      'CREATE TRIGGER $updateTrigger '
      'BEFORE UPDATE OF key ON ${registry.table} '
      'WHEN NOT ($predicate) '
      "BEGIN SELECT RAISE(ABORT, '$error'); END",
    );
  }
}

String _sqlLiteral(String value) => "'${value.replaceAll("'", "''")}'";

void _storedBool(String key, String value) {
  if (value != '0' && value != '1') throw FormatException('invalid $key');
}

void _boundedInt(String key, String value, int minimum, int maximum) {
  final parsed = int.tryParse(value);
  if (parsed == null || parsed < minimum || parsed > maximum) {
    throw FormatException('invalid $key');
  }
}

void _zeroToTwo(String key, String value) => _boundedInt(key, value, 0, 2);
void _zeroToNine(String key, String value) => _boundedInt(key, value, 0, 9);
void _zeroToThousand(String key, String value) =>
    _boundedInt(key, value, 0, 1000);
void _autoMapIntervalSeconds(String key, String value) =>
    _boundedInt(key, value, 1, 86400);
void _autoMapMaxAttempts(String key, String value) =>
    _boundedInt(key, value, 1, 1000);

void _oneOf(String key, String value, Set<String> allowed) {
  if (!allowed.contains(value)) throw FormatException('invalid $key');
}

void _themeColor(String key, String value) => _oneOf(key, value, const {
  'Blue',
  'Red',
  'Pink',
  'Purple',
  'DeepPurple',
  'Indigo',
  'LightBlue',
  'Cyan',
  'Teal',
  'LightGreen',
  'Lime',
  'Yellow',
  'Amber',
  'Orange',
  'DeepOrange',
  'Brown',
  'Grey',
  'BlueGrey',
});

void _readerTheme(String key, String value) =>
    _oneOf(key, value, const {'app', 'white', 'light', 'dark', 'black'});

void _readerInfoPosition(String key, String value) => _oneOf(key, value, const {
  'bottomLeft',
  'bottomRight',
  'topLeft',
  'topRight',
});

void _readerBatteryFormat(String key, String value) =>
    _oneOf(key, value, const {'hidden', 'icon', 'number', 'iconAndNumber'});

void _readerPageFormat(String key, String value) => _oneOf(key, value, const {
  'hidden',
  'current',
  'currentAndTotal',
  'percentage',
});

void _readerEndAction(String key, String value) =>
    _oneOf(key, value, const {'nextChapter', 'comments'});

void _horizontalImageFit(String key, String value) => _oneOf(key, value, const {
  'original',
  'actualSize',
  'contain',
  'cover',
  'stretch',
  'fitHeight',
});

void _verticalImageFit(String key, String value) => _oneOf(key, value, const {
  'original',
  'actualSize',
  'contain',
  'cover',
  'stretch',
  'fitWidth',
});

void _boundedDouble(String key, String value, double minimum, double maximum) {
  final parsed = double.tryParse(value);
  if (parsed == null ||
      !parsed.isFinite ||
      parsed < minimum ||
      parsed > maximum) {
    throw FormatException('invalid $key');
  }
}

void _clickAreaPercent(String key, String value) =>
    _boundedDouble(key, value, 5, 40);
void _legacyClickAreaSize(String key, String value) =>
    _boundedDouble(key, value, 1, 1000);

void _sourceModelSortOrder(String key, String value) {
  Object? decoded;
  try {
    decoded = jsonDecode(value);
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
}

void _chineseDisplayLanguage(String key, String value) =>
    _oneOf(key, value, const {'traditional', 'simplified'});

void _apiDomain(String key, String value) {
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
  if (value.isNotEmpty && !domains.contains(value)) {
    throw const FormatException('invalid API domain');
  }
}
