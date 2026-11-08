import 'dart:io';

import 'package:dcomic/downloads/comic_download_models.dart';
import 'package:dcomic/downloads/offline_comic_store.dart';
import 'package:dcomic/providers/models/chapter_metadata.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/utils/image_utils.dart';

typedef OfflineChapterCommentsLoader =
    Future<List<ChapterCommentEntity>> Function(ChapterKey actual);

class OfflineComicDetailModel extends BaseComicDetailModel {
  final OfflineComicSnapshot comic;
  final List<OfflineChapterSnapshot> readableChapters;
  final OfflineComicStore? _store;
  final Directory? _rootDirectory;
  late final BaseComicSourceModel _parent = _OfflineComicSourceModel(
    comic.key.sourceId,
  );

  OfflineComicDetailModel({
    required this.comic,
    required List<OfflineChapterSnapshot> readableChapters,
  })  : readableChapters = List.unmodifiable(readableChapters),
        _store = null,
        _rootDirectory = null;

  OfflineComicDetailModel._({
    required this.comic,
    required List<OfflineChapterSnapshot> readableChapters,
    required OfflineComicStore store,
    required Directory rootDirectory,
  })  : readableChapters = List.unmodifiable(readableChapters),
        _store = store,
        _rootDirectory = rootDirectory;

  static Future<OfflineComicDetailModel> fromStore({
    required OfflineComicStore store,
    required ComicKey comicKey,
  }) async {
    final chapters = await store.listReadableChapters(comicKey);
    if (chapters.isEmpty) {
      throw StateError('No readable offline chapters exist for $comicKey');
    }
    final manifest = await store.loadManifest(chapters.first.key);
    if (manifest == null) {
      throw StateError('Offline comic disappeared while it was being opened');
    }
    return OfflineComicDetailModel._(
      comic: manifest.comic,
      readableChapters: chapters,
      store: store,
      rootDirectory: await store.transfers.rootDirectory,
    );
  }

  String get sourceId => comic.key.sourceId;

  @override
  ImageEntity get cover {
    final local = comic.coverRelativePath;
    final root = _rootDirectory;
    if (local != null && root != null) {
      return ImageEntity(ImageType.local, _resolve(root, local).path);
    }
    final remote = comic.remoteCoverUrl;
    return remote == null
        ? ImageEntity(ImageType.unknown, '')
        : ImageEntity(ImageType.network, remote);
  }

  @override
  ImageEntity get historyCover {
    final remote = comic.remoteCoverUrl;
    return remote == null
        ? ImageEntity(ImageType.unknown, '')
        : ImageEntity(ImageType.network, remote);
  }

  @override
  String get title => comic.rawTitle;

  @override
  String get rawTitle => comic.rawTitle;

  @override
  DateTime get lastUpdate {
    DateTime? latest;
    for (final chapter in readableChapters) {
      final completed = chapter.completedAt;
      if (completed != null && (latest == null || completed.isAfter(latest))) {
        latest = completed;
      }
    }
    return latest ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Map<String, List<BaseComicChapterEntityModel>> get chapters {
    final grouped = <String, List<BaseComicChapterEntityModel>>{};
    for (final chapter in readableChapters) {
      (grouped[chapter.groupName] ??= []).add(
        DefaultComicChapterEntityModel(
          chapter.rawTitle,
          chapter.key.chapterId,
          chapter.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
          language: chapter.language,
          scanlationGroups: chapter.scanlationGroups,
        ),
      );
    }
    return grouped;
  }

  @override
  String get description => '';

  @override
  String get status => '';

  @override
  String get comicId => comic.key.comicId;

  @override
  List<CategoryEntity> get authors => const [];

  @override
  List<CategoryEntity> get categories => const [];

  @override
  bool get isLongComic => comic.isLongComic;

  @override
  BaseComicSourceModel get parent => _parent;

  @override
  Future<BaseComicChapterDetailModel?> fetchRemoteChapter(
    String chapterId,
  ) async {
    final key = (
      sourceId: comic.key.sourceId,
      comicId: comic.key.comicId,
      chapterId: chapterId,
    );
    final store = _store;
    final root = _rootDirectory;
    if (store == null || root == null) {
      throw OfflineChapterMissingException(
        key,
        'Construct with OfflineComicDetailModel.fromStore to read files',
      );
    }
    final readable = await store.listReadableChapters(comic.key);
    OfflineChapterSnapshot? selected;
    for (final chapter in readable) {
      if (chapter.key.chapterId == chapterId) {
        selected = chapter;
        break;
      }
    }
    if (selected == null) {
      throw OfflineChapterMissingException(key, 'Offline chapter files are missing');
    }
    return OfflineComicChapterDetailModel.fromSnapshot(
      snapshot: selected,
      requested: key,
      rootDirectory: root,
    );
  }

  @override
  Future<List<ComicCommentEntity>> getComments({int page = 0}) => Future.error(
        UnsupportedError('Offline comic comments require a network source'),
      );

  @override
  Future<void> doInit() => loadComicHistory();
}

class OfflineComicChapterDetailModel extends BaseComicChapterDetailModel {
  final OfflineChapterSnapshot snapshot;
  final Directory rootDirectory;
  final OfflineChapterCommentsLoader? _commentsLoader;
  final ChapterProvenance _provenance;

  OfflineComicChapterDetailModel.fromSnapshot({
    required this.snapshot,
    required ChapterKey requested,
    required this.rootDirectory,
    OfflineChapterCommentsLoader? commentsLoader,
  })  : _commentsLoader = commentsLoader,
        _provenance = ChapterProvenance(
          requested: requested,
          actual: snapshot.key,
          isLocal: true,
        );

  String get actualSourceId => snapshot.key.sourceId;

  @override
  String get chapterId => _provenance.requested.chapterId;

  @override
  String get title => snapshot.rawTitle;
  @override
  String? get language => snapshot.language;

  @override
  List<ScanlationGroup> get scanlationGroups => snapshot.scanlationGroups;


  @override
  List<ImageEntity> get pages => [
        for (final page in snapshot.pages)
          ImageEntity(ImageType.local, _resolve(rootDirectory, page.relativePath).path),
      ];

  @override
  ChapterProvenance get provenance => _provenance;

  @override
  Future<List<ChapterCommentEntity>> getChapterComments() {
    final loader = _commentsLoader;
    if (loader == null) {
      throw OfflineCommentsUnavailableException(snapshot.key);
    }
    return loader(snapshot.key);
  }
}

class _OfflineComicSourceModel extends BaseComicSourceModel {
  final String sourceId;

  _OfflineComicSourceModel(this.sourceId);

  @override
  ComicSourceEntity get type => ComicSourceEntity(sourceId, sourceId);

  @override
  Future<BaseComicDetailModel?> getComicDetail(String comicId, String title) =>
      Future.error(
        StateError('Offline comic detail never initializes a remote source'),
      );

  @override
  Future<List<ComicListItemEntity>> searchComicDetail(
    String keyword, {
    int page = 0,
  }) async => const [];
}

File _resolve(Directory root, String relativePath) {
  final normalized = relativePath.replaceAll('\\', '/');
  if (normalized.startsWith('/') ||
      normalized.split('/').any((segment) => segment == '..')) {
    throw FormatException('Invalid offline relative path: $relativePath');
  }
  return File(
    '${root.path}${Platform.pathSeparator}'
    '${normalized.replaceAll('/', Platform.pathSeparator)}',
  );
}
