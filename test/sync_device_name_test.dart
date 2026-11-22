import 'dart:convert';

import 'package:dcomic/utils/sync_device_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile device name takes precedence over localhost', () {
    expect(
      selectSyncDeviceName(
        platform: 'android',
        name: '我的 Pixel',
        model: 'Google Pixel 9',
        hostname: 'localhost',
      ),
      '我的 Pixel',
    );
  });

  test('mobile falls back to its model, never the network hostname', () {
    expect(
      selectSyncDeviceName(
        platform: 'android',
        name: ' LOCALHOST ',
        model: 'Samsung Galaxy S24',
        hostname: 'android-host',
      ),
      'Samsung Galaxy S24',
    );
    expect(
      selectSyncDeviceName(platform: 'ios', hostname: 'localhost'),
      'ios device',
    );
  });

  test('desktop uses the computer name but rejects loopback identities', () {
    expect(
      selectSyncDeviceName(platform: 'windows', hostname: '  READER-PC  '),
      'READER-PC',
    );
    for (final hostname in ['localhost', 'localhost.localdomain', '127.0.0.1', '::1']) {
      expect(
        selectSyncDeviceName(platform: 'linux', hostname: hostname),
        'linux device',
      );
    }
  });

  test('device name respects server byte limit without splitting Unicode', () {
    final name = selectSyncDeviceName(
      platform: 'android',
      name: String.fromCharCode(0x20000) * 40,
    );
    expect(name, String.fromCharCode(0x20000) * 32);
    expect(utf8.encode(name).length, 128);
  });
}
