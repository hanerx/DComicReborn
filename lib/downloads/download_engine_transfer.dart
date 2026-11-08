import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import 'package:path/path.dart' as p;

class ParallelDownloadCapabilityException implements Exception {
  final String message;

  const ParallelDownloadCapabilityException(this.message);

  @override
  String toString() => 'ParallelDownloadCapabilityException: $message';
}

class DownloadByteRange {
  final int start;
  final int end;

  const DownloadByteRange(this.start, this.end)
    : assert(start >= 0),
      assert(end >= start);

  int get length => end - start + 1;

  @override
  bool operator ==(Object other) =>
      other is DownloadByteRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'bytes=$start-$end';
}

List<DownloadByteRange> splitDownloadRanges(int length, int chunks) {
  if (length <= 0) {
    throw ArgumentError.value(length, 'length', 'must be positive');
  }
  if (chunks <= 0) {
    throw ArgumentError.value(chunks, 'chunks', 'must be positive');
  }
  final count = math.min(length, chunks);
  final chunkLength = (length / count).ceil();
  return [
    for (var start = 0; start < length; start += chunkLength)
      DownloadByteRange(start, math.min(start + chunkLength - 1, length - 1)),
  ];
}

String? strongEntityTag(String? value) {
  if (value == null) return null;
  final candidate = value.trim();
  if (candidate.length < 2 ||
      candidate.startsWith('W/') ||
      candidate.startsWith('w/') ||
      !candidate.startsWith('"') ||
      !candidate.endsWith('"') ||
      candidate.substring(1, candidate.length - 1).contains('"')) {
    return null;
  }
  return candidate;
}

String? headerValue(Map<String, String> headers, String name) {
  final target = name.toLowerCase();
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == target) return entry.value;
  }
  return null;
}

Map<String, String> identityRequestHeaders(
  Map<String, String> source, {
  DownloadByteRange? range,
  String? strongETag,
}) {
  final result = <String, String>{};
  for (final entry in source.entries) {
    final name = entry.key.toLowerCase();
    if (name != 'range' &&
        name != 'if-match' &&
        name != 'accept-encoding' &&
        name != 'known-content-length') {
      result[entry.key] = entry.value;
    }
  }
  result['Accept-Encoding'] = 'identity';
  if (range != null) result['Range'] = 'bytes=${range.start}-${range.end}';
  if (strongETag != null) result['If-Match'] = strongETag;
  return result;
}

void validateRangeResponse({
  required int? statusCode,
  required Map<String, String>? headers,
  required DownloadByteRange range,
  required int expectedLength,
  required String? strongETag,
  required int actualFileLength,
}) {
  if (statusCode != HttpStatus.partialContent) {
    throw FormatException(
      'Range request returned HTTP ${statusCode ?? 'unknown'} instead of 206',
    );
  }
  final responseHeaders = headers ?? const <String, String>{};
  final encoding = headerValue(
    responseHeaders,
    HttpHeaders.contentEncodingHeader,
  );
  if (encoding != null && encoding.trim().toLowerCase() != 'identity') {
    throw FormatException('Range response used non-identity content encoding');
  }
  final contentRange = headerValue(
    responseHeaders,
    HttpHeaders.contentRangeHeader,
  );
  final parsed = _parseContentRange(contentRange);
  if (parsed == null ||
      parsed.start != range.start ||
      parsed.end != range.end ||
      parsed.total != expectedLength) {
    throw FormatException(
      'Range response Content-Range did not match bytes '
      '${range.start}-${range.end}/$expectedLength',
    );
  }
  if (strongETag != null) {
    final responseETag = strongEntityTag(
      headerValue(responseHeaders, HttpHeaders.etagHeader),
    );
    if (responseETag != strongETag) {
      throw const FormatException(
        'Range response ETag did not match the pinned representation',
      );
    }
  }
  if (actualFileLength != range.length) {
    throw FormatException(
      'Range response length $actualFileLength did not match ${range.length}',
    );
  }
}

