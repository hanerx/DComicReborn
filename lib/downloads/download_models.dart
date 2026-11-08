import 'dart:collection';
import 'dart:io';

/// Business-visible state. Native transfer completion is represented as
/// [verifying] until the durable file has passed every configured check.
enum DownloadState {
  queued,
  running,
  paused,
  verifying,
  completed,
  failed,
  canceled,
}

enum TransferStrategy { single, parallel }

class DownloadIntegrity {
  final int? expectedBytes;
  final String? sha256Hex;

  const DownloadIntegrity({this.expectedBytes, this.sha256Hex})
    : assert(expectedBytes == null || expectedBytes >= 0),
      assert(sha256Hex == null || sha256Hex.length == 64);

  bool get hasExpectation => expectedBytes != null || sha256Hex != null;

  String? get normalizedSha256 {
    final value = sha256Hex?.toLowerCase();
    if (value == null) return null;
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
      throw const FormatException('SHA-256 must contain 64 hexadecimal digits');
    }
    return value;
  }
}

class DownloadRequest {
  final String id;
  final Uri url;
  final Map<String, String> headers;
  final String relativePath;
  final String group;
  final DownloadIntegrity integrity;
  final TransferStrategy strategy;
  final int chunks;
  final String? cacheKey;
  final String? displayName;

  DownloadRequest({
    required this.id,
    required this.url,
    Map<String, String> headers = const {},
    required this.relativePath,
    required this.group,
    this.integrity = const DownloadIntegrity(),
    this.strategy = TransferStrategy.single,
    this.chunks = 1,
    this.cacheKey,
    this.displayName,
  }) : headers = UnmodifiableMapView(Map<String, String>.of(headers)) {
    if (id.isEmpty) throw ArgumentError.value(id, 'id', 'must not be empty');
    if (!url.hasScheme || url.host.isEmpty) {
      throw ArgumentError.value(url, 'url', 'must be an absolute network URL');
    }
    if (url.scheme != 'http' && url.scheme != 'https') {
      throw ArgumentError.value(url, 'url', 'must use HTTP or HTTPS');
    }
    if (group.isEmpty) {
      throw ArgumentError.value(group, 'group', 'must not be empty');
    }
    if (chunks < 1) {
      throw ArgumentError.value(chunks, 'chunks', 'must be at least one');
    }
    validateRelativeDownloadPath(relativePath);
    if (relativePath.replaceAll('\\', '/').split('/').first.toLowerCase() ==
        '.staging') {
      throw ArgumentError.value(
        relativePath,
        'relativePath',
        'uses the reserved staging namespace',
      );
    }
    integrity.normalizedSha256;
  }

  DownloadRequest copyWith({
    String? id,
    Uri? url,
    Map<String, String>? headers,
    String? relativePath,
    String? group,
    DownloadIntegrity? integrity,
    TransferStrategy? strategy,
    int? chunks,
    String? cacheKey,
    bool clearCacheKey = false,
    String? displayName,
    bool clearDisplayName = false,
  }) => DownloadRequest(
    id: id ?? this.id,
    url: url ?? this.url,
    headers: headers ?? this.headers,
    relativePath: relativePath ?? this.relativePath,
    group: group ?? this.group,
    integrity: integrity ?? this.integrity,
    strategy: strategy ?? this.strategy,
    chunks: chunks ?? this.chunks,
    cacheKey: clearCacheKey ? null : cacheKey ?? this.cacheKey,
    displayName: clearDisplayName ? null : displayName ?? this.displayName,
  );

  bool sameContentAs(DownloadRequest other) =>
      id == other.id &&
      url == other.url &&
      _mapsEqual(headers, other.headers) &&
      relativePath == other.relativePath &&
      group == other.group &&
      integrity.expectedBytes == other.integrity.expectedBytes &&
      integrity.normalizedSha256 == other.integrity.normalizedSha256 &&
      strategy == other.strategy &&
      chunks == other.chunks &&
      cacheKey == other.cacheKey &&
      displayName == other.displayName;
}

class DownloadRecord {
  final DownloadRequest request;
  final DownloadState state;
  final int generation;
  final TransferStrategy effectiveStrategy;
  final String? engineTaskId;
  final int bytesReceived;
  final int? totalBytes;
  final bool resumeRequested;
  final String? error;
  final DateTime createdAt;
  final DateTime? completedAt;

  DownloadRecord({
    required this.request,
    required this.state,
    required this.generation,
    TransferStrategy? effectiveStrategy,
    this.engineTaskId,
    this.resumeRequested = false,
    required this.bytesReceived,
    this.totalBytes,
    this.error,
    required this.createdAt,
    this.completedAt,
  }) : effectiveStrategy = effectiveStrategy ?? request.strategy;

  String get id => request.id;

  DownloadRecord copyWith({
    DownloadRequest? request,
    DownloadState? state,
    int? generation,
    TransferStrategy? effectiveStrategy,
    String? engineTaskId,
    bool? resumeRequested,
    bool clearEngineTaskId = false,
    int? bytesReceived,
    int? totalBytes,
    bool clearTotalBytes = false,
    String? error,
    bool clearError = false,
    DateTime? createdAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) => DownloadRecord(
    request: request ?? this.request,
    state: state ?? this.state,
    effectiveStrategy: effectiveStrategy ?? this.effectiveStrategy,
    generation: generation ?? this.generation,
    engineTaskId: clearEngineTaskId ? null : engineTaskId ?? this.engineTaskId,
    resumeRequested: resumeRequested ?? this.resumeRequested,
    bytesReceived: bytesReceived ?? this.bytesReceived,
    totalBytes: clearTotalBytes ? null : totalBytes ?? this.totalBytes,
    error: clearError ? null : error ?? this.error,
    createdAt: createdAt ?? this.createdAt,
    completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
  );
}

void validateRelativeDownloadPath(String value) {
  if (value.isEmpty || value.contains('\u0000')) {
    throw ArgumentError.value(
      value,
      'relativePath',
      'must be a safe relative path',
    );
  }
  final normalized = value.replaceAll('\\', '/');
  if (normalized.startsWith('/') ||
      RegExp(r'^[A-Za-z]:').hasMatch(normalized)) {
    throw ArgumentError.value(value, 'relativePath', 'must not be absolute');
  }
  final segments = normalized.split('/');
  if (segments.any(
    (segment) => segment.isEmpty || segment == '.' || segment == '..',
  )) {
    throw ArgumentError.value(
      value,
      'relativePath',
      'contains an unsafe segment',
    );
  }
}

String canonicalRelativeDownloadPath(String value) {
  validateRelativeDownloadPath(value);
  final normalized = value.replaceAll('\\', '/');
  if (Platform.isWindows || Platform.isMacOS) {
    return normalized.toLowerCase();
  }
  return normalized;
}

bool _mapsEqual(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}
