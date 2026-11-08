import 'dart:io';

import 'package:dcomic/downloads/download_models.dart';
import 'package:dcomic/downloads/download_service.dart';

enum UpdateTargetPlatform { android, windows, macos, ios, unsupported }

class ReleaseInfo {
  final String version;
  final String updateUrl;
  final String desc;
  final String releaseUrl;
  final String fileName;
  final int? expectedBytes;
  final String? sha256Hex;

  const ReleaseInfo(
    this.version,
    this.updateUrl,
    this.desc,
    this.releaseUrl, {
    this.fileName = '',
    this.expectedBytes,
    this.sha256Hex,
  });

  bool get hasTrustedSha256 => sha256Hex != null;
}

UpdateTargetPlatform get currentUpdateTargetPlatform {
  if (Platform.isAndroid) return UpdateTargetPlatform.android;
  if (Platform.isWindows) return UpdateTargetPlatform.windows;
  if (Platform.isMacOS) return UpdateTargetPlatform.macos;
  if (Platform.isIOS) return UpdateTargetPlatform.ios;
  return UpdateTargetPlatform.unsupported;
}

ReleaseInfo? releaseInfoFromGithub(
  Map<dynamic, dynamic> release,
  UpdateTargetPlatform platform,
) {
  final version = release['tag_name']?.toString();
  if (version == null || version.isEmpty) return null;

  final assets = release['assets'];
  final selectedAsset = assets is Iterable
      ? _selectPlatformAsset(assets, platform)
      : null;

  final fileName = selectedAsset?['name']?.toString() ?? '';
  return ReleaseInfo(
    version,
    selectedAsset?['browser_download_url']?.toString() ?? '',
    release['body']?.toString() ?? '',
    release['html_url']?.toString() ?? '',
    fileName: fileName,
    expectedBytes: _parseExpectedBytes(selectedAsset?['size']),
    sha256Hex: _parseSha256(selectedAsset?['digest']),
  );
}

DownloadRequest buildUpdateDownloadRequest(
  ReleaseInfo release,
  UpdateTargetPlatform platform,
) {
  if (platform == UpdateTargetPlatform.unsupported) {
    throw UnsupportedError('Updates are not available on this platform.');
  }
  if (release.updateUrl.isEmpty || release.fileName.isEmpty) {
    throw StateError('The release does not contain a platform package.');
  }
  if (!release.hasTrustedSha256) {
    throw StateError('The release package has no trusted SHA-256 digest.');
  }

  final versionSegment = _safePathSegment(release.version, fallback: 'release');
  final fileSegment = _safePathSegment(release.fileName, fallback: 'update');
  return DownloadRequest(
    id: 'app-update:${platform.name}:${release.version}',
    url: Uri.parse(release.updateUrl),
    relativePath: 'updates/${platform.name}/$versionSegment/$fileSegment',
    group: 'app-update',
    integrity: DownloadIntegrity(
      expectedBytes: release.expectedBytes,
      sha256Hex: release.sha256Hex,
    ),
    displayName: release.fileName,
  );
}

Future<String> submitUpdateDownload(
  ReleaseInfo release,
  UpdateTargetPlatform platform,
) {
  return DownloadService.instance.submit(
    buildUpdateDownloadRequest(release, platform),
  );
}

Map<dynamic, dynamic>? _selectPlatformAsset(
  Iterable<dynamic> assets,
  UpdateTargetPlatform platform,
) {
  Map<dynamic, dynamic>? windowsFallback;
  for (final asset in assets) {
    if (asset is! Map) continue;
    final name = asset['name']?.toString() ?? '';
    if (platform == UpdateTargetPlatform.windows) {
      final lower = name.toLowerCase();
      if (!lower.endsWith('.exe')) continue;
      if (lower.contains('setup')) return asset;
      windowsFallback ??= asset;
      continue;
    }
    if (_matchesPlatformAsset(name, platform)) return asset;
  }
  return windowsFallback;
}

bool _matchesPlatformAsset(String fileName, UpdateTargetPlatform platform) {
  final lower = fileName.toLowerCase();
  return switch (platform) {
    UpdateTargetPlatform.android => lower.endsWith('.apk'),
    UpdateTargetPlatform.windows => lower.endsWith('.exe'),
    UpdateTargetPlatform.macos =>
      lower.endsWith('.dmg') && lower.contains('universal'),
    UpdateTargetPlatform.ios => lower.endsWith('.ipa'),
    UpdateTargetPlatform.unsupported => false,
  };
}

int? _parseExpectedBytes(Object? value) {
  if (value is int) return value >= 0 ? value : null;
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    final parsed = value.toInt();
    return parsed >= 0 ? parsed : null;
  }
  if (value is String) {
    final parsed = int.tryParse(value);
    return parsed != null && parsed >= 0 ? parsed : null;
  }
  return null;
}

String? _parseSha256(Object? value) {
  if (value is! String) return null;
  final match = RegExp(
    r'^sha256:([0-9a-f]{64})$',
    caseSensitive: false,
  ).firstMatch(value.trim());
  return match?.group(1)?.toLowerCase();
}

String _safePathSegment(String value, {required String fallback}) {
  final normalized = value
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
      .replaceAll(RegExp(r'^\.+'), '');
  return normalized.isEmpty ? fallback : normalized;
}