int? validateSingleResponse({
  required int? statusCode,
  required Map<String, String>? headers,
  required int? expectedLength,
  required String? strongETag,
  required int actualFileLength,
  required bool resuming,
}) {
  if (statusCode != HttpStatus.ok &&
      !(resuming && statusCode == HttpStatus.partialContent)) {
    throw FormatException(
      'Single request returned HTTP ${statusCode ?? 'unknown'}',
    );
  }
  final responseHeaders = headers ?? const <String, String>{};
  final encoding = headerValue(
    responseHeaders,
    HttpHeaders.contentEncodingHeader,
  );
  if (encoding != null && encoding.trim().toLowerCase() != 'identity') {
    throw const FormatException(
      'Single response used non-identity content encoding',
    );
  }
  if (strongETag != null) {
    final actualETag = strongEntityTag(
      headerValue(responseHeaders, HttpHeaders.etagHeader),
    );
    if (actualETag != strongETag) {
      throw const FormatException(
        'Single response ETag did not match the pinned representation',
      );
    }
  }
  var resolvedLength = expectedLength;
  if (statusCode == HttpStatus.partialContent) {
    final contentRange = _parseContentRange(
      headerValue(responseHeaders, HttpHeaders.contentRangeHeader),
    );
    resolvedLength ??= contentRange?.total;
    if (contentRange == null ||
        contentRange.total != resolvedLength ||
        contentRange.end != resolvedLength! - 1) {
      throw const FormatException(
        'Resumed single response had an invalid Content-Range',
      );
    }
  } else {
    final responseLength = int.tryParse(
      headerValue(responseHeaders, HttpHeaders.contentLengthHeader) ?? '',
    );
    if (resolvedLength == null &&
        responseLength != null &&
        responseLength >= 0) {
      resolvedLength = responseLength;
    }
  }
  if (resolvedLength != null && actualFileLength != resolvedLength) {
    throw FormatException(
      'Single response length $actualFileLength did not match $resolvedLength',
    );
  }
  return resolvedLength;
}

({int start, int end, int total})? _parseContentRange(String? value) {
  if (value == null) return null;
  final match = RegExp(
    r'^bytes\s+(\d+)-(\d+)/(\d+)$',
    caseSensitive: false,
  ).firstMatch(value.trim());
  if (match == null) return null;
  final start = int.tryParse(match.group(1)!);
  final end = int.tryParse(match.group(2)!);
  final total = int.tryParse(match.group(3)!);
  if (start == null ||
      end == null ||
      total == null ||
      end < start ||
      total <= end) {
    return null;
  }
  return (start: start, end: end, total: total);
}

class EngineHttpResponse {
  final int statusCode;
  final Map<String, String> headers;

  const EngineHttpResponse({required this.statusCode, required this.headers});
}

abstract interface class DownloadHttpProbe {
  Future<EngineHttpResponse> head(Uri url, Map<String, String> headers);

  Future<EngineHttpResponse> range(
    Uri url,
    Map<String, String> headers,
    DownloadByteRange range,
  );
}

class IoDownloadHttpProbe implements DownloadHttpProbe {
  final Duration timeout;

  const IoDownloadHttpProbe({this.timeout = const Duration(seconds: 30)});

  @override
  Future<EngineHttpResponse> head(Uri url, Map<String, String> headers) =>
      _request('HEAD', url, identityRequestHeaders(headers), false);

  @override
  Future<EngineHttpResponse> range(
    Uri url,
    Map<String, String> headers,
    DownloadByteRange range,
  ) => _request('GET', url, headers, true);

  Future<EngineHttpResponse> _request(
    String method,
    Uri url,
    Map<String, String> headers,
    bool rangeProbe,
  ) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.openUrl(method, url).timeout(timeout);
      request.followRedirects = true;
      request.maxRedirects = 5;
      headers.forEach((name, value) => request.headers.set(name, value));
      final response = await request.close().timeout(timeout);
      final responseHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        responseHeaders[name.toLowerCase()] = values.join(',');
      });
      final result = EngineHttpResponse(
        statusCode: response.statusCode,
        headers: responseHeaders,
      );
      if (!rangeProbe ||
          (response.statusCode == HttpStatus.partialContent &&
              response.contentLength >= 0 &&
              response.contentLength <= 1)) {
        await response.drain<void>().timeout(timeout);
      } else {
        final subscription = response.listen((_) {});
        await subscription.cancel();
      }
      return result;
    } finally {
      client.close(force: true);
    }
  }
}

class DownloadRepresentation {
  final int? expectedLength;
  final String? strongETag;

  const DownloadRepresentation({this.expectedLength, this.strongETag});
}

class DownloadEnginePreflight {
  final DownloadHttpProbe _probe;

  DownloadEnginePreflight([DownloadHttpProbe? probe])
    : _probe = probe ?? const IoDownloadHttpProbe();

