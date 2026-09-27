import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dcomic/database/sync/sync_models.dart';
import 'package:dcomic/database/sync/sync_store.dart';

class DatabaseBackupException implements Exception {
  const DatabaseBackupException(this.message);

  final String message;

  @override
  String toString() => 'DatabaseBackupException: $message';
}

class DatabaseBackup {
  DatabaseBackup(this._store);

  static const _format = 'dcomic-logical-backup';
  static const _version = 1;
  static const _maximumBytes = 32 * 1024 * 1024;
  static const _maximumRecords = 100000;
  static const _iterations = 210000;
  static const _minimumIterations = 100000;
  static const _maximumIterations = 1000000;

  final SyncStore _store;
  final AesGcm _cipher = AesGcm.with256bits();

  Future<Uint8List> export(
    Set<SyncCategory> categories, {
    String? password,
  }) async {
    if (categories.isEmpty) {
      throw const DatabaseBackupException('请至少选择一个备份分类');
    }
    final secret = _usablePassword(password);
    if (categories.contains(SyncCategory.credentials) && secret == null) {
      throw const DatabaseBackupException('包含登录凭据的备份必须设置密码');
    }
    final records = await _store.snapshot(categories);
    _store.validateRecords(records);
    final body = <String, dynamic>{
      'categories': [
        for (final category in SyncCategory.values)
          if (categories.contains(category)) category.name,
      ],
      'records': [for (final record in records) record.toJson()],
    };
    _validateBody(body, encrypted: secret != null);
    final Map<String, dynamic> envelope;
    if (secret == null) {
      envelope = {
        'format': _format,
        'version': _version,
        'encrypted': false,
        ...body,
      };
    } else {
      final salt = _cipher.newNonce();
      final nonce = _cipher.newNonce();
      final key = await _deriveKey(secret, salt, _iterations);
      final cleartext = utf8.encode(jsonEncode(body));
      final box = await _cipher.encrypt(
        cleartext,
        secretKey: key,
        nonce: nonce,
      );
      envelope = {
        'format': _format,
        'version': _version,
        'encrypted': true,
        'kdf': {
          'name': 'pbkdf2-sha256',
          'iterations': _iterations,
          'salt': base64Encode(salt),
        },
        'cipher': {
          'name': 'aes-256-gcm',
          'nonce': base64Encode(box.nonce),
          'mac': base64Encode(box.mac.bytes),
          'data': base64Encode(box.cipherText),
        },
      };
    }
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
    if (bytes.length > _maximumBytes) {
      throw const DatabaseBackupException('备份超过 32 MiB 大小限制');
    }
    return bytes;
  }

  Future<Set<SyncCategory>> inspect(
    Uint8List bytes, {
    String? password,
  }) async {
    final decoded = await _decode(bytes, password: password);
    return Set<SyncCategory>.unmodifiable(decoded.categories);
  }

  Future<void> importData(
    Uint8List bytes,
    Set<SyncCategory> categories, {
    String? password,
    bool replace = false,
  }) async {
    if (categories.isEmpty) return;
    final decoded = await _decode(bytes, password: password);
    if (!decoded.categories.containsAll(categories)) {
      final missing = categories.difference(decoded.categories);
      throw DatabaseBackupException(
        '备份不包含所选分类：${missing.map((item) => item.label).join('、')}',
      );
    }
    try {
      await _store.importRecords(
        decoded.records,
        categories,
        replace: replace,
      );
    } on FormatException catch (error) {
      throw DatabaseBackupException('无法安全合并备份：${error.message}');
    } on StateError catch (error) {
      throw DatabaseBackupException('无法安全合并备份：${error.message}');
    }
  }

