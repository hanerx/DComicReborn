import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dcomic/utils/network_dns.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NetworkDiagnosticTarget {
  final String label;
  final Uri uri;

  const NetworkDiagnosticTarget({required this.label, required this.uri});
}

class _DiagnosticCancelled implements Exception {
  const _DiagnosticCancelled();
}

class NetworkDiagnosticsController extends ChangeNotifier {
  static const _defaultPublicIpUri = 'https://api64.ipify.org';
  static const _maximumPublicIpBodyBytes = 64;

  final List<NetworkDiagnosticTarget> _targets;
  final Future<List<String>> Function() _readAccountStatus;
  final bool chinese;
  final Future<List<ConnectivityResult>> Function() _networkTypesReader;
  final Future<List<NetworkInterface>> Function() _networkInterfacesReader;
  final Future<NetworkDnsConfiguration> Function() _dnsConfigurationReader;
  final Uri _publicIpUri;
  final Duration _stepTimeout;
  final DateTime Function() _now;
  final Dio _dio;
  final bool _ownsDio;

  final List<String> _lines = [];
  CancelToken? _activeCancelToken;
  StreamSubscription<Uint8List>? _activeStreamSubscription;
  Completer<List<int>>? _activeBodyCompleter;
  Future<void>? _run;
  String? _runningStep;
  bool _started = false;
  bool _isRunning = false;
  bool _disposed = false;
  bool _dioClosed = false;

  NetworkDiagnosticsController({
    required List<NetworkDiagnosticTarget> targets,
    required this._readAccountStatus,
    required this.chinese,
    Future<List<ConnectivityResult>> Function()? networkTypesReader,
    Future<List<NetworkInterface>> Function()? networkInterfacesReader,
    Future<NetworkDnsConfiguration> Function()? dnsConfigurationReader,
    Dio? dio,
    Uri? publicIpUri,
    Duration stepTimeout = const Duration(seconds: 8),
    DateTime Function()? now,
  }) : assert(stepTimeout > Duration.zero),
       _targets = List.unmodifiable(targets),
       _networkTypesReader =
           networkTypesReader ?? Connectivity().checkConnectivity,
       _networkInterfacesReader =
           networkInterfacesReader ??
           (() => NetworkInterface.list(
             includeLoopback: false,
             includeLinkLocal: true,
             type: InternetAddressType.any,
           )),
       _dnsConfigurationReader =
           dnsConfigurationReader ?? readNetworkDnsConfiguration,
       _publicIpUri =
           publicIpUri ??
           Uri.parse(NetworkDiagnosticsController._defaultPublicIpUri),
       _stepTimeout = stepTimeout,
       _now = now ?? DateTime.now,
       _dio = dio ?? Dio(),
       _ownsDio = dio == null;

  String get report {
    final result = List<String>.of(_lines);
    if (_runningStep != null) {
      result.add('${_text('正在进行', 'Running')}: $_runningStep');
    }
    return result.join('\n');
  }

  bool get isRunning => _isRunning;

  Future<void> start() {
    if (_started || _disposed) {
      return _run ?? Future<void>.value();
    }
    _started = true;
    _isRunning = true;
    final startedAt = _now();
    _lines.addAll([
      _text('网络诊断', 'Network diagnostics'),
      '${_text('开始时间', 'Started')}: ${startedAt.toIso8601String()}',
      _text(
        '隐私提示：报告包含网络地址和服务状态，但不包含凭据或原始服务器响应内容。',
        'Privacy: This report contains network addresses and service status, but no credentials or raw server response contents.',
      ),
      _text(
        '说明：HTTP 状态码表示服务器已响应（包括非 2xx）；传输错误表示未收到 HTTP 响应。',
        'Interpretation: An HTTP status means the server replied (including non-2xx); a transport error means no HTTP response was received.',
      ),
      '',
      _text('[网络]', '[Network]'),
    ]);
    _notify();
    final run = _runDiagnostics();
    _run = run;
    return run;
  }

