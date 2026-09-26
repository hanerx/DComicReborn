import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dcomic/providers/network_diagnostics_controller.dart';
import 'package:dcomic/utils/network_dns.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DNS configuration is reported before slow external checks', () async {
    final requested = Completer<void>();
    final release = Completer<void>();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      requested.complete();
      await release.future;
      request.response.write('203.0.113.7');
      await request.response.close();
    });
    final controller = _controller(
      publicIpUri: _uri(server, '/public-ip'),
      dnsConfigurationReader: () async => const NetworkDnsConfiguration(
        servers: ['192.168.1.1', '2001:db8::53'],
        privateDnsActive: true,
        privateDnsServerName: 'dns.example.net',
      ),
    );
    addTearDown(controller.dispose);

    final run = controller.start();
    await requested.future.timeout(const Duration(seconds: 2));
    expect(controller.isRunning, isTrue);
    expect(controller.report, contains('192.168.1.1'));
    expect(controller.report, contains('2001:db8::53'));
    expect(controller.report, contains('Private DNS: active'));
    expect(controller.report, contains('dns.example.net'));
    release.complete();
    await run;
    expect(controller.report, contains('203.0.113.7'));
  });

  test(
    'unavailable DNS does not invent servers or prevent later checks',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response.write('203.0.113.8');
        await request.response.close();
      });
      final controller = _controller(
        publicIpUri: _uri(server, '/public-ip'),
        dnsConfigurationReader: () async =>
            throw StateError('private native details'),
      );
      addTearDown(controller.dispose);

      await controller.start();
      expect(controller.report, contains('DNS: check failed'));
      expect(controller.report, isNot(contains('private native details')));
      expect(controller.report, isNot(contains('8.8.8.8')));
      expect(controller.report, contains('203.0.113.8'));
      expect(controller.isRunning, isFalse);
    },
  );

  test('publishes progress before a delayed HTTP response arrives', () async {
    final requestReceived = Completer<void>();
    final releaseResponse = Completer<void>();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      if (request.uri.path == '/public-ip') {
        request.response.write('203.0.113.7');
        await request.response.close();
        return;
      }
      requestReceived.complete();
      await releaseResponse.future;
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
    });

    final controller = _controller(
      publicIpUri: _uri(server, '/public-ip'),
      readAccountStatus: () async => const ['Source account: signed in'],
      targets: [
        NetworkDiagnosticTarget(
          label: 'Delayed source',
          uri: _uri(server, '/delayed'),
        ),
      ],
    );
    addTearDown(controller.dispose);
    final snapshots = <String>[];
    controller.addListener(() => snapshots.add(controller.report));

    final run = controller.start();
    await requestReceived.future.timeout(const Duration(seconds: 2));

    expect(controller.isRunning, isTrue);
    expect(
      controller.report,
      contains('Public IP (api64.ipify.org): 203.0.113.7'),
    );
    expect(controller.report, contains('Source account: signed in'));
    expect(controller.report, contains('Running: HTTP Delayed source'));
    expect(controller.report, isNot(contains('Delayed source: HTTP 204')));

    releaseResponse.complete();
    await run;

    expect(controller.isRunning, isFalse);
    expect(controller.report, contains('Delayed source: HTTP 204'));
    expect(controller.report, contains('Completed:'));
    expect(
      snapshots.any(
        (snapshot) => snapshot.contains('Running: HTTP Delayed source'),
      ),
      isTrue,
    );
  });

  test('reports HTTP errors without following redirects and distinguishes transport failures', () async {
    var redirectedRequests = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      if (request.uri.path == '/public-ip') {
        request.response.write('2001:db8::7');
      } else if (request.uri.path == '/redirect') {
        request.response.statusCode = HttpStatus.found;
        request.response.headers.set(
          HttpHeaders.locationHeader,
          '/redirected-secret',
        );
      } else if (request.uri.path == '/redirected-secret') {
        redirectedRequests++;
      } else {
        request.response.statusCode = HttpStatus.serviceUnavailable;
        request.response.write('private server detail');
      }
      await request.response.close();
    });
    final unavailable = await _unusedLoopbackUri();

    final controller = _controller(
      publicIpUri: _uri(server, '/public-ip'),
      targets: [
        NetworkDiagnosticTarget(
          label: 'Responding source',
          uri: _uri(server, '/unavailable'),
        ),
        NetworkDiagnosticTarget(
          label: 'Redirecting source',
          uri: _uri(server, '/redirect'),
        ),
        NetworkDiagnosticTarget(label: 'Offline source', uri: unavailable),
      ],
    );
    addTearDown(controller.dispose);

    await controller.start();

    expect(
      controller.report,
      matches(RegExp(r'Responding source: HTTP 503 \(\d+ ms\)')),
    );
    expect(controller.report, contains('Offline source: connection error'));
    expect(
      controller.report,
      matches(
        RegExp(
          r'Offline source: connection error \(\d+ ms\) \['
          '${RegExp.escape(unavailable.toString())}'
          r'\]',
        ),
      ),
    );
    expect(controller.report, contains('Redirecting source: HTTP 302'));
    expect(redirectedRequests, 0);
    expect(controller.report, isNot(contains('private server detail')));
  });

  test(
    'dispose cancels the active request and does not schedule later targets',
    () async {
      final firstRequest = Completer<void>();
      final releaseFirst = Completer<void>();
      var laterRequests = 0;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        if (request.uri.path == '/public-ip') {
          request.response.write('198.51.100.4');
          await request.response.close();
          return;
        }
        if (request.uri.path == '/first') {
          firstRequest.complete();
          await releaseFirst.future;
        } else {
          laterRequests++;
        }
        try {
          await request.response.close();
        } on HttpException {
          // The client deliberately aborts this response when disposed.
        } on SocketException {
          // The platform may surface the same abort as a socket error.
        }
      });

      final controller = _controller(
        publicIpUri: _uri(server, '/public-ip'),
        targets: [
          NetworkDiagnosticTarget(label: 'First', uri: _uri(server, '/first')),
          NetworkDiagnosticTarget(label: 'Later', uri: _uri(server, '/later')),
        ],
      );
      var notifications = 0;
      controller.addListener(() => notifications++);

      final run = controller.start();
      await firstRequest.future.timeout(const Duration(seconds: 2));
      controller.dispose();
      final notificationsAtDispose = notifications;
      releaseFirst.complete();
      await run.timeout(const Duration(seconds: 2));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(laterRequests, 0);
      expect(notifications, notificationsAtDispose);
      expect(controller.isRunning, isFalse);
    },
  );

  test(
    'report omits URL credentials, query values, headers, and response body',
    () async {
      const bodySecret = 'body-secret-721';
      const headerSecret = 'header-secret-905';
      String? receivedAuthorization;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        if (request.uri.path == '/public-ip') {
          request.response.write('192.0.2.8');
        } else {
          receivedAuthorization = request.headers.value(
            HttpHeaders.authorizationHeader,
          );
          request.response.statusCode = 418;
          request.response.headers.set('x-private-detail', headerSecret);
          request.response.write(bodySecret);
        }
        await request.response.close();
      });
      final credentialedUri = Uri(
        scheme: 'http',
        userInfo: 'alice:password-314',
        host: InternetAddress.loopbackIPv4.address,
        port: server.port,
        path: '/source',
        queryParameters: const {'token': 'query-secret-159'},
      );
      final controller = _controller(
        publicIpUri: _uri(server, '/public-ip'),
        targets: [
          NetworkDiagnosticTarget(label: 'Safe label', uri: credentialedUri),
        ],
      );
      addTearDown(controller.dispose);

      await controller.start();

      expect(controller.report, contains('Safe label: HTTP 418'));
      expect(controller.report, contains('http://127.0.0.1:${server.port}'));
      expect(controller.report, isNot(contains('alice')));
      expect(controller.report, isNot(contains('password-314')));
      expect(controller.report, isNot(contains('query-secret-159')));
      expect(controller.report, isNot(contains(bodySecret)));
      expect(controller.report, isNot(contains(headerSecret)));
      expect(receivedAuthorization, isNull);
    },
  );

  test(
    'malformed public IP is reported safely and account checks still run',
    () async {
      const malformedBody = 'not-an-ip private-response-content';
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response.write(malformedBody);
        await request.response.close();
      });
      var accountReads = 0;
      final controller = _controller(
        publicIpUri: _uri(server, '/public-ip'),
        readAccountStatus: () async {
          accountReads++;
          return const ['Example source: signed in'];
        },
      );
      addTearDown(controller.dispose);

      await controller.start();

      expect(
        controller.report,
        contains('Public IP (api64.ipify.org): malformed response'),
      );
      expect(controller.report, isNot(contains(malformedBody)));
      expect(controller.report, contains('Example source: signed in'));
      expect(accountReads, 1);
    },
  );

  test('failed early checks do not prevent later HTTP diagnostics', () async {
    var targetRequests = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      if (request.uri.path == '/public-ip') {
        request.response.write('198.51.100.11');
      } else {
        targetRequests++;
        request.response.statusCode = HttpStatus.ok;
      }
      await request.response.close();
    });
    final controller = _controller(
      publicIpUri: _uri(server, '/public-ip'),
      networkTypesReader: () async => throw const SocketException('offline'),
      readAccountStatus: () async => throw StateError('database detail'),
      targets: [
        NetworkDiagnosticTarget(
          label: 'Later source',
          uri: _uri(server, '/source'),
        ),
      ],
    );
    addTearDown(controller.dispose);

    await controller.start();

    expect(controller.report, contains('Network types: DNS resolution error'));
    expect(controller.report, contains('Account status: check failed'));
    expect(
      controller.report,
      contains('Public IP (api64.ipify.org): 198.51.100.11'),
    );
    expect(controller.report, contains('Later source: HTTP 200'));
    expect(controller.report, isNot(contains('database detail')));
    expect(targetRequests, 1);
  });

  test('start is idempotent while running and after completion', () async {
    var accountReads = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.write('203.0.113.9');
      await request.response.close();
    });
    final controller = _controller(
      publicIpUri: _uri(server, '/public-ip'),
      readAccountStatus: () async {
        accountReads++;
        return const ['Source: signed out'];
      },
    );
    addTearDown(controller.dispose);

    final firstRun = controller.start();
    final secondRun = controller.start();
    await Future.wait([firstRun, secondRun]);
    final firstReport = controller.report;
    await controller.start();

    expect(accountReads, 1);
    expect(controller.report, firstReport);
  });
}

