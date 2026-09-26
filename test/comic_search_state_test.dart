import 'dart:async';

import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/page_controllers/comic_search_page_controller.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

class _Request {
  _Request(this.query, this.page);
  final String query;
  final int page;
  final result = Completer<List<ComicListItemEntity>>();
}

class _Source extends BaseComicSourceModel {
  final requests = <_Request>[];

  @override
  Future<BaseComicDetailModel?> getComicDetail(
    String comicId,
    String title,
  ) async => null;

  @override
  Future<List<ComicListItemEntity>> searchComicDetail(
    String keyword, {
    int page = 0,
  }) {
    final request = _Request(keyword, page);
    requests.add(request);
    return request.result.future;
  }
}

ComicListItemEntity _comic(String id) =>
    ComicListItemEntity(id, ImageEntity(ImageType.unknown, ''), {}, (_) {}, id);

void main() {
  late _Source source;
  late ComicSearchPageController controller;

  setUp(() {
    source = _Source();
    controller = ComicSearchPageController([source])
      ..logger = Logger(output: ConsoleOutput());
  });

  tearDown(() {
    controller.dispose();
    source.dispose();
  });

  Future<void> firstPage() async {
    controller.pendingKeyword = 'comic';
    final search = controller.search();
    source.requests.last.result.complete([_comic('first')]);
    await search;
  }

  test('a slow source does not block other sources', () async {
    final other = _Source();
    addTearDown(other.dispose);
    final multi = ComicSearchPageController([source, other]);
    addTearDown(multi.dispose);
    multi.pendingKeyword = 'comic';
    final pending = multi.search();
    expect(other.requests, hasLength(1));
    other.requests.single.result.complete([_comic('fast')]);
    await Future<void>.delayed(Duration.zero);
    expect(multi.data[other]!.data.single.title, 'fast');
    source.requests.single.result.complete([]);
    await pending;
  });

  test(
    'refresh preserves visible results until replacement succeeds',
    () async {
      await firstPage();
      final refresh = controller.refresh(source);
      expect(controller.data[source]!.data.single.title, 'first');
      source.requests.last.result.completeError(StateError('offline'));
      await refresh;
      expect(controller.data[source]!.data.single.title, 'first');
      expect(controller.data[source]!.hasError, isTrue);
      final retry = controller.refresh(source);
      expect(source.requests.last.page, 0);
      source.requests.last.result.complete([_comic('replacement')]);
      await retry;
      expect(controller.data[source]!.data.single.title, 'replacement');
    },
  );

  test(
    'overlapping loads do not duplicate requests or skip failed pages',
    () async {
      await firstPage();
      final load = controller.load(source);
      final duplicate = controller.load(source);
      expect(source.requests, hasLength(2));
      source.requests.last.result.completeError(StateError('offline'));
      await Future.wait([load, duplicate]);
      final retry = controller.load(source);
      expect(source.requests.last.page, 1);
      source.requests.last.result.complete([_comic('second')]);
      await retry;
      expect(controller.data[source]!.data.map((e) => e.title), [
        'first',
        'second',
      ]);
    },
  );

  test('an empty page stops pagination until explicit refresh', () async {
    await firstPage();
    final load = controller.load(source);
    source.requests.last.result.complete([]);
    await load;
    await controller.load(source);
    expect(source.requests, hasLength(2));
  });

  test(
    'queries are trimmed and duplicate submission does not refresh',
    () async {
      controller.pendingKeyword = '  comic  ';
      final search = controller.search();
      expect(source.requests.single.query, 'comic');
      source.requests.single.result.complete([_comic('first')]);
      await search;
      await controller.search();
      expect(source.requests, hasLength(1));
    },
  );

  test(
    'whitespace submission clears results without making a request',
    () async {
      await firstPage();
      controller.pendingKeyword = '   ';
      await controller.search();
      expect(controller.keyword, isEmpty);
      expect(controller.data[source]!.data, isEmpty);
      expect(source.requests, hasLength(1));
    },
  );

  test('new query cannot be overwritten by an older result', () async {
    controller.pendingKeyword = 'old';
    final old = controller.search();
    controller.pendingKeyword = 'new';
    final current = controller.search();
    source.requests[1].result.complete([_comic('new')]);
    await current;
    source.requests[0].result.complete([_comic('old')]);
    await old;
    expect(controller.data[source]!.data.single.title, 'new');
  });

  test(
    'returning to an earlier query still rejects its original request',
    () async {
      controller.pendingKeyword = 'A';
      final first = controller.search();
      controller.pendingKeyword = 'B';
      final middle = controller.search();
      controller.pendingKeyword = 'A';
      final last = controller.search();
      source.requests[2].result.complete([_comic('latest-A')]);
      await last;
      source.requests[0].result.complete([_comic('stale-A')]);
      source.requests[1].result.complete([_comic('stale-B')]);
      await Future.wait([first, middle]);
      expect(controller.data[source]!.data.single.title, 'latest-A');
    },
  );

  test('clearing during a request keeps the landing state empty', () async {
    controller.pendingKeyword = 'comic';
    final search = controller.search();
    controller.clear();
    source.requests.single.result.complete([_comic('stale')]);
    await search;
    expect(controller.keyword, isEmpty);
    expect(controller.data[source]!.data, isEmpty);
    expect(controller.data[source]!.isLoading, isFalse);
    expect(controller.data[source]!.hasSearched, isFalse);
  });
}