  Future<DownloadRepresentation> single(
    Uri url,
    Map<String, String> headers,
  ) async {
    try {
      final response = await _probe.head(url, headers);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const DownloadRepresentation();
      }
      final encoding = headerValue(
        response.headers,
        HttpHeaders.contentEncodingHeader,
      );
      if (encoding != null && encoding.trim().toLowerCase() != 'identity') {
        return const DownloadRepresentation();
      }
      return DownloadRepresentation(
        expectedLength: _positiveContentLength(response.headers),
        strongETag: strongEntityTag(
          headerValue(response.headers, HttpHeaders.etagHeader),
        ),
      );
    } on Object {
      return const DownloadRepresentation();
    }
  }

  Future<DownloadRepresentation> parallel(
    Uri url,
    Map<String, String> headers, {
    required bool hasExpectedDigest,
  }) async {
    EngineHttpResponse? headResponse;
    try {
      final candidate = await _probe.head(url, headers);
      if (candidate.statusCode >= 200 && candidate.statusCode < 300) {
        headResponse = candidate;
      }
    } on Object {
      headResponse = null;
    }
    final headEncoding = headResponse == null
        ? null
        : headerValue(headResponse.headers, HttpHeaders.contentEncodingHeader);
    if (headEncoding != null &&
        headEncoding.trim().toLowerCase() != 'identity') {
      throw const ParallelDownloadCapabilityException(
        'Server did not provide an identity byte representation',
      );
    }
    final headLength = headResponse == null
        ? null
        : _positiveContentLength(headResponse.headers);
    final headETag = headResponse == null
        ? null
        : strongEntityTag(
            headerValue(headResponse.headers, HttpHeaders.etagHeader),
          );
    const probeRange = DownloadByteRange(0, 0);
    final rangeHeaders = identityRequestHeaders(
      headers,
      range: probeRange,
      strongETag: headETag,
    );
    final EngineHttpResponse rangeResponse;
    try {
      rangeResponse = await _probe.range(url, rangeHeaders, probeRange);
    } on Object catch (error) {
      throw ParallelDownloadCapabilityException(
        'Range request preflight failed (${error.runtimeType})',
      );
    }
    if (rangeResponse.statusCode != HttpStatus.partialContent) {
      throw ParallelDownloadCapabilityException(
        'Range request returned HTTP ${rangeResponse.statusCode} instead of 206',
      );
    }
    final rangeEncoding = headerValue(
      rangeResponse.headers,
      HttpHeaders.contentEncodingHeader,
    );
    if (rangeEncoding != null &&
        rangeEncoding.trim().toLowerCase() != 'identity') {
      throw const ParallelDownloadCapabilityException(
        'Range request returned a non-identity byte representation',
      );
    }
    final contentRange = _parseContentRange(
      headerValue(rangeResponse.headers, HttpHeaders.contentRangeHeader),
    );
    if (contentRange == null ||
        contentRange.start != 0 ||
        contentRange.end != 0) {
      throw const ParallelDownloadCapabilityException(
        'Range request returned an invalid Content-Range',
      );
    }
    if (headLength != null && headLength != contentRange.total) {
      throw const ParallelDownloadCapabilityException(
        'HEAD and Range responses reported different content lengths',
      );
    }
    final rangeETag = strongEntityTag(
      headerValue(rangeResponse.headers, HttpHeaders.etagHeader),
    );
    if (headETag != null && rangeETag != headETag) {
      throw const ParallelDownloadCapabilityException(
        'HEAD and Range responses did not identify the same representation',
      );
    }
    final representationETag = headETag ?? rangeETag;
    if (representationETag == null && !hasExpectedDigest) {
      throw const ParallelDownloadCapabilityException(
        'Range requests require a strong ETag or an expected digest',
      );
    }
    return DownloadRepresentation(
      expectedLength: contentRange.total,
      strongETag: representationETag,
    );
  }

  int? _positiveContentLength(Map<String, String> headers) {
    final parsed = int.tryParse(
      headerValue(headers, HttpHeaders.contentLengthHeader) ?? '',
    );
    return parsed != null && parsed > 0 ? parsed : null;
  }
}

enum DurableTransferKind { single, parallel }

enum DurableTransferState {
  preparing,
  running,
  pauseRequested,
  paused,
  resumeRequested,
  merging,
  complete,
  failed,
  canceled,
}

enum DurableChildState { pending, running, paused, complete, failed, canceled }

List<DurableTransferChild> childrenForSafeParallelPause(
  Iterable<DurableTransferChild> children,
) => [
  for (final child in children)
    child.state == DurableChildState.complete
        ? child
        : child.copyWith(state: DurableChildState.pending),
];

