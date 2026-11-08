import 'dart:collection';
import 'package:dcomic/providers/models/chapter_metadata.dart';

/// Stable identity of a comic within one source.
typedef ComicKey = ({String sourceId, String comicId});

/// Stable identity of a chapter within one source comic.
typedef ChapterKey = ({String sourceId, String comicId, String chapterId});

enum OfflineChapterState {
  pending,
  resolving,
  downloading,
  paused,
  completed,
  failed,
  canceled,
}

class ChapterProvenance {
  final ChapterKey requested;
  final ChapterKey actual;
  final bool isLocal;

  const ChapterProvenance({
    required this.requested,
    required this.actual,
    required this.isLocal,
  });
}

class OfflineCatalogChapter {
  final String chapterId;
  final String rawTitle;
  final String groupName;
  final String? language;
  final List<ScanlationGroup> scanlationGroups;

  const OfflineCatalogChapter({
    required this.chapterId,
    required this.rawTitle,
    required this.groupName,
    this.language,
    this.scanlationGroups = const [],
  });
}

class OfflinePage {
  final int index;
  final String taskId;
  final String relativePath;
  final String resourceUrl;
  final Map<String, String> headers;
  final String? cacheKey;
  final int? expectedBytes;
  final bool submitted;

  OfflinePage({
    required this.index,
    required this.taskId,
    required this.relativePath,
    required this.resourceUrl,
    Map<String, String> headers = const {},
    this.cacheKey,
    this.expectedBytes,
    this.submitted = false,
  }) : headers = UnmodifiableMapView(Map<String, String>.of(headers));
}

class OfflineComicSnapshot {
  final ComicKey key;
  final String rawTitle;
  final String? coverRelativePath;
  final String? remoteCoverUrl;
  final bool isLongComic;
  final List<OfflineCatalogChapter> catalog;

  const OfflineComicSnapshot({
    required this.key,
    required this.rawTitle,
    this.coverRelativePath,
    this.remoteCoverUrl,
    required this.isLongComic,
    this.catalog = const [],
  });
}

class OfflineChapterSnapshot {
  final ChapterKey key;
  final String rawTitle;
  final String groupName;
  final String? language;
  final List<ScanlationGroup> scanlationGroups;
  final int sortIndex;
  final int manifestGeneration;
  final int operationGeneration;
  final String manifestSignature;
  final OfflineChapterState state;
  final String? error;
  final DateTime? completedAt;
  final List<OfflinePage> pages;

  OfflineChapterSnapshot({
    required this.key,
    required this.rawTitle,
    required this.groupName,
    this.language,
    List<ScanlationGroup> scanlationGroups = const [],
    required this.sortIndex,
    required this.manifestGeneration,
    this.operationGeneration = 0,
    required this.manifestSignature,
    required this.state,
    this.error,
    this.completedAt,
    List<OfflinePage> pages = const [],
  })  : scanlationGroups = List<ScanlationGroup>.unmodifiable(scanlationGroups),
        pages = List<OfflinePage>.unmodifiable(pages);

  OfflineChapterSnapshot copyWith({
    int? manifestGeneration,
    int? operationGeneration,
    String? manifestSignature,
    OfflineChapterState? state,
    String? error,
    bool clearError = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    List<OfflinePage>? pages,
    String? language,
    bool clearLanguage = false,
    List<ScanlationGroup>? scanlationGroups,
  }) => OfflineChapterSnapshot(
    key: key,
    rawTitle: rawTitle,
    groupName: groupName,
    sortIndex: sortIndex,
    language: clearLanguage ? null : language ?? this.language,
    scanlationGroups: scanlationGroups ?? this.scanlationGroups,
    manifestGeneration: manifestGeneration ?? this.manifestGeneration,
    operationGeneration: operationGeneration ?? this.operationGeneration,
    manifestSignature: manifestSignature ?? this.manifestSignature,
    state: state ?? this.state,
    error: clearError ? null : error ?? this.error,
    completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
    pages: pages ?? this.pages,
  );
}

class OfflineManifest {
  final OfflineComicSnapshot comic;
  final OfflineChapterSnapshot chapter;

  const OfflineManifest({required this.comic, required this.chapter});
}

/// A source-owned version suitable for a library or source picker UI.
class OfflineComicVersion {
  final OfflineComicSnapshot comic;
  final int readableChapterCount;
  final DateTime? earliestCompletedAt;

  const OfflineComicVersion({
    required this.comic,
    required this.readableChapterCount,
    required this.earliestCompletedAt,
  });
}

/// A library row. [versions] contains each real source and never rewrites its
/// identity; aggregated rows only group versions for presentation.
class OfflineComicListItem {
  final String title;
  final List<OfflineComicVersion> versions;
  final bool aggregated;

  OfflineComicListItem({
    required this.title,
    required List<OfflineComicVersion> versions,
    required this.aggregated,
  }) : versions = List<OfflineComicVersion>.unmodifiable(versions);

  int get readableChapterCount => versions.fold(
    0,
    (total, version) => total + version.readableChapterCount,
  );

  List<String> get sourceIds => List<String>.unmodifiable(
    versions.map((version) => version.comic.key.sourceId),
  );
}

class OfflineChapterProgress {
  final ChapterKey key;
  final OfflineChapterState state;
  final int completedPages;
  final int totalPages;
  final int bytesReceived;
  final int? totalBytes;
  final String? error;

  const OfflineChapterProgress({
    required this.key,
    required this.state,
    required this.completedPages,
    required this.totalPages,
    required this.bytesReceived,
    required this.totalBytes,
    this.error,
  });
}

class OfflineChapterTask {
  final OfflineComicSnapshot comic;
  final OfflineChapterSnapshot chapter;
  final OfflineChapterProgress progress;

  const OfflineChapterTask({
    required this.comic,
    required this.chapter,
    required this.progress,
  });
}

class OfflineChapterAvailability {
  final ChapterKey requested;
  final OfflineChapterSnapshot? ownComplete;
  final List<OfflineChapterSnapshot> alternateCompletes;
  final OfflineChapterSnapshot? preferred;

  OfflineChapterAvailability({
    required this.requested,
    required this.ownComplete,
    required List<OfflineChapterSnapshot> alternateCompletes,
    required this.preferred,
  }) : alternateCompletes = List<OfflineChapterSnapshot>.unmodifiable(
         alternateCompletes,
       );

  bool get ownCompleteAvailable => ownComplete != null;

  bool get alternateCompleteAvailable => alternateCompletes.isNotEmpty;
}

class OfflineChapterMissingException implements Exception {
  final ChapterKey key;
  final String message;

  const OfflineChapterMissingException(this.key, this.message);

  @override
  String toString() => 'OfflineChapterMissingException($message, $key)';
}

class OfflineCommentsUnavailableException implements Exception {
  final ChapterKey key;

  const OfflineCommentsUnavailableException(this.key);

  @override
  String toString() => 'Comments require a connection for $key';
}