  Future<_DecodedBackup> _decode(
    Uint8List bytes, {
    String? password,
  }) async {
    if (bytes.isEmpty || bytes.length > _maximumBytes) {
      throw const DatabaseBackupException('备份文件为空或超过 32 MiB 限制');
    }
    Map<String, dynamic> envelope;
    try {
      final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
      if (decoded is! Map) throw const FormatException();
      envelope = Map<String, dynamic>.from(decoded);
    } on Object {
      throw const DatabaseBackupException('备份文件不是有效的 UTF-8 JSON');
    }
    if (envelope['format'] != _format || envelope['version'] != _version) {
      throw const DatabaseBackupException('不支持的备份格式或版本');
    }
    final encrypted = envelope['encrypted'];
    if (encrypted is! bool) {
      throw const DatabaseBackupException('备份缺少加密标记');
    }
    Map<String, dynamic> body;
    if (!encrypted) {
      _requireKeys(
        envelope,
        const {'format', 'version', 'encrypted', 'categories', 'records'},
      );
      body = {
        'categories': envelope['categories'],
        'records': envelope['records'],
      };
    } else {
      _requireKeys(
        envelope,
        const {'format', 'version', 'encrypted', 'kdf', 'cipher'},
      );
      final secret = _usablePassword(password);
      if (secret == null) {
        throw const DatabaseBackupException('此备份已加密，请输入密码');
      }
      try {
        final kdf = Map<String, dynamic>.from(envelope['kdf'] as Map);
        final cipher = Map<String, dynamic>.from(envelope['cipher'] as Map);
        _requireKeys(kdf, const {'name', 'iterations', 'salt'});
        _requireKeys(cipher, const {'name', 'nonce', 'mac', 'data'});
        if (kdf['name'] != 'pbkdf2-sha256' ||
            cipher['name'] != 'aes-256-gcm') {
          throw const FormatException('unsupported algorithms');
        }
        final iterations = kdf['iterations'];
        if (iterations is! int ||
            iterations < _minimumIterations ||
            iterations > _maximumIterations) {
          throw const FormatException('unsafe KDF work factor');
        }
        final salt = _decodeBase64(kdf['salt'], minimum: 12, maximum: 64);
        final nonce = _decodeBase64(cipher['nonce'], minimum: 12, maximum: 32);
        final mac = _decodeBase64(cipher['mac'], minimum: 16, maximum: 16);
        final ciphertext = _decodeBase64(
          cipher['data'],
          minimum: 1,
          maximum: _maximumBytes,
        );
        final key = await _deriveKey(secret, salt, iterations);
        final cleartext = await _cipher.decrypt(
          SecretBox(ciphertext, nonce: nonce, mac: Mac(mac)),
          secretKey: key,
        );
        if (cleartext.length > _maximumBytes) {
          throw const FormatException('decrypted payload is too large');
        }
        final decoded = jsonDecode(
          utf8.decode(cleartext, allowMalformed: false),
        );
        if (decoded is! Map) throw const FormatException();
        body = Map<String, dynamic>.from(decoded);
      } on DatabaseBackupException {
        rethrow;
      } on Object {
        throw const DatabaseBackupException('密码错误或备份文件已损坏');
      }
    }
    return _validateBody(body, encrypted: encrypted);
  }

  _DecodedBackup _validateBody(
    Map<String, dynamic> body, {
    required bool encrypted,
  }) {
    _requireKeys(body, const {'categories', 'records'});
    final rawCategories = body['categories'];
    final rawRecords = body['records'];
    if (rawCategories is! List || rawRecords is! List) {
      throw const DatabaseBackupException('备份分类或记录列表格式无效');
    }
    if (rawRecords.length > _maximumRecords) {
      throw const DatabaseBackupException('备份记录数量超过限制');
    }
    final categories = <SyncCategory>{};
    for (final raw in rawCategories) {
      if (raw is! String) {
        throw const DatabaseBackupException('备份分类名称格式无效');
      }
      final matches = SyncCategory.values.where(
        (category) => category.name == raw,
      );
      if (matches.isEmpty || !categories.add(matches.single)) {
        throw DatabaseBackupException('备份包含未知或重复分类：$raw');
      }
    }
    if (categories.contains(SyncCategory.credentials) && !encrypted) {
      throw const DatabaseBackupException('未加密备份不得包含登录凭据');
    }
    final records = <SyncRecord>[];
    final identities = <String>{};
    try {
      for (final raw in rawRecords) {
        if (raw is! Map) throw const FormatException('record is not an object');
        final record = SyncRecord.fromJson(Map<String, dynamic>.from(raw));
        if (!categories.contains(record.category)) {
          throw const FormatException('record category is not declared');
        }
        final identity = '${record.category.name}\u0000${record.key}';
        if (!identities.add(identity)) {
          throw const FormatException('duplicate record identity');
        }
        if (record.key.length > 16384 ||
            jsonEncode(record.value).length > 2 * 1024 * 1024) {
          throw const FormatException('record exceeds size limit');
        }
        records.add(record);
      }
      _store.validateRecords(records);
    } on FormatException catch (error) {
      throw DatabaseBackupException('备份记录无效：${error.message}');
    } on ArgumentError catch (error) {
      throw DatabaseBackupException('备份记录无效：${error.message}');
    }
    return _DecodedBackup(
      Set<SyncCategory>.unmodifiable(categories),
      List<SyncRecord>.unmodifiable(records),
    );
  }

  Future<SecretKey> _deriveKey(
    String password,
    List<int> salt,
    int iterations,
  ) =>
      Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: iterations,
        bits: 256,
      ).deriveKey(
        secretKey: SecretKey(utf8.encode(password)),
        nonce: salt,
      );

  static String? _usablePassword(String? password) =>
      password == null || password.isEmpty ? null : password;

  static List<int> _decodeBase64(
    Object? encoded, {
    required int minimum,
    required int maximum,
  }) {
    if (encoded is! String) throw const FormatException('invalid base64 field');
    final bytes = base64Decode(encoded);
    if (bytes.length < minimum || bytes.length > maximum) {
      throw const FormatException('invalid binary field length');
    }
    return bytes;
  }

  static void _requireKeys(Map<String, dynamic> map, Set<String> keys) {
    if (map.length != keys.length || !map.keys.toSet().containsAll(keys)) {
      throw const DatabaseBackupException('备份包含缺失或未知字段');
    }
  }
}

class _DecodedBackup {
  const _DecodedBackup(this.categories, this.records);

  final Set<SyncCategory> categories;
  final List<SyncRecord> records;
}
