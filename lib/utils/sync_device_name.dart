import 'dart:io';

import 'package:flutter/services.dart';

const _deviceInfoChannel = MethodChannel('dcomic/device_info');

Future<String> readSyncDeviceName() async {
  final platform = Platform.operatingSystem;
  if (Platform.isAndroid || Platform.isIOS) {
    Map<String, dynamic>? info;
    try {
      info = await _deviceInfoChannel.invokeMapMethod<String, dynamic>(
        'getDeviceInfo',
      );
    } on PlatformException {
      // A restricted device can still be identified by its sync device ID.
    } on MissingPluginException {
      // The platform name remains honest when native information is unavailable.
    }
    return selectSyncDeviceName(
      platform: platform,
      name: info?['name'] as String?,
      model: info?['model'] as String?,
    );
  }
  String? hostname;
  try {
    hostname = Platform.localHostname;
  } on OSError {
    // Keep the stable device ID as the discriminator when hostname lookup fails.
  }
  return selectSyncDeviceName(platform: platform, hostname: hostname);
}

String selectSyncDeviceName({
  required String platform,
  String? name,
  String? model,
  String? hostname,
}) {
  final mobile = platform == 'android' || platform == 'ios';
  final candidates = mobile ? [name, model] : [name, hostname, model];
  for (final candidate in candidates) {
    final value = candidate?.trim();
    if (value == null || value.isEmpty) continue;
    if (const {
      'localhost',
      'localhost.localdomain',
      'localhost6',
      'localhost6.localdomain6',
      '127.0.0.1',
      '::1',
      'unknown',
    }.contains(value.toLowerCase())) {
      continue;
    }
    // The server's limit is UTF-8 bytes, not UTF-16 code units.
    var bytes = 0;
    var end = 0;
    for (final rune in value.runes) {
      final width = rune <= 0x7f ? 1 : rune <= 0x7ff ? 2 : rune <= 0xffff ? 3 : 4;
      if (bytes + width > 128) break;
      bytes += width;
      end += rune <= 0xffff ? 1 : 2;
    }
    return value.substring(0, end);
  }
  return '$platform device';
}
