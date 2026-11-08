import 'dart:async';

import 'package:dcomic/providers/base_provider.dart';
import 'package:dcomic/providers/config_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:dcomic/utils/reader_image_precache.dart';

enum ChapterCommentLoadState {
  idle,
  loading,
  loaded,
  offlineUnavailable,
  failed,
}

class ComicViewerPageController extends BaseProvider {
  final BaseComicDetailModel detailModel;
  final List<BaseComicChapterEntityModel> chapters;
  final String initChapterId;
  BaseComicChapterEntityModel? currentChapter;
  BaseComicChapterDetailModel? chapterDetailModel;
  late final ReaderImagePrecache _precache = ReaderImagePrecache(
    onError: (error, stack) =>
        logger.w('Reader prefetch failed', error: error, stackTrace: stack),
  );
  List<ImageEntity> _precachePages = const [];
  int _precacheCount;
  int _chapterLoad = 0;
  int _chapterRevision = 0;

  /// Identifies an accepted chapter load, including reused cached objects.
  int get chapterRevision => _chapterRevision;
  bool _disposed = false;
  final bool resumeLastReadPage;

  // viewer参数
  int _currentPage = 0;
  bool _showToolBar = false;
  ReadDirectionType? _readDirection;

  ReadDirectionType effectiveReadDirection(ReadDirectionType preference) =>
      _readDirection ??
      (detailModel.isLongComic ? ReadDirectionType.vertical : preference);

  set readDirection(ReadDirectionType value) {
    if (_readDirection == value) return;
    _readDirection = value;
    notifyListeners();
  }

  // comment
  List<ChapterCommentEntity> _comments = [];

  List<ChapterCommentEntity> get comments => _comments;

  ChapterCommentLoadState _commentLoadState = ChapterCommentLoadState.idle;
  ChapterCommentLoadState get commentLoadState => _commentLoadState;

  Object? _commentError;
  Object? get commentError => _commentError;

  int get maxLikes => _comments.isNotEmpty
      ? _comments.first.likes > 100
            ? _comments.first.likes
            : 100
      : 0;

  ComicViewerPageController(
    this.detailModel,
    this.chapters,
    this.initChapterId, {
    required this._precacheCount,
    this.resumeLastReadPage = false,
  }) {
    final initialIndex = chapters.indexWhere(
      (chapter) => chapter.chapterId == initChapterId,
    );
    if (initialIndex >= 0) currentChapter = chapters[initialIndex];
  }

  set precacheCount(int value) {
    if (_precacheCount == value) return;
    _precacheCount = value;
    _updatePrecache();
  }

  void _updatePrecache() {
    if (_disposed || _precachePages.isEmpty) return;
    unawaited(
      _precache.update(
        pages: _precachePages,
        currentPage: _currentPage,
        count: _precacheCount,
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _chapterLoad++;
    _precache.clear();
    super.dispose();
  }

  BaseComicChapterEntityModel? get preChapter {
    final current = currentChapter;
    if (current == null) return null;
    final index = chapters.indexOf(current);
    return index > 0 ? chapters[index - 1] : null;
  }

  BaseComicChapterEntityModel? get nextChapter {
    final current = currentChapter;
    if (current == null) return null;
    final index = chapters.indexOf(current);
    return index >= 0 && index < chapters.length - 1
        ? chapters[index + 1]
        : null;
  }

  /// Returns false at the first chapter without reloading or resetting progress.
  Future<bool> refresh() async {
    final chapter = chapterDetailModel == null ? currentChapter : preChapter;
    if (chapter == null) return false;
    await loadChapter(chapter);
    return true;
  }

  /// Returns false at the latest chapter without reloading or resetting progress.
  Future<bool> load() async {
    final chapter = chapterDetailModel == null ? currentChapter : nextChapter;
    if (chapter == null) return false;
    await loadChapter(chapter);
    return true;
  }

  Future<void> loadChapter(BaseComicChapterEntityModel chapter) async {
    final load = ++_chapterLoad;
    _precache.clear();
    _precachePages = const [];
    _comments = const [];
    _commentLoadState = ChapterCommentLoadState.idle;
    _commentError = null;
    currentChapter = chapter;
    // Read before chapter-entry history can replace the previous position.
    final position = resumeLastReadPage && chapterDetailModel == null
        ? await detailModel.loadLocalReadingPosition()
        : null;
    if (_disposed || load != _chapterLoad) return;
    final detail = await detailModel.getChapter(chapter.chapterId);
    if (_disposed || load != _chapterLoad) return;
    chapterDetailModel = detail;
    _chapterRevision = load;
    _precachePages = detail?.pages ?? const [];
    _currentPage = position?.chapterId == chapter.chapterId &&
            detail != null &&
            detail.pages.isNotEmpty
        ? (position!.page - 1).clamp(0, detail.pages.length - 1)
        : 0;
    _updatePrecache();
    _commentLoadState = detail?.provenance?.isLocal == true
        ? ChapterCommentLoadState.offlineUnavailable
        : ChapterCommentLoadState.loading;
    notifyListeners();
    unawaited(addComicHistory());
    if (detail != null && detail.provenance?.isLocal != true) {
      unawaited(loadComment());
    }
  }

  Future<void> loadComment({bool explicit = false}) async {
    final chapter = chapterDetailModel;
    final load = _chapterLoad;
    if (chapter == null) return;
    if (chapter.provenance?.isLocal == true && !explicit) {
      _commentLoadState = ChapterCommentLoadState.offlineUnavailable;
      _commentError = null;
      if (!_disposed) notifyListeners();
      return;
    }
    _commentLoadState = ChapterCommentLoadState.loading;
    _commentError = null;
    if (!_disposed) notifyListeners();
    try {
      final comments = await chapter.getChapterComments();
      if (_disposed ||
          load != _chapterLoad ||
          !identical(chapter, chapterDetailModel)) {
        return;
      }
      _comments = comments;
      _commentLoadState = ChapterCommentLoadState.loaded;
    } catch (error) {
      if (_disposed ||
          load != _chapterLoad ||
          !identical(chapter, chapterDetailModel)) {
        return;
      }
      _commentError = error;
      _commentLoadState = ChapterCommentLoadState.failed;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> addComicHistory() async {
    if (currentChapter != null) {
      final imageCount = chapterDetailModel?.pages.length ?? 0;
      final page = imageCount > 0
          ? (_currentPage + 1).clamp(1, imageCount)
          : _currentPage + 1;
      await detailModel.addComicHistory(
        currentChapter!.chapterId,
        currentChapter!.rawTitle,
        page: page,
      );
    }
  }

  int get currentPage => _currentPage;

  set currentPage(int value) {
    if (value == _currentPage || value < 0) return;
    _currentPage = value;
    _updatePrecache();
    unawaited(addComicHistory());
    notifyListeners();
  }

  bool get showToolBar => _showToolBar;

  set showToolBar(bool value) {
    _showToolBar = value;
    notifyListeners();
  }

  String get title =>
      chapterDetailModel == null ? "title" : chapterDetailModel!.title;
}
