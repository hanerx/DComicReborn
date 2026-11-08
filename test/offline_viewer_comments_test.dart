import 'dart:async';

import 'package:dcomic/downloads/comic_download_models.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/page_controllers/comic_viewer_page_controller.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(BaseComicDetailModel.clearOfflineResolverForTest);

  test('local pages publish without requesting or awaiting online comments', () async {
    final detail = _Detail();
    final local = _LocalChapter();
    BaseComicDetailModel.installOfflineResolver((_, __) async => local);
    final chapter = DefaultComicChapterEntityModel(
      'Chapter 1',
      'requested',
      DateTime(2026),
    );
    final controller = ComicViewerPageController(
      detail,
      [chapter],
      chapter.chapterId,
      precacheCount: 0,
    );
    addTearDown(controller.dispose);

    await controller.loadChapter(chapter);

    expect(controller.chapterDetailModel, same(local));
    expect(controller.chapterDetailModel!.pages.single.imageType, ImageType.local);
    expect(local.commentRequests, 0);
    expect(controller.commentLoadState, ChapterCommentLoadState.offlineUnavailable);
    expect(detail.remoteRequests, 0);
    expect(detail.savedChapterId, 'requested');
  });

}

class _LocalChapter extends BaseComicChapterDetailModel {
  int commentRequests = 0;
  @override
  String get chapterId => 'requested';
  @override
  String get title => 'Local';
  @override
  List<ImageEntity> get pages => [ImageEntity(ImageType.local, 'local.jpg')];
  @override
  ChapterProvenance get provenance => const ChapterProvenance(
        requested: (sourceId: 'a', comicId: 'book-a', chapterId: 'requested'),
        actual: (sourceId: 'b', comicId: 'book-b', chapterId: 'actual'),
        isLocal: true,
      );
  @override
  Future<List<ChapterCommentEntity>> getChapterComments() {
    commentRequests++;
    return Completer<List<ChapterCommentEntity>>().future;
  }
}

class _Detail extends BaseComicDetailModel {
  int remoteRequests = 0;
  String? savedChapterId;
  final BaseComicSourceModel _source = _Source();
  @override
  Future<void> doInit() async {}
  @override
  BaseComicSourceModel get parent => _source;
  @override
  String get comicId => 'book-a';
  @override
  String get title => 'Book';
  @override
  ImageEntity get cover => ImageEntity(ImageType.network, 'https://cover');
  @override
  DateTime get lastUpdate => DateTime(2026);
  @override
  Map<String, List<BaseComicChapterEntityModel>> get chapters => const {};
  @override
  String get description => '';
  @override
  String get status => '';
  @override
  List<CategoryEntity> get authors => const [];
  @override
  List<CategoryEntity> get categories => const [];
  @override
  Future<BaseComicChapterDetailModel?> fetchRemoteChapter(String chapterId) async {
    remoteRequests++;
    return null;
  }
  @override
  Future<List<ComicCommentEntity>> getComments({int page = 0}) async => const [];
  @override
  Future<bool> addComicHistory(
    String chapterId,
    String chapterName, {
    int page = 1,
  }) async {
    savedChapterId = chapterId;
    return true;
  }
}

class _Source extends BaseComicSourceModel {
  @override
  ComicSourceEntity get type => ComicSourceEntity('A', 'a');
  @override
  Future<BaseComicDetailModel?> getComicDetail(String comicId, String title) async =>
      null;
  @override
  Future<List<ComicListItemEntity>> searchComicDetail(
    String keyword, {
    int page = 0,
  }) async => const [];
}