NetworkDiagnosticsController _controller({
  required Uri publicIpUri,
  List<NetworkDiagnosticTarget> targets = const [],
  Future<List<String>> Function()? readAccountStatus,
  Future<List<ConnectivityResult>> Function()? networkTypesReader,
  Future<NetworkDnsConfiguration> Function()? dnsConfigurationReader,
}) {
  return NetworkDiagnosticsController(
    targets: targets,
    readAccountStatus: readAccountStatus ?? () async => const [],
    chinese: false,
    networkTypesReader:
        networkTypesReader ?? () async => const [ConnectivityResult.wifi],
    networkInterfacesReader: () async => const <NetworkInterface>[],
    dnsConfigurationReader:
        dnsConfigurationReader ??
        () async => const NetworkDnsConfiguration(servers: []),
    publicIpUri: publicIpUri,
    stepTimeout: const Duration(seconds: 3),
    now: () => DateTime.utc(2026, 9, 27, 12, 34, 56),
  );
}

Uri _uri(HttpServer server, String path) => Uri(
  scheme: 'http',
  host: InternetAddress.loopbackIPv4.address,
  port: server.port,
  path: path,
);

Future<Uri> _unusedLoopbackUri() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final port = server.port;
  await server.close(force: true);
  return Uri(
    scheme: 'http',
    host: InternetAddress.loopbackIPv4.address,
    port: port,
  );
}
