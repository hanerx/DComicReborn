import 'package:dcomic/downloads/comic_download_models.dart';
import 'package:dcomic/view/downloads/chapter_download_sheet.dart';
import 'package:dcomic/view/downloads/offline_comic_page.dart';
import 'package:dcomic/view/drawer_page/download_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chapter selection keeps explicit own-source downloads available', () {
    final selection = ChapterDownloadSelection(const ['chapter-1', 'chapter-2']);

    selection.toggle('chapter-1');
    expect(selection.selectedIds, {'chapter-1'});

    // An alternate completed version is informational. It must not disable an
    // explicit download of the requested source chapter.
    expect(selection.canSelect('chapter-1'), isTrue);

    selection.selectAll();
    expect(selection.selectedIds, {'chapter-1', 'chapter-2'});
    selection.clear();
    expect(selection.selectedIds, isEmpty);
  });

  test('partial transfer never receives a completed indicator', () {
    const key = (sourceId: 'source', comicId: 'comic', chapterId: 'chapter');
    const progress = OfflineChapterProgress(
      key: key,
      state: OfflineChapterState.downloading,
      completedPages: 2,
      totalPages: 5,
      bytesReceived: 200,
      totalBytes: 500,
    );

    final indicators = ChapterDownloadIndicators.from(
      progress: progress,
      ownComplete: false,
      alternateComplete: false,
    );


    expect(indicators.isPartial, isTrue);
    expect(indicators.isComplete, isFalse);
    expect(indicators.isActive, isTrue);
  });
  test('offline reader uses the same newest-to-oldest chapter order', () {
    final ordered = offlineReaderChapterOrder(const ['oldest', 'middle', 'newest']);

    expect(ordered, ['newest', 'middle', 'oldest']);
  });

  test('comic page retry refreshes the owning chapter manifest', () async {
    const chapter = (
      sourceId: 'source',
      comicId: 'comic',
      chapterId: 'chapter',
    );
    ChapterKey? refreshed;
    String? generic;
    final router = DownloadTaskActionRouter(
      chapterForTask: (taskId) async => chapter,
      resumeChapter: (key) async => refreshed = key,
      resumeGeneric: (taskId) async => generic = taskId,
    );

    await router.resume('page-task');

    expect(refreshed, chapter);
    expect(generic, isNull);
  });

  test('non-comic retry remains on the generic download service', () async {
    ChapterKey? refreshed;
    String? generic;
    final router = DownloadTaskActionRouter(
      chapterForTask: (taskId) async => null,
      resumeChapter: (key) async => refreshed = key,
      resumeGeneric: (taskId) async => generic = taskId,
    );

    await router.resume('update-task');

    expect(refreshed, isNull);
    expect(generic, 'update-task');
  });
}