bool shouldCaptureExternalResume(
  DurableTransferDescriptor descriptor, {
  required bool nativeActive,
  required bool nativeCompleted,
  required bool nativeRunnable,
}) =>
    descriptor.kind == DurableTransferKind.single &&
    descriptor.state == DurableTransferState.paused &&
    (nativeCompleted || (nativeActive && nativeRunnable));

bool shouldReplayNativeCancellation(
  DurableTransferDescriptor descriptor, {
  required bool nativeCanceled,
}) =>
    nativeCanceled &&
    descriptor.kind == DurableTransferKind.single &&
    descriptor.state == DurableTransferState.paused &&
    !descriptor.restartRequired;

bool isNativeTransferProgress(double progress) =>
    progress >= 0 && progress <= 1;

bool shouldCancelNativeTasksOnRemoval(DurableTransferState state) =>
    state != DurableTransferState.complete;

String? comicNotificationGroupId(String? businessGroup) {
  if (businessGroup == null || !businessGroup.startsWith('comic:')) return null;
  return 'dcomic-comic-${sha256.convert(utf8.encode(businessGroup))}';
}

class DurableTransferChild {
  final String taskId;
  final int index;
  final int start;
  final int end;
  final String path;
  final int attempt;
  final DurableChildState state;

  const DurableTransferChild({
    required this.taskId,
    required this.index,
    required this.start,
    required this.end,
    required this.path,
    this.attempt = 0,
    this.state = DurableChildState.pending,
  });

  DownloadByteRange get range => DownloadByteRange(start, end);

  DurableTransferChild copyWith({
    String? taskId,
    int? attempt,
    DurableChildState? state,
  }) => DurableTransferChild(
    taskId: taskId ?? this.taskId,
    index: index,
    start: start,
    end: end,
    path: path,
    attempt: attempt ?? this.attempt,
    state: state ?? this.state,
  );

  Map<String, Object> toJson() => {
    'taskId': taskId,
    'index': index,
    'start': start,
    'end': end,
    'path': path,
    'attempt': attempt,
    'state': state.name,
  };

  factory DurableTransferChild.fromJson(Map<String, dynamic> json) {
    final taskId = json['taskId'];
    final index = json['index'];
    final start = json['start'];
    final end = json['end'];
    final path = json['path'];
    final attempt = json['attempt'];
    final stateName = json['state'];
    if (taskId is! String ||
        index is! int ||
        start is! int ||
        end is! int ||
        path is! String ||
        attempt is! int ||
        stateName is! String) {
      throw const FormatException('Invalid durable transfer child');
    }
    final state = _enumByName(DurableChildState.values, stateName);
    if (state == null || start < 0 || end < start || attempt < 0) {
      throw const FormatException('Invalid durable transfer child');
    }
    return DurableTransferChild(
      taskId: taskId,
      index: index,
      start: start,
      end: end,
      path: path,
      attempt: attempt,
      state: state,
    );
  }
}

class DurableTransferDescriptor {
  static const schema = 1;

  final String businessId;
  final int generation;
  final String parentTaskId;
  final String stagingPath;
  final String url;
  final Map<String, String> headers;
  final String? businessGroup;
  final String displayName;
  final DurableTransferKind kind;
  final DurableTransferState state;
  final int? expectedLength;
  final String? strongETag;
  final bool hasExpectedDigest;
  final bool restartRequired;
  final List<DurableTransferChild> children;
  final bool resuming;
  final bool externalResumeRequested;
  final String? error;

  DurableTransferDescriptor({
    required this.businessId,
    required this.generation,
    required this.parentTaskId,
    required this.stagingPath,
    required this.url,
    required Map<String, String> headers,
    this.businessGroup,
    required this.displayName,
    required this.kind,
    required this.state,
    required this.expectedLength,
    required this.strongETag,
    required this.hasExpectedDigest,
    this.resuming = false,
    this.externalResumeRequested = false,
    this.restartRequired = false,
    List<DurableTransferChild> children = const [],
    this.error,
  }) : headers = Map<String, String>.unmodifiable(headers),
       children = List<DurableTransferChild>.unmodifiable(children) {
    if (businessId.isEmpty ||
        generation < 0 ||
        parentTaskId.isEmpty ||
        stagingPath.isEmpty ||
        url.isEmpty ||
        (expectedLength != null && expectedLength! < 0) ||
        (kind == DurableTransferKind.parallel &&
            (expectedLength == null ||
                expectedLength! <= 0 ||
                children.isEmpty))) {
      throw const FormatException('Invalid durable transfer descriptor');
    }
  }