  Future<void> _runDiagnostics() async {
    try {
      await _runStep(
        _text('网络类型', 'Network type'),
        _readNetworkTypes,
        _text('网络类型', 'Network types'),
      );
      await _runStep(
        _text('本地 IP', 'Local IP'),
        _readLocalAddresses,
        _text('本地 IP', 'Local IP'),
      );
      await _runStep('DNS', _readDnsConfiguration, 'DNS');
      if (!_canContinue) {
        return;
      }

      _lines.add('');
      _lines.add(_text('[账号]', '[Accounts]'));
      _notify();
      await _runStep(
        _text('账号状态', 'Account status'),
        _readAccounts,
        _text('账号状态', 'Account status'),
      );

      if (!_canContinue) {
        return;
      }
      _lines.add('');
      _lines.add(_text('[公网]', '[Internet]'));
      _notify();
      await _runStep(
        _text('公网 IP', 'Public IP'),
        _readPublicIp,
        _text('公网 IP（api64.ipify.org）', 'Public IP (api64.ipify.org)'),
        hasOwnTimeout: true,
      );

      if (!_canContinue) {
        return;
      }
      _lines.add('');
      _lines.add(_text('[HTTP 服务]', '[HTTP services]'));
      _notify();
      for (final target in _targets) {
        if (!_canContinue) {
          return;
        }
        final label = _safeSingleLine(target.label);
        await _runStep(
          '${_text('HTTP', 'HTTP')} $label [${_safeEndpoint(target.uri)}]',
          () => _probeTarget(target),
          label,
          hasOwnTimeout: true,
        );
      }
    } finally {
      _isRunning = false;
      if (!_disposed) {
        _runningStep = null;
        _lines.add('');
        _lines.add('${_text('已完成', 'Completed')}: ${_now().toIso8601String()}');
        _notify();
      }
      _closeOwnedDio();
    }
  }

  Future<void> _runStep(
    String runningLabel,
    Future<List<String>> Function() action,
    String failureLabel, {
    bool hasOwnTimeout = false,
  }) async {
    if (!_canContinue) {
      return;
    }
    _runningStep = runningLabel;
    _notify();
    if (!_canContinue) {
      return;
    }
    try {
      final result = hasOwnTimeout
          ? await action()
          : await action().timeout(_stepTimeout);
      if (!_canContinue) {
        return;
      }
      _lines.addAll(result);
    } catch (error) {
      if (!_canContinue) {
        return;
      }
      _lines.add('$failureLabel: ${_errorCategory(error)}');
    } finally {
      if (!_disposed) {
        _runningStep = null;
        _notify();
      }
    }
  }

  Future<List<String>> _readNetworkTypes() async {
    final results = await _networkTypesReader();
    final names = results.map(_connectivityName).toSet().toList();
    if (names.isEmpty) {
      names.add(_text('无', 'None'));
    }
    return ['${_text('网络类型', 'Network types')}: ${names.join(', ')}'];
  }

  Future<List<String>> _readLocalAddresses() async {
    final interfaces = await _networkInterfacesReader();
    final result = <String>[];
    final seen = <String>{};
    for (final interface in interfaces) {
      final interfaceName = _safeSingleLine(interface.name);
      for (final address in interface.addresses) {
        if (address.isLoopback) {
          continue;
        }
        final family = address.type == InternetAddressType.IPv6
            ? 'IPv6'
            : 'IPv4';
        final line =
            '${_text('本地 IP', 'Local IP')}: $interfaceName ($family) ${address.address}';
        if (seen.add(line)) {
          result.add(line);
        }
      }
    }
    if (result.isEmpty) {
      result.add(
        '${_text('本地 IP', 'Local IP')}: ${_text('未发现', 'none found')}',
      );
    }
    return result;
  }

  Future<List<String>> _readDnsConfiguration() async {
    final NetworkDnsConfiguration configuration;
    try {
      configuration = await _dnsConfigurationReader();
    } on MissingPluginException {
      return [
        'DNS: ${_text('当前平台未提供系统 DNS 读取接口', 'system DNS lookup is not supported on this platform')}',
      ];
    } on PlatformException catch (error) {
      if (error.code != 'NO_ACTIVE_NETWORK') rethrow;
      return ['DNS: ${_text('无活动网络', 'no active network')}'];
    }
    final servers = configuration.servers.toSet();
    final lines = [
      if (servers.isEmpty)
        'DNS: ${_text('系统未提供服务器地址', 'no server addresses supplied by the system')}'
      else
        'DNS (${_text('当前网络配置', 'active network configuration')}): ${servers.join(', ')}',
    ];
    final privateDnsActive = configuration.privateDnsActive;
    if (privateDnsActive != null) {
      final state = privateDnsActive
          ? _text('已启用', 'active')
          : _text('未启用', 'inactive');
      lines.add('${_text('私人 DNS', 'Private DNS')}: $state');
    }
    final privateDnsHost = configuration.privateDnsServerName;
    if (privateDnsHost != null && privateDnsHost.isNotEmpty) {
      lines.add(
        '${_text('私人 DNS 配置主机', 'Private DNS configured host')}: ${_safeSingleLine(privateDnsHost)}',
      );
    }
    return lines;
  }

  Future<List<String>> _readAccounts() async {
    final lines = await _readAccountStatus();
    if (lines.isEmpty) {
      return [
        '${_text('账号状态', 'Account status')}: ${_text('无来源', 'no sources')}',
      ];
    }
    return lines.map(_safeSingleLine).toList(growable: false);
  }

