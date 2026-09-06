import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/page_controllers/comic_search_dialog_controller.dart';
import 'package:dcomic/providers/page_controllers/comic_search_page_controller.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

class _SearchSource extends BaseComicSourceModel {
  _SearchSource(this.id, {this.failure}) {
    addTearDown(dispose);
  }
  final String id;
  Object? failure;
  final results = <String, List<ComicListItemEntity>>{};
  final pages = <int, List<ComicListItemEntity>>{};

  @override
  ComicSourceEntity get type => ComicSourceEntity(id, id);

  @override
  Future<BaseComicDetailModel?> getComicDetail(
          String comicId, String title) async =>
      null;

  @override
  Future<List<ComicListItemEntity>> searchComicDetail(String keyword,
      {int page = 0}) async {
    final error = failure;
    if (error != null) throw error;
    if (page > 0) return pages[page] ?? [];
    return results[keyword] ?? [];
  }
}

ComicListItemEntity _comic([String comicId = 'comic-id']) =>
    ComicListItemEntity(
        'Comic', ImageEntity(ImageType.unknown, ''), {}, (_) {}, comicId);

void main() {
  test('one failed source does not hide results from a healthy source',
      () async {
    final failed =
        _SearchSource('failed', failure: StateError('Service rejected search'));
    final healthy = _SearchSource('healthy')..results['Comic'] = [_comic()];
    final controller = ComicSearchPageController([failed, healthy])
      ..logger = Logger(output: ConsoleOutput())
      ..pendingKeyword = 'Comic';
    addTearDown(controller.dispose);

    await controller.search();

    expect(
        controller.data[healthy]!.data.map((entry) => entry.title), ['Comic']);
    expect(controller.data[failed]!.hasError, isTrue);
    expect(controller.data[healthy]!.hasError, isFalse);
  });

  test('binding search keeps the initial comic title when submitted unchanged',
      () async {
    final source = _SearchSource('source')..results['Comic'] = [_comic()];
    final controller = ComicSearchDialogController(source, 'Comic')
      ..logger = Logger(output: ConsoleOutput());
    addTearDown(controller.dispose);

    await controller.search();

    expect(controller.data.map((entry) => entry.comicId), ['comic-id']);
  });

  test('binding search can retry after a source failure', () async {
    final source = _SearchSource('source', failure: StateError('Unavailable'))
      ..results['Comic'] = [_comic()];
    final controller = ComicSearchDialogController(source, 'Comic')
      ..logger = Logger(output: ConsoleOutput());
    addTearDown(controller.dispose);

    await controller.refresh();
    expect(controller.hasError, isTrue);
    source.failure = null;
    await controller.refresh();

    expect(controller.hasError, isFalse);
    expect(controller.data.map((entry) => entry.comicId), ['comic-id']);
  });

  test('retrying a failed binding search page does not skip results', () async {
    final source = _SearchSource('source')
      ..results['Comic'] = [_comic('first')]
      ..pages[1] = [_comic('second')]
      ..pages[2] = [_comic('third')];
    final controller = ComicSearchDialogController(source, 'Comic')
      ..logger = Logger(output: ConsoleOutput());
    addTearDown(controller.dispose);
    await controller.refresh();

    source.failure = StateError('Page unavailable');
    await controller.load();
    expect(controller.hasError, isTrue);
    source.failure = null;
    await controller.load();

    expect(controller.hasError, isFalse);
    expect(controller.data.map((entry) => entry.comicId), ['first', 'second']);
  });
}