  DurableTransferDescriptor copyWith({
    DurableTransferState? state,
    int? expectedLength,
    bool? restartRequired,
    List<DurableTransferChild>? children,
    String? error,
    bool? resuming,
    bool? externalResumeRequested,
    bool clearError = false,
  }) => DurableTransferDescriptor(
    businessId: businessId,
    generation: generation,
    parentTaskId: parentTaskId,
    stagingPath: stagingPath,
    url: url,
    headers: headers,
    displayName: displayName,
    businessGroup: businessGroup,
    kind: kind,
    state: state ?? this.state,
    expectedLength: expectedLength ?? this.expectedLength,
    strongETag: strongETag,
    hasExpectedDigest: hasExpectedDigest,
    restartRequired: restartRequired ?? this.restartRequired,
    resuming: resuming ?? this.resuming,
    externalResumeRequested:
        externalResumeRequested ?? this.externalResumeRequested,
    children: children ?? this.children,
    error: clearError ? null : error ?? this.error,
  );

  Map<String, Object?> toJson() => {
    'schema': schema,
    'businessId': businessId,
    'generation': generation,
    'parentTaskId': parentTaskId,
    'stagingPath': stagingPath,
    'url': url,
    'businessGroup': businessGroup,
    'headers': headers,
    'displayName': displayName,
    'kind': kind.name,
    'state': state.name,
    'expectedLength': expectedLength,
    'strongETag': strongETag,
    'hasExpectedDigest': hasExpectedDigest,
    'restartRequired': restartRequired,
    'resuming': resuming,
    'externalResumeRequested': externalResumeRequested,
    'children': children.map((child) => child.toJson()).toList(),
    'error': error,
  };