  Future<List<String>> _readPublicIp() async {
    final stopwatch = Stopwatch()..start();
    final token = CancelToken();
    _activeCancelToken = token;
    try {
      final response = await _getStreamResponse(
        _requestUri(_publicIpUri),
        token,
        stopwatch,
      );
      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        await _cancelBody(response.data, token, stopwatch);
        return [
          '${_text('公网 IP（api64.ipify.org）', 'Public IP (api64.ipify.org)')}: HTTP ${response.statusCode ?? _text('未知', 'unknown')}',
        ];
      }
      final body = response.data;
      if (body == null) {
        return [
          '${_text('公网 IP（api64.ipify.org）', 'Public IP (api64.ipify.org)')}: ${_text('响应格式无效', 'malformed response')}',
        ];
      }
      final bytes = await _readLimitedBody(body, token, stopwatch);
      if (bytes.length > _maximumPublicIpBodyBytes) {
        return [
          '${_text('公网 IP（api64.ipify.org）', 'Public IP (api64.ipify.org)')}: ${_text('响应格式无效', 'malformed response')}',
        ];
      }
      final value = ascii.decode(bytes, allowInvalid: true).trim();
      final address = InternetAddress.tryParse(value);
      return [
        '${_text('公网 IP（api64.ipify.org）', 'Public IP (api64.ipify.org)')}: ${address?.address ?? _text('响应格式无效', 'malformed response')}',
      ];
    } finally {
      if (identical(_activeCancelToken, token)) {
        _activeCancelToken = null;
      }
    }
  }

  Future<List<String>> _probeTarget(NetworkDiagnosticTarget target) async {
    final label = _safeSingleLine(target.label);
    final endpoint = _safeEndpoint(target.uri);
    if (target.uri.host.isEmpty ||
        (target.uri.scheme != 'http' && target.uri.scheme != 'https')) {
      return ['$label: ${_text('目标无效', 'invalid target')} [$endpoint]'];
    }
    final stopwatch = Stopwatch()..start();
    final token = CancelToken();
    _activeCancelToken = token;
    try {
      final response = await _getStreamResponse(
        _requestUri(target.uri),
        token,
        stopwatch,
      );
      await _cancelBody(response.data, token, stopwatch);
      final elapsed = stopwatch.elapsedMilliseconds;
      return [
        '$label: HTTP ${response.statusCode ?? _text('未知', 'unknown')} ($elapsed ms) [$endpoint]',
      ];
    } catch (error) {
      return [
        '$label: ${_errorCategory(error)} (${stopwatch.elapsedMilliseconds} ms) [$endpoint]',
      ];
    } finally {
      if (identical(_activeCancelToken, token)) {
        _activeCancelToken = null;
      }
    }
  }

  Future<Response<ResponseBody>> _getStreamResponse(
    Uri uri,
    CancelToken token,
    Stopwatch stopwatch,
  ) {
    final remaining = _remaining(stopwatch);
    return _dio
        .getUri<ResponseBody>(
          uri,
          cancelToken: token,
          options: Options(
            responseType: ResponseType.stream,
            followRedirects: false,
            sendTimeout: remaining,
            receiveTimeout: remaining,
            validateStatus: (_) => true,
          ),
        )
        .timeout(
          remaining,
          onTimeout: () {
            token.cancel('diagnostic step timed out');
            throw TimeoutException('diagnostic step timed out');
          },
        );
  }

  Future<List<int>> _readLimitedBody(
    ResponseBody body,
    CancelToken token,
    Stopwatch stopwatch,
  ) async {
    final remainingTime = _remaining(stopwatch);
    final completer = Completer<List<int>>();
    final bytes = <int>[];
    StreamSubscription<Uint8List>? subscription;
    late final Timer timer;

    void complete() {
      if (!completer.isCompleted) {
        completer.complete(bytes);
      }
    }

    subscription = body.stream.listen(
      (chunk) {
        final remaining = _maximumPublicIpBodyBytes + 1 - bytes.length;
        if (remaining > 0) {
          bytes.addAll(chunk.take(remaining));
        }
        if (bytes.length > _maximumPublicIpBodyBytes) {
          complete();
          token.cancel('diagnostic public IP response too large');
          unawaited(subscription?.cancel());
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
      onDone: complete,
      cancelOnError: true,
    );
    _activeStreamSubscription = subscription;
    _activeBodyCompleter = completer;
    timer = Timer(remainingTime, () {
      token.cancel('diagnostic step timed out');
      unawaited(subscription?.cancel());
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('diagnostic step timed out'));
      }
    });
    try {
      return await completer.future;
    } finally {
      timer.cancel();
      await subscription.cancel();
      if (identical(_activeStreamSubscription, subscription)) {
        _activeStreamSubscription = null;
      }
      if (identical(_activeBodyCompleter, completer)) {
        _activeBodyCompleter = null;
      }
    }
  }

  Future<void> _cancelBody(
    ResponseBody? body,
    CancelToken token,
    Stopwatch stopwatch,
  ) async {
    if (body == null) {
      return;
    }
    late final Duration remaining;
    try {
      remaining = _remaining(stopwatch);
    } on TimeoutException {
      token.cancel('diagnostic response cancellation timed out');
      return;
    }
    final subscription = body.stream.listen((_) {}, onError: (_) {});
    _activeStreamSubscription = subscription;
    token.cancel('diagnostic response body not required');
    final cancellation = subscription.cancel();
    try {
      await cancellation.timeout(
        remaining,
        onTimeout: () {
          token.cancel('diagnostic response cancellation timed out');
        },
      );
    } on TimeoutException {
      token.cancel('diagnostic response cancellation timed out');
    } catch (_) {
      token.cancel('diagnostic response cancellation failed');
    } finally {
      if (identical(_activeStreamSubscription, subscription)) {
        _activeStreamSubscription = null;
      }
    }
  }

  Duration _remaining(Stopwatch stopwatch) {
    final remaining = _stepTimeout - stopwatch.elapsed;
    if (remaining <= Duration.zero) {
      throw TimeoutException('diagnostic step timed out');
    }
    return remaining;
  }

  String _connectivityName(ConnectivityResult result) {
    return switch (result) {
      ConnectivityResult.bluetooth => _text('蓝牙', 'Bluetooth'),
      ConnectivityResult.wifi => 'Wi-Fi',
      ConnectivityResult.ethernet => _text('以太网', 'Ethernet'),
      ConnectivityResult.mobile => _text('移动网络', 'Mobile'),
      ConnectivityResult.none => _text('无', 'None'),
      ConnectivityResult.vpn => 'VPN',
      ConnectivityResult.satellite => _text('卫星网络', 'Satellite'),
      ConnectivityResult.other => _text('其他', 'Other'),
    };
  }

  String _errorCategory(Object error) {
    if (error is TimeoutException) {
      return _text('超时', 'timeout');
    }
    if (error is _DiagnosticCancelled) {
      return _text('已取消', 'cancelled');
    }
    if (error is HandshakeException || error is TlsException) {
      return _text('TLS/证书错误', 'TLS/certificate error');
    }
    if (error is SocketException) {
      return error.address == null
          ? _text('DNS 解析错误', 'DNS resolution error')
          : _text('连接错误', 'connection error');
    }
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.transformTimeout:
          return _text('超时', 'timeout');
        case DioExceptionType.badCertificate:
          return _text('TLS/证书错误', 'TLS/certificate error');
        case DioExceptionType.connectionError:
          final cause = error.error;
          if (cause is HandshakeException || cause is TlsException) {
            return _text('TLS/证书错误', 'TLS/certificate error');
          }
          if (cause is SocketException && cause.address == null) {
            return _text('DNS 解析错误', 'DNS resolution error');
          }
          return _text('连接错误', 'connection error');
        case DioExceptionType.cancel:
          return _text('已取消', 'cancelled');
        case DioExceptionType.badResponse:
        case DioExceptionType.unknown:
          final cause = error.error;
          if (cause is HandshakeException || cause is TlsException) {
            return _text('TLS/证书错误', 'TLS/certificate error');
          }
          if (cause is SocketException) {
            return cause.address == null
                ? _text('DNS 解析错误', 'DNS resolution error')
                : _text('连接错误', 'connection error');
          }
          return _text('传输错误', 'transport error');
      }
    }
    return _text('检查失败', 'check failed');
  }

  Uri _requestUri(Uri uri) => uri.replace(userInfo: '', fragment: '');

  String _safeEndpoint(Uri uri) {
    if (uri.host.isEmpty || uri.scheme.isEmpty) {
      return _text('无效目标', 'invalid target');
    }
    try {
      return Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
      ).toString();
    } on FormatException {
      return _text('无效目标', 'invalid target');
    }
  }

  String _safeSingleLine(String value) =>
      value.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();

  String _text(String zh, String en) => chinese ? zh : en;

  bool get _canContinue => !_disposed;

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _closeOwnedDio() {
    if (_ownsDio && !_dioClosed) {
      _dioClosed = true;
      _dio.close(force: true);
    }
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _isRunning = false;
    _activeCancelToken?.cancel('network diagnostics disposed');
    final bodyCompleter = _activeBodyCompleter;
    if (bodyCompleter != null && !bodyCompleter.isCompleted) {
      bodyCompleter.completeError(const _DiagnosticCancelled());
    }
    unawaited(_activeStreamSubscription?.cancel());
    _closeOwnedDio();
    super.dispose();
  }
}
