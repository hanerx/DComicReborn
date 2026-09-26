import 'package:flutter/services.dart';

class NetworkDnsConfiguration {
  const NetworkDnsConfiguration({
    required this.servers,
    this.privateDnsActive,
    this.privateDnsServerName,
  });

  final List<String> servers;
  final bool? privateDnsActive;
  final String? privateDnsServerName;
}

const _channel = MethodChannel('dcomic/network_diagnostics');

/// Reads the active network's configuration, without overriding its resolver.
Future<NetworkDnsConfiguration> readNetworkDnsConfiguration() async {
  final data = await _channel.invokeMapMethod<String, dynamic>(
    'getDnsConfiguration',
  );
  if (data == null) throw StateError('DNS configuration unavailable');
  return NetworkDnsConfiguration(
    servers: List<String>.from(data['servers'] as List),
    privateDnsActive: data['privateDnsActive'] as bool?,
    privateDnsServerName: data['privateDnsServerName'] as String?,
  );
}