  factory DurableTransferDescriptor.fromJson(Map<String, dynamic> json) {
    if (json['schema'] != schema) {
      throw const FormatException('Unsupported durable transfer descriptor');
    }
    final businessId = json['businessId'];
    final generation = json['generation'];
    final parentTaskId = json['parentTaskId'];
    final stagingPath = json['stagingPath'];
    final url = json['url'];
    final rawHeaders = json['headers'];
    final displayName = json['displayName'];
    final businessGroup = json['businessGroup'];
    final kindName = json['kind'];
    final stateName = json['state'];
    final expectedLength = json['expectedLength'];
    final strongETag = json['strongETag'];
    final hasExpectedDigest = json['hasExpectedDigest'];
    final restartRequired = json['restartRequired'];
    final resuming = json['resuming'] ?? false;
    final externalResumeRequested = json['externalResumeRequested'] ?? false;
    final rawChildren = json['children'];
    final error = json['error'];
    if (businessId is! String ||
        generation is! int ||
        parentTaskId is! String ||
        stagingPath is! String ||
        url is! String ||
        rawHeaders is! Map ||
        (businessGroup != null && businessGroup is! String) ||
        displayName is! String ||
        kindName is! String ||
        stateName is! String ||
        (expectedLength != null && expectedLength is! int) ||
        (strongETag != null && strongETag is! String) ||
        hasExpectedDigest is! bool ||
        resuming is! bool ||
        externalResumeRequested is! bool ||
        restartRequired is! bool ||
        rawChildren is! List ||
        (error != null && error is! String)) {
      throw const FormatException('Invalid durable transfer descriptor');
    }
    final kind = _enumByName(DurableTransferKind.values, kindName);
    final state = _enumByName(DurableTransferState.values, stateName);
    if (kind == null || state == null) {
      throw const FormatException('Invalid durable transfer descriptor');
    }
    return DurableTransferDescriptor(
      businessId: businessId,
      generation: generation,
      parentTaskId: parentTaskId,
      stagingPath: stagingPath,
      url: url,
      businessGroup: businessGroup as String?,
      headers: Map<String, String>.from(rawHeaders),
      displayName: displayName,
      kind: kind,
      state: state,
      expectedLength: expectedLength as int?,
      strongETag: strongETag as String?,
      hasExpectedDigest: hasExpectedDigest,
      restartRequired: restartRequired,
      resuming: resuming,
      externalResumeRequested: externalResumeRequested,
      children: rawChildren
          .map(
            (value) => DurableTransferChild.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList(growable: false),
      error: error as String?,
    );
  }
}

T? _enumByName<T extends Enum>(List<T> values, String name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

class DownloadEngineDescriptorStore {
  const DownloadEngineDescriptorStore();

  String pathFor(String stagingPath) => '$stagingPath.dcomic-transfer.json';

  String mergePathFor(String stagingPath) => '$stagingPath.dcomic-merge';

  File stagingFile(String stagingPath) {
    _assertSafeSidecar(stagingPath, stagingPath);
    return File(stagingPath);
  }

  File sidecarFile(String stagingPath, String sidecarPath) {
    _assertSafeSidecar(stagingPath, sidecarPath);
    return File(sidecarPath);
  }

  Future<DurableTransferDescriptor?> readForStaging(String stagingPath) {
    _assertSafeSidecar(stagingPath, pathFor(stagingPath));
    return read(pathFor(stagingPath));
  }

  Future<DurableTransferDescriptor?> read(String descriptorPath) async {
    const suffix = '.dcomic-transfer.json';
    if (!descriptorPath.endsWith(suffix)) {
      throw FileSystemException(
        'invalid download descriptor path',
        descriptorPath,
      );
    }
    final stagingPath = descriptorPath.substring(
      0,
      descriptorPath.length - suffix.length,
    );
    _assertSafeSidecar(stagingPath, descriptorPath);
    final file = File(descriptorPath);
    if (!await file.exists()) return null;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw const FormatException('Invalid durable transfer descriptor');
    }
    return DurableTransferDescriptor.fromJson(
      Map<String, dynamic>.from(decoded),
    );
  }

  Future<void> write(DurableTransferDescriptor descriptor) async {
    final target = sidecarFile(
      descriptor.stagingPath,
      pathFor(descriptor.stagingPath),
    );
    await target.parent.create(recursive: true);
    final temporary = sidecarFile(descriptor.stagingPath, '${target.path}.tmp');
    await temporary.writeAsString(jsonEncode(descriptor.toJson()), flush: true);
    _assertSafeSidecar(descriptor.stagingPath, target.path);
    _assertSafeSidecar(descriptor.stagingPath, temporary.path);
    await temporary.rename(target.path);
  }

  Future<void> delete(DurableTransferDescriptor descriptor) async {
    await _deleteIfExists(
      sidecarFile(descriptor.stagingPath, pathFor(descriptor.stagingPath)),
    );
    await _deleteIfExists(
      sidecarFile(
        descriptor.stagingPath,
        '${pathFor(descriptor.stagingPath)}.tmp',
      ),
    );
    await _deleteIfExists(
      sidecarFile(descriptor.stagingPath, mergePathFor(descriptor.stagingPath)),
    );
  }

  Future<void> _deleteIfExists(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      if (await file.exists()) rethrow;
    }
  }

  void _assertSafeSidecar(String stagingPath, String candidatePath) {
    final staging = File(stagingPath).absolute;
    final stagingDirectory = staging.parent;
    final root = stagingDirectory.parent;
    final expectedStagingDirectory = _normalizedAbsolute(
      '${root.path}${Platform.pathSeparator}.staging',
    );
    if (_normalizedAbsolute(stagingDirectory.path) !=
            expectedStagingDirectory ||
        _normalizedAbsolute(File(candidatePath).parent.path) !=
            expectedStagingDirectory) {
      throw FileSystemException(
        'download sidecar escapes the staging directory',
        candidatePath,
      );
    }
    final rootCanonical = _canonical(root);
    for (final entity in <FileSystemEntity>[
      stagingDirectory,
      File(candidatePath),
    ]) {
      final type = FileSystemEntity.typeSync(entity.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) continue;
      if (type == FileSystemEntityType.link) {
        throw FileSystemException(
          'download sidecar traverses a filesystem link',
          entity.path,
        );
      }
      final resolved = _canonical(
        type == FileSystemEntityType.directory
            ? Directory(entity.path)
            : File(entity.path),
      );
      if (!_isWithin(rootCanonical, resolved)) {
        throw FileSystemException(
          'download sidecar escapes the managed root',
          entity.path,
        );
      }
    }
  }

  String _canonical(FileSystemEntity entity) =>
      _normalizedAbsolute(entity.resolveSymbolicLinksSync());

  String _normalizedAbsolute(String path) {
    var normalized = p.normalize(p.absolute(path)).replaceAll('\\', '/');
    while (normalized.length > 1 && normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }

  bool _isWithin(String rootPath, String candidate) =>
      candidate == rootPath || candidate.startsWith('$rootPath/');
}
