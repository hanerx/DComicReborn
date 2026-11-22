import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dcomic/database/database_common.dart';
import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/database/entity/config.dart';
import 'package:dcomic/database/sync/sync_models.dart';
import 'package:dcomic/database/sync/sync_store.dart';
import 'package:dcomic/providers/database_sync_service.dart';
import 'package:dcomic/view/settings/database_sync_page.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late DComicDatabase database;
  late SyncStore store;
  late _SyncServer server;
  late StreamController<bool> online;
  late DatabaseSyncService service;

  setUpAll(() {
    HttpOverrides.global = null;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('database_sync_service_');
    database = await $FloorDComicDatabase
        .databaseBuilder('${directory.path}/sync.db')
        .addMigrations(DatabaseInstance.migrations)
        .addCallback(DatabaseInstance.databaseCallback)
        .build();
    store = await SyncStore.attach(database);
    server = await _SyncServer.start();
    online = StreamController<bool>.broadcast();
    service = DatabaseSyncService(
      store: store,
      onlineChanges: online.stream,
      pollInterval: const Duration(days: 1),
      reconnectDelay: const Duration(days: 1),
    );
    await service.initialize();
  });

  tearDown(() async {
    service.dispose();
    await online.close();
    await server.close();
    await store.close();
    await database.close();
    await directory.delete(recursive: true);
  });


  test('starts disabled with every non-sensitive category selected', () {
    expect(service.initialized, isTrue);
    expect(service.enabled, isFalse);
    expect(
      service.categories,
      equals(SyncCategory.values.where((category) => !category.sensitive).toSet()),
    );
    expect(service.categories, isNot(contains(SyncCategory.credentials)));
  });

  test('connects to a non-loopback HTTP server origin', () async {
    service.dispose();
    final dio = Dio();
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.findProxy = (_) => 'DIRECT';
        client.connectionFactory = (uri, proxyHost, proxyPort) =>
            Socket.startConnect(InternetAddress.loopbackIPv4, uri.port);
        return client;
      },
    );
    addTearDown(() => dio.close(force: true));
    service = DatabaseSyncService(
      store: store,
      dio: dio,
      onlineChanges: online.stream,
    );
    await service.initialize();
    // Route only the test socket locally; the request retains its LAN origin.
    final origin = 'http://192.0.2.10:${Uri.parse(server.url).port}';
    await service.login(
      serverUrl: origin,
      username: 'alice',
      password: 'correct-password',
      migrateLocal: false,
    );
    expect(service.error, isNull);
    expect(service.username, 'alice');
    expect(service.serverUrl, origin);
  });

  test('failed login keeps the previous account and connection usable', () async {
    await service.login(
      serverUrl: server.url,
      username: 'alice',
      password: 'correct-password',
      migrateLocal: false,
    );
    expect(service.error, isNull);
    expect(service.username, 'alice');
    expect(service.serverUrl, server.url);

    server.rejectLogin = true;
    await service.login(
      serverUrl: server.url,
      username: 'mallory',
      password: 'wrong-password',
      migrateLocal: false,
    );

    expect(service.error, isNotNull);
    expect(service.username, 'alice');
    expect(service.serverUrl, server.url);
    server.rejectLogin = false;
    await service.setEnabled(true);
    await _waitFor(() => service.lastSuccess != null);
    expect(service.lastSuccess, isNotNull);
  });

  test('login reconciles all pull pages before uploading colliding offline edits',
      () async {
    await database.configDao.insertConfig(
      ConfigEntity.createConfigEntity('ThemeColor', 'Blue'),
    );
    final local = (await store.pending({SyncCategory.settings})).single;
    final remote = SyncRecord(
      category: local.category,
      key: local.key,
      value: const {'value': 'Red'},
      deleted: false,
      version: local.version,
      uncertain: local.uncertain,
      baseVersion: local.baseVersion,
    );
    final firstPage = SyncRecord(
      category: SyncCategory.settings,
      key: 'ThemeMode',
      value: const {'value': '2'},
      deleted: false,
      version: const SyncVersion(wall: 1, logical: 0, device: 'remote'),
      uncertain: false,
    );
    server.onSync = (body) async {
      final changes = (body['changes'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      server.syncStatusCode = HttpStatus.ok;
      if (changes.isEmpty) {
        final cursor = body['cursor']! as int;
        return {
          ...server.responseFor(body, cursor: cursor == 0 ? 1 : 2),
          'hasMore': cursor == 0,
          'records': [
            if (cursor == 0) firstPage.toJson(),
            if (cursor == 1) remote.toJson(),
          ],
        };
      }
      final response = server.responseFor(body, cursor: 2);
      final results = <Map<String, dynamic>>[];
      for (final change in changes) {
        final candidate = SyncRecord.fromJson(change);
        if (candidate.category == remote.category &&
            candidate.key == remote.key) {
          if (candidate.version == remote.version) {
            server.syncStatusCode = HttpStatus.conflict;
            return {
              'error': {
                'code': 'version_reuse',
                'message': 'record version was reused with different content',
              },
            };
          }
          server.conflicts.add({
            'local': candidate.toJson(),
            'remote': remote.toJson(),
          });
          results.add({
            'category': candidate.category.name,
            'key': candidate.key,
            'status': 'conflict',
            'record': remote.toJson(),
          });
        } else {
          results.add({
            'category': candidate.category.name,
            'key': candidate.key,
            'status': 'accepted',
            'record': change,
          });
        }
      }
      return {...response, 'results': results};
    };

    await service.login(
      serverUrl: server.url,
      username: 'alice',
      password: 'correct-password',
      migrateLocal: true,
    );
    await service.setEnabled(true);
    await _waitFor(
      () => !service.busy &&
          (service.error != null || service.conflicts.isNotEmpty),
    );

    expect(service.error, isNull);
    final conflict = service.conflicts.single;
    expect(conflict.local.value, local.value);
    expect(conflict.local.version.compareTo(remote.version), greaterThan(0));
    expect(conflict.local.baseVersion, local.baseVersion);
    expect(conflict.local.uncertain, isTrue);
    expect(conflict.remote, remote);
    expect(
      (await database.configDao.getConfigByKey('ThemeMode'))?.get<int>(),
      2,
    );
  });

  test('a category enabled during a request resets the next pull cursor', () async {
    server.nextCursor = 23;
    await _loginAndEnable(service, server.url);
    await _waitFor(() => server.syncBodies.isNotEmpty);
    await _waitFor(() => service.lastSuccess != null);

    final requestStarted = Completer<void>();
    final releaseRequest = Completer<void>();
    server.onSync = (body) async {
      if (!requestStarted.isCompleted) requestStarted.complete();
      await releaseRequest.future;
      return server.responseFor(body, cursor: 77);
    };

    final sync = service.syncNow();
    await requestStarted.future.timeout(const Duration(seconds: 2));
    await service.setCategory(SyncCategory.credentials, true);
    releaseRequest.complete();
    await sync.timeout(const Duration(seconds: 2));
    await _waitFor(() => server.syncBodies.length >= 3);

    final retried = server.syncBodies.last;
    expect(retried['cursor'], 0);
    expect(
      (retried['categories'] as List<dynamic>).cast<String>(),
      contains(SyncCategory.credentials.name),
    );
  });

  test('background pauses uploads and resume flushes pending edits', () async {
    await _loginAndEnable(service, server.url);
    await _waitFor(() => server.syncBodies.isNotEmpty);
    final requestsBeforePause = server.syncBodies.length;

    service.didChangeAppLifecycleState(AppLifecycleState.paused);
    await database.configDao.insertConfig(
      ConfigEntity.createConfigEntity('ThemeMode', 1),
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(server.syncBodies.length, requestsBeforePause);

    service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await _waitFor(
      () => server.syncBodies.skip(requestsBeforePause).any(
        (body) => (body['changes'] as List<dynamic>).isNotEmpty,
      ),
    );
  });

  test('acknowledging an in-flight version does not drop a newer edit', () async {
    await _loginAndEnable(service, server.url);
    await _waitFor(() => server.syncBodies.isNotEmpty);

    final firstEditReceived = Completer<Map<String, dynamic>>();
    final releaseFirstEdit = Completer<void>();
    var editRequests = 0;
    Map<String, dynamic>? newestUploaded;
    server.onSync = (body) async {
      final changes = (body['changes'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      if (changes.isNotEmpty) {
        editRequests++;
        if (editRequests == 1) {
          firstEditReceived.complete(changes.single);
          await releaseFirstEdit.future;
        } else if (editRequests == 2) {
          newestUploaded = changes.single;
        }
      }
      return server.responseFor(body);
    };

    await database.configDao.insertConfig(
      ConfigEntity.createConfigEntity('ThemeColor', 'Blue'),
    );
    final sent = await firstEditReceived.future.timeout(
      const Duration(seconds: 2),
    );
    final setting = await database.configDao.getConfigByKey('ThemeColor');
    setting!.set('Purple');
    await database.configDao.updateConfig(setting);
    releaseFirstEdit.complete();

    await _waitFor(() => editRequests >= 2);
    await _waitFor(() => !service.busy);
    final newest = newestUploaded!;
    expect(newest['version'], isNot(equals(sent['version'])));
    expect(await store.pendingCount({SyncCategory.settings}), 0);
  });

  test('category disabled in flight ignores its late records', () async {
    await _loginAndEnable(service, server.url);
    await _waitFor(() => service.lastSuccess != null);
    await _waitFor(() => !service.busy);
    await service.setCategory(SyncCategory.credentials, true);
    await _waitFor(() => !service.busy);
    await Future<void>.delayed(Duration.zero);

    final requestStarted = Completer<int>();
    final releaseRequest = Completer<void>();
    var held = false;
    final credentials = SyncRecord(
      category: SyncCategory.credentials,
      key: 'accounts',
      value: const {
        'cookies': [
          {'key': 'auth', 'value': 'private-cookie'},
        ],
        'configs': <Object>[],
      },
      deleted: false,
      version: const SyncVersion(wall: 25, logical: 0, device: 'server'),
      uncertain: false,
    );
    server.onSync = (body) async {
      if (!held) {
        held = true;
        requestStarted.complete(body['cursor']! as int);
        await releaseRequest.future;
        return {
          ...server.responseFor(body),
          'records': [credentials.toJson()],
        };
      }
      return server.responseFor(body);
    };

    final sync = service.syncNow();
    final heldCursor = await requestStarted.future.timeout(
      const Duration(seconds: 2),
    );
    await service.setCategory(SyncCategory.credentials, false);
    releaseRequest.complete();
    await sync.timeout(const Duration(seconds: 2));
    await _waitFor(() => !service.busy);

    expect(service.categories, isNot(contains(SyncCategory.credentials)));
    expect(await database.database.query('CookieEntity'), isEmpty);
    expect(server.syncBodies.last['cursor'], heldCursor);
  });

  testWidgets('last sync status stays within a narrow phone viewport',
      (tester) async {
    await tester.runAsync(() async {
      await _loginAndEnable(service, server.url);
      await service.syncNow();
    });
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<DatabaseSyncService>.value(
        value: service,
        child: const MaterialApp(home: DatabaseSyncPage()),
      ),
    );
    final label = find.textContaining('Last success ');
    expect(label, findsOneWidget);
    final bounds = tester.getRect(label);
    expect(bounds.left, greaterThanOrEqualTo(0));
    expect(bounds.right, lessThanOrEqualTo(320));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('source device names refresh without leaking across accounts', () async {
    server.deviceNames['other-phone'] = 'Pixel 9';
    await _loginAndEnable(service, server.url);
    await service.syncNow();
    expect(service.sourceDeviceName('other-phone'), 'Pixel 9');

    server.deviceNames['other-phone'] = 'Reading phone';
    await service.syncNow();
    expect(service.sourceDeviceName('other-phone'), 'Reading phone');

    server.deviceNames.clear();
    server.userId = 'user-2';
    await service.login(
      serverUrl: server.url,
      username: 'bob',
      password: 'correct-password',
      migrateLocal: false,
    );
    expect(service.sourceDeviceName('other-phone'), 'other-phone');
  });

  test('server conflict list removes a candidate resolved elsewhere', () async {
    await _loginAndEnable(service, server.url);
    await _waitFor(() => service.lastSuccess != null);
    await _waitFor(() => !service.busy);
    final local = SyncRecord(
      category: SyncCategory.settings,
      key: 'ThemeMode',
      value: const {'value': '1'},
      deleted: false,
      version: const SyncVersion(wall: 10, logical: 0, device: 'local'),
      uncertain: true,
    );
    final remote = SyncRecord(
      category: SyncCategory.settings,
      key: 'ThemeMode',
      value: const {'value': '2'},
      deleted: false,
      version: const SyncVersion(wall: 11, logical: 0, device: 'remote'),
      uncertain: true,
    );
    await store.addConflict(local, remote);
    final conflict = (await store.conflicts()).single;
    await store.resolveConflict(conflict.id, useLocal: true);
    expect(await store.pendingResolution(conflict.id), isNotNull);

    await service.syncNow();

    expect(await store.conflicts(), isEmpty);
    expect(service.error, isNull);
  });

  test('conflict pruning preserves a newer canonical pull', () async {
    await _loginAndEnable(service, server.url);
    await _waitFor(() => service.lastSuccess != null);
    await _waitFor(() => !service.busy);
    final local = SyncRecord(
      category: SyncCategory.settings,
      key: 'ReaderTheme',
      value: const {'value': 'app'},
      deleted: false,
      version: const SyncVersion(wall: 30, logical: 0, device: 'local'),
      uncertain: true,
    );
    final oldRemote = SyncRecord(
      category: SyncCategory.settings,
      key: 'ReaderTheme',
      value: const {'value': 'white'},
      deleted: false,
      version: const SyncVersion(wall: 31, logical: 0, device: 'remote'),
      uncertain: true,
    );
    final newest = SyncRecord(
      category: SyncCategory.settings,
      key: 'ReaderTheme',
      value: const {'value': 'light'},
      deleted: false,
      version: const SyncVersion(wall: 40, logical: 0, device: 'server'),
      uncertain: false,
      baseVersion: oldRemote.version,
    );
    await store.addConflict(local, oldRemote);
    server.onSync = (body) async => {
      ...server.responseFor(body),
      'records': [newest.toJson()],
    };

    await service.syncNow();

    expect(await store.conflicts(), isEmpty);
    expect(
      (await database.configDao.getConfigByKey('ReaderTheme'))?.value,
      'light',
    );
  });

  test('disabled credentials never import server conflict payloads', () async {
    final local = SyncRecord(
      category: SyncCategory.credentials,
      key: 'accounts',
      value: const {'cookies': <Object>[], 'configs': <Object>[]},
      deleted: false,
      version: const SyncVersion(wall: 20, logical: 0, device: 'local'),
      uncertain: true,
    );
    final remote = SyncRecord(
      category: SyncCategory.credentials,
      key: 'accounts',
      value: const {'cookies': <Object>[], 'configs': <Object>[]},
      deleted: false,
      version: const SyncVersion(wall: 21, logical: 0, device: 'remote'),
      uncertain: true,
    );
    server.conflicts.add({
      'id': 'server-conflict',
      'local': local.toJson(),
      'remote': remote.toJson(),
    });

    await _loginAndEnable(service, server.url);
    await _waitFor(() => service.lastSuccess != null);
    await _waitFor(() => !service.busy);

    expect(service.categories, isNot(contains(SyncCategory.credentials)));
    expect(service.conflicts, isEmpty);
    expect(await store.conflicts(), isEmpty);
  });

  test('migrating between saved accounts resets only the replaced cursor',
      () async {
    server.userId = 'user-1';
    await _loginAndEnable(service, server.url);
    await _waitFor(() => service.lastSuccess != null);
    await _waitFor(() => !service.busy);

    server.userId = 'user-2';
    await service.login(
      serverUrl: server.url,
      username: 'bob',
      password: 'correct-password',
      migrateLocal: false,
    );

    server.userId = 'user-1';
    var requestsBeforeLogin = server.syncBodies.length;
    await service.login(
      serverUrl: server.url,
      username: 'alice',
      password: 'correct-password',
      migrateLocal: true,
    );
    await _waitFor(() => server.syncBodies.length > requestsBeforeLogin);
    expect(server.syncBodies[requestsBeforeLogin]['cursor'], 0);
    await _waitFor(() => !service.busy);

    requestsBeforeLogin = server.syncBodies.length;
    await service.login(
      serverUrl: server.url,
      username: 'alice',
      password: 'correct-password',
      migrateLocal: true,
    );
    await _waitFor(() => server.syncBodies.length > requestsBeforeLogin);
    expect(server.syncBodies[requestsBeforeLogin]['cursor'], isNot(0));
  });

  test('adding the first category restarts live event transport', () async {
    await _loginAndEnable(service, server.url);
    await _waitFor(() => server.eventRequests > 0);

    for (final category in SyncCategory.values.toList()) {
      if (service.categories.contains(category)) {
        await service.setCategory(category, false);
      }
    }
    expect(service.categories, isEmpty);
    final requestsWhileEmpty = server.eventRequests;

    await service.setCategory(SyncCategory.settings, true);
    await _waitFor(() => server.eventRequests > requestsWhileEmpty);
  });
}

Future<void> _loginAndEnable(DatabaseSyncService service, String serverUrl) async {
  await service.login(
    serverUrl: serverUrl,
    username: 'alice',
    password: 'correct-password',
    migrateLocal: false,
  );
  expect(service.error, isNull);
  await service.setEnabled(true);
}

Future<void> _waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for condition');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _SyncServer {
  final HttpServer _server;
  final List<Map<String, dynamic>> syncBodies = [];
  final List<Map<String, dynamic>> conflicts = [];
  final Map<String, String> deviceNames = {};
  bool rejectLogin = false;
  int syncStatusCode = HttpStatus.ok;
  String userId = 'user-1';
  int eventRequests = 0;
  int nextCursor = 1;
  Future<Map<String, dynamic>> Function(Map<String, dynamic>)? onSync;

  _SyncServer._(this._server);

  static Future<_SyncServer> start() async {
    final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final server = _SyncServer._(http);
    http.listen(server._handle);
    return server;
  }

  String get url => 'http://${_server.address.address}:${_server.port}';

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    request.response.headers.contentType = ContentType.json;
    switch (request.uri.path) {
      case '/api/v1/time':
        _json(request, {'serverTime': DateTime.now().millisecondsSinceEpoch});
        return;
      case '/api/v1/login':
        final body = await _body(request);
        if (rejectLogin) {
          request.response.statusCode = HttpStatus.unauthorized;
          _json(request, {'error': 'secret server detail'});
          return;
        }
        _json(request, {
          'token': 'opaque-test-token',
          'userId': userId,
          'username': body['username'],
          'serverTime': DateTime.now().millisecondsSinceEpoch,
        });
        return;
      case '/api/v1/sync':
        final body = await _body(request);
        syncBodies.add(body);
        final handler = onSync;
        final response =
            handler == null ? responseFor(body) : await handler(body);
        request.response.statusCode = syncStatusCode;
        _json(request, response);
        return;
      case '/api/v1/events':
        eventRequests++;
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
        return;
      case '/api/v1/conflicts':
        _json(request, {'conflicts': conflicts, 'devices': deviceNames});
        return;
      case '/api/v1/logout':
      case '/api/v1/password':
        _json(request, <String, Object>{});
        return;
      default:
        request.response.statusCode = HttpStatus.notFound;
        _json(request, {'error': 'not found'});
        return;
    }
  }

  Map<String, dynamic> responseFor(
    Map<String, dynamic> request, {
    int? cursor,
  }) {
    final changes = (request['changes'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    return {
      'cursor': cursor ?? nextCursor++,
      'hasMore': false,
      'records': <Object>[],
      'results': [
        for (final record in changes)
          {
            'category': record['category'],
            'key': record['key'],
            'status': 'accepted',
            'record': record,
          },
      ],
      'serverTime': DateTime.now().millisecondsSinceEpoch,
    };
  }

  static Future<Map<String, dynamic>> _body(HttpRequest request) async {
    final text = await utf8.decoder.bind(request).join();
    return (jsonDecode(text) as Map<dynamic, dynamic>).cast<String, dynamic>();
  }

  static void _json(HttpRequest request, Map<String, dynamic> value) {
    request.response.write(jsonEncode(value));
    request.response.close();
  }
}
