import 'dart:async';

import 'package:dcomic/providers/base_provider.dart';
import 'package:dcomic/providers/config_provider.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:dcomic/utils/reader_image_precache.dart';

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
    if (chapters.indexWhere((element) => element.chapterId == initChapterId) >=
        0) {
      currentChapter =
          chapters[chapters.indexWhere(
            (element) => element.chapterId == initChapterId,
          )];
    }
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

  BaseComicChapterEntityModel? get preChapter =>
      currentChapter != null && chapters.indexOf(currentChapter!) > 0
      ? chapters[chapters.indexOf(currentChapter!) - 1]
      : null;

  BaseComicChapterEntityModel? get nextChapter =>
      currentChapter != null &&
          chapters.indexOf(currentChapter!) < chapters.length - 1
      ? chapters[chapters.indexOf(currentChapter!) + 1]
      : null;

  /// Returns false at the first chapter without reloading or resetting progress.
  Future<bool> refresh() async {
    final chapter = chapterDetailModel == null ? currentChapter! : preChapter;
    if (chapter == null) return false;
    await loadChapter(chapter);
    return true;
  }

  /// Returns false at the latest chapter without reloading or resetting progress.
  Future<bool> load() async {
    final chapter = chapterDetailModel == null ? currentChapter! : nextChapter;
    if (chapter == null) return false;
    await loadChapter(chapter);
    return true;
  }

  Future<void> loadChapter(BaseComicChapterEntityModel chapter) async {
    final load = ++_chapterLoad;
    _precache.clear();
    _precachePages = const [];
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
    await loadComment();
    if (_disposed || load != _chapterLoad) return;
    unawaited(addComicHistory());
    notifyListeners();
  }

  Future<void> loadComment() async {
    final chapter = chapterDetailModel;
    final load = _chapterLoad;
    if (chapter != null) {
      final comments = await chapter.getChapterComments();
      if (_disposed || load != _chapterLoad) return;
      _comments = comments;
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
