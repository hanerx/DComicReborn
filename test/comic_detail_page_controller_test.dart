import 'dart:async';
import 'dart:io';

import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/page_controllers/comic_detail_page_controller.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

ComicListItemEntity _searchHit(String title, String comicId) =>
    ComicListItemEntity(
        title, ImageEntity(ImageType.unknown, ''), {}, (_) {}, comicId);

// Only network data is simulated; binding persistence and controller transitions
// exercise the production implementations.
class _FakeDetail extends BaseComicDetailModel {
  _FakeDetail(
      {required this.parentSource,
      this.detailId = 'detail-id',
      this.detailTitle = 'Detail Title'}) {
    addTearDown(dispose);
  }

  final BaseComicSourceModel parentSource;
  final String detailId;
  final String detailTitle;

  @override
  Future<void> doInit() => SynchronousFuture<void>(null);

  @override
  String get comicId => detailId;

  @override
  String get title => detailTitle;

  @override
  BaseComicSourceModel get parent => parentSource;

  @override
  ImageEntity get cover => ImageEntity(ImageType.unknown, '');

  @override
  DateTime get lastUpdate => DateTime(2024, 1, 1);

  @override
  Map<String, List<BaseComicChapterEntityModel>> get chapters => {};

  @override
  String get description => 'description';

  @override
  String get status => 'ongoing';

  @override
  List<CategoryEntity> get authors => [];

  @override
  List<CategoryEntity> get categories => [];

  @override
  Future<BaseComicChapterDetailModel?> getChapter(String chapterId) async =>
      null;

  @override
  Future<List<ComicCommentEntity>> getComments({int page = 0}) async => [];
}

class _UnparsedDetail extends _FakeDetail {
  _UnparsedDetail(BaseComicSourceModel source, String comicId)
      : super(parentSource: source, detailId: comicId);

  @override
  String get description => <String, dynamic>{}['description'];
}

/// Network-boundary fake: search and detail fetching are simulated, mapping
/// storage and the controller under test are the real ones.
class _FakeSource extends BaseComicSourceModel {
  _FakeSource(this.sourceId,
      {List<ComicListItemEntity> results = const [], this.detailError})
      : searchResults = results {
    addTearDown(dispose);
  }

  // Create gates inside runAsync, not the widget test's fake async zone.
  void pauseDetails() {
    detailGate = Completer<BaseComicDetailModel?>();
    detailStarted = Completer<void>();
  }

  final String sourceId;
  final List<ComicListItemEntity> searchResults;

  /// Detail returned by [getComicDetail]; mutable so it can reference the
  /// source itself as its parent.
  BaseComicDetailModel? detail;

  /// When set, [getComicDetail] throws it instead of returning a detail.
  final Object? detailError;

  /// When set, [searchComicDetail] throws it instead of returning results,
  /// so resolution itself fails with a transport error.
  Object? searchError;

  Completer<BaseComicDetailModel?>? detailGate;

  /// Completes once [getComicDetail] has been entered.
  Completer<void>? detailStarted;

  @override
  ComicSourceEntity get type => ComicSourceEntity(sourceId, sourceId);

  @override
  Future<BaseComicDetailModel?> getComicDetail(
      String comicId, String title) async {
    final started = detailStarted;
    if (started != null && !started.isCompleted) {
      started.complete();
    }
    final gate = detailGate;
    if (gate != null) {
      return await gate.future;
    }
    final error = detailError;
    if (error != null) {
      throw error;
    }
    final result = detail;
    return result?.comicId == comicId ? result : null;
  }

  @override
  Future<List<ComicListItemEntity>> searchComicDetail(String keyword,
      {int page = 0}) async {
    final error = searchError;
    if (error != null) {
      throw error;
    }
    return searchResults;
  }
}

/// Avoids the real provider startup (config writes, source initModel).
class _FakeSourceProvider extends ComicSourceProvider {
  _FakeSourceProvider(List<BaseComicSourceModel> models) {
    sources = models;
    addTearDown(dispose);
  }

  @override
  Future<void> init() async {}
}

ComicDetailPageController _controller(BaseComicSourceModel? source) {
  final controller = ComicDetailPageController(source)
    ..logger = Logger(output: ConsoleOutput());
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  BuildContext? hostContext;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('detail_controller_');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(directory.path);
  });

  tearDownAll(() async {
    await (await DatabaseInstance.instance).close();
    await directory.delete(recursive: true);
  });

  Future<void> pumpHost(WidgetTester tester, ComicSourceProvider provider) =>
      tester.pumpWidget(ChangeNotifierProvider<ComicSourceProvider>.value(
        value: provider,
        child: Builder(builder: (context) {
          hostContext = context;
          return const SizedBox();
        }),
      ));

  testWidgets('a missing binding enters the shared error state',
      (tester) async {
    final origin = _FakeSource('origin');
    final target = _FakeSource('target');
    final provider = _FakeSourceProvider([origin, target]);
    await pumpHost(tester, provider);
    final context = hostContext!;
    final controller = _controller(origin);

    await tester.runAsync(() async {
      controller.comicSourceModel = target;
      await controller.refresh(context, 'comic-t1', 'Requested Title');
    });

    expect(controller.loadState, ComicDetailLoadState.error);
    expect(controller.boundComicId, isNull);
    expect(controller.detailModel, isNull);
    expect(controller.isLoading, isFalse);
    expect(controller.loadError, isA<StateError>());
    expect(controller.title, 'Requested Title');
    expect(provider.activeModel, same(target),
        reason: 'viewing a comic keeps the app-wide source in sync');
  });

  testWidgets('an auto-matched binding loads the matched target detail',
      (tester) async {
    final origin = _FakeSource('origin');
    final working = _FakeSource('target',
        results: [_searchHit('Requested Title', 'matched-id')]);
    working.detail = _FakeDetail(parentSource: working, detailId: 'matched-id');
    final provider = _FakeSourceProvider([origin, working]);
    await pumpHost(tester, provider);
    final context = hostContext!;
    final controller = _controller(origin);

    await tester.runAsync(() async {
      controller.comicSourceModel = working;
      await controller.refresh(context, 'comic-t2', 'Requested Title');
    });

    expect(controller.loadState, ComicDetailLoadState.ready);
    expect(controller.boundComicId, 'matched-id');
    expect(controller.comicId, 'matched-id',
        reason: 'the detail must be fetched for the resolved id');
    expect(controller.isLoading, isFalse);
    expect(controller.canUnbind, isTrue);
  });

  testWidgets(
      'a bound source returning no detail keeps its binding in the error state',
      (tester) async {
    final origin = _FakeSource('origin');
    final target = _FakeSource('target');
    final provider = _FakeSourceProvider([origin, target]);
    await pumpHost(tester, provider);
    final context = hostContext!;
    final controller = _controller(origin);

    await tester.runAsync(() async {
      await target.bindComicIdFromSourceModel('comic-t3', 'bound-id', origin);
      controller.comicSourceModel = target;
      await controller.refresh(context, 'comic-t3', 'Requested Title');
    });

    expect(controller.loadState, ComicDetailLoadState.error);
    expect(controller.boundComicId, 'bound-id');
    expect(controller.detailModel, isNull);
    expect(controller.comments, isEmpty);
    expect(controller.isLoading, isFalse);
    expect(controller.title, 'Requested Title');
  });

  testWidgets('request failures retain the original error for presentation',
      (tester) async {
    final origin = _FakeSource('origin');
    final target = _FakeSource('t4-target',
        results: [_searchHit('Requested Title', 'matched-t4')],
        detailError: DioException(
            requestOptions: RequestOptions(path: '/detail'),
            error: const FormatException('malformed response')));
    final provider = _FakeSourceProvider([origin, target]);
    await pumpHost(tester, provider);
    final context = hostContext!;
    final controller = _controller(origin);

    await tester.runAsync(() async {
      controller.comicSourceModel = target;
      await controller.refresh(context, 'comic-t4', 'Requested Title');
    });

    expect(controller.loadState, ComicDetailLoadState.error);
    expect(controller.boundComicId, 'matched-t4');
    expect(controller.isLoading, isFalse);
    expect(controller.loadError, same(target.detailError));
  });

  testWidgets('lazy parsing failures enter the shared error state',
      (tester) async {
    final origin = _FakeSource('origin');
    final target = _FakeSource('t7-target',
        results: [_searchHit('Requested Title', 'matched-t7')]);
    target.detail = _UnparsedDetail(target, 'matched-t7');
    final provider = _FakeSourceProvider([origin, target]);
    await pumpHost(tester, provider);
    final context = hostContext!;
    final controller = _controller(origin);

    await tester.runAsync(() async {
      controller.comicSourceModel = target;
      await controller.refresh(context, 'comic-t7', 'Requested Title');
    });

    expect(controller.loadState, ComicDetailLoadState.error);
    expect(controller.isLoading, isFalse);
    expect(controller.loadError, isA<TypeError>());
  });

  testWidgets(
      'a failed load preserves the book title and can recover by rebinding',
      (tester) async {
    final origin = _FakeSource('origin');
    final broken = _FakeSource('broken',
        results: [_searchHit('Origin Title', 'any-id')],
        detailError: Exception('offline'));
    final working = _FakeSource('working',
        results: [_searchHit('Origin Title', 'fixed-id')]);
    working.detail = _FakeDetail(
        parentSource: working,
        detailId: 'fixed-id',
        detailTitle: 'Recovered Comic');
    final provider = _FakeSourceProvider([origin, broken, working]);
    await pumpHost(tester, provider);
    final context = hostContext!;
    final controller = _controller(origin);

    await tester.runAsync(() async {
      controller.comicSourceModel = broken;
      await controller.refresh(context, 'comic-t8', 'Origin Title');
      expect(controller.loadState, ComicDetailLoadState.error);
      expect(controller.title, 'Origin Title');

      controller.comicSourceModel = working;
      await controller.bindComicId('comic-t8', 'fixed-id');
    });

    expect(controller.loadState, ComicDetailLoadState.ready);
    expect(controller.loadError, isNull);
    expect(controller.boundComicId, 'fixed-id');
    expect(controller.title, 'Recovered Comic');
  });

  testWidgets(
      'a bind failure enters the error state instead of an endless spinner',
      (tester) async {
    final origin = _FakeSource('origin');
    final target = _FakeSource('target');
    final failing = _FakeSource('failing',
        results: [_searchHit('Requested Title', 'bind-target')],
        detailError: Exception('offline'));
    final provider = _FakeSourceProvider([origin, target, failing]);
    await pumpHost(tester, provider);
    final context = hostContext!;
    final controller = _controller(origin);

    await tester.runAsync(() async {
      controller.comicSourceModel = target;
      await controller.refresh(context, 'comic-t9', 'Requested Title');
      expect(controller.loadState, ComicDetailLoadState.error);

      controller.comicSourceModel = failing;
      await controller.bindComicId('comic-t9', 'bind-target');
    });

    expect(controller.loadState, ComicDetailLoadState.error);
    expect(controller.boundComicId, 'bind-target');
    expect(controller.isLoading, isFalse);
  });

  testWidgets(
      'a resolve failure on a switched source never keeps the old source binding',
      (tester) async {
    final origin = _FakeSource('origin');
    final good = _FakeSource('good', results: [_searchHit('Title', 'old-id')]);
    good.detail = _FakeDetail(parentSource: good, detailId: 'old-id');
    final failing = _FakeSource('failing')..searchError = Exception('offline');
    final provider = _FakeSourceProvider([origin, good, failing]);
    await pumpHost(tester, provider);
    final context = hostContext!;
    final controller = _controller(origin);

    await tester.runAsync(() async {
      controller.comicSourceModel = good;
      await controller.refresh(context, 'comic-t14', 'Title');
      expect(controller.loadState, ComicDetailLoadState.ready);
      expect(controller.boundComicId, 'old-id');

      controller.comicSourceModel = failing;
      await controller.refresh(context, 'comic-t14', 'Title');
    });

    expect(controller.loadState, ComicDetailLoadState.error);
    expect(controller.boundComicId, isNull,
        reason: 'a failed resolve must not leak the previous source binding');
    expect(controller.canUnbind, isFalse);
    expect(controller.title, 'Title');
  });

  testWidgets('a stale request error cannot replace a newer successful source',
      (tester) async {
    final origin = _FakeSource('origin');
    final oldSource =
        _FakeSource('old', results: [_searchHit('Title', 'old-id')]);
    final newSource =
        _FakeSource('new', results: [_searchHit('Title', 'new-id')]);
    newSource.detail = _FakeDetail(parentSource: newSource, detailId: 'new-id');
    final provider = _FakeSourceProvider([origin, oldSource, newSource]);
    await pumpHost(tester, provider);
    final context = hostContext!;
    final controller = _controller(origin);

    await tester.runAsync(() async {
      oldSource.pauseDetails();
      controller.comicSourceModel = oldSource;
      final stale = controller.refresh(context, 'comic-t10', 'Title');
      await oldSource.detailStarted!.future;
      controller.comicSourceModel = newSource;
      await controller.refresh(context, 'comic-t10', 'Title');
      expect(controller.comicId, 'new-id');

      oldSource.detailGate!.completeError(StateError('Old source failed'));
      await stale;
    });

    expect(controller.loadState, ComicDetailLoadState.ready);
    expect(controller.loadError, isNull);
    expect(controller.comicId, 'new-id');
    expect(controller.comicSourceModel, same(newSource));
  });

  testWidgets('unbind cancels the pending detail and cannot be undone by it',
      (tester) async {
    final origin = _FakeSource('origin');
    final target =
        _FakeSource('target', results: [_searchHit('Title', 'bound-id')]);
    final provider = _FakeSourceProvider([origin, target]);
    await pumpHost(tester, provider);
    final context = hostContext!;
    final controller = _controller(origin);

    await tester.runAsync(() async {
      target.pauseDetails();
      controller.comicSourceModel = target;
      final pending = controller.refresh(context, 'comic-t11', 'Title');
      await target.detailStarted!.future;

      await controller.unbindComicId('comic-t11');
      expect(controller.loadState, ComicDetailLoadState.error);
      expect(controller.boundComicId, isNull);
      expect(controller.canUnbind, isFalse);
      expect(controller.detailModel, isNull);

      target.detailGate!
          .complete(_FakeDetail(parentSource: target, detailId: 'bound-id'));
      await pending;
      await controller.refresh(context, 'comic-t11', 'Title');
    });

    expect(controller.loadState, ComicDetailLoadState.error);
    expect(controller.detailModel, isNull);
  });

  testWidgets('disposal drops late completions safely', (tester) async {
    final origin = _FakeSource('origin');
    final target =
        _FakeSource('target', results: [_searchHit('Title', 'bound-id')]);
    final provider = _FakeSourceProvider([origin, target]);
    await pumpHost(tester, provider);
    final context = hostContext!;
    final controller = ComicDetailPageController(origin)
      ..logger = Logger(output: ConsoleOutput());

    await tester.runAsync(() async {
      target.pauseDetails();
      controller.comicSourceModel = target;
      final pending = controller.refresh(context, 'comic-t12', 'Title');
      await target.detailStarted!.future;

      controller.dispose();
      target.detailGate!
          .complete(_FakeDetail(parentSource: target, detailId: 'bound-id'));
      await pending;
    });

    expect(controller.detailModel, isNull,
        reason: 'late results must not publish a detail after disposal');
  });

  testWidgets(
      'the origin captured on the first refresh survives source switches',
      (tester) async {
    final origin = _FakeSource('origin');
    origin.detail = _FakeDetail(parentSource: origin, detailId: 'comic-t13');
    final later =
        _FakeSource('later', results: [_searchHit('Title', 'later-id')]);
    later.detail = _FakeDetail(parentSource: later, detailId: 'later-id');
    final provider = _FakeSourceProvider([origin, later]);
    await pumpHost(tester, provider);
    final context = hostContext!;
    final controller = _controller(null);

    await tester.runAsync(() async {
      await controller.refresh(context, 'comic-t13', 'Title');
      expect(controller.loadState, ComicDetailLoadState.ready);

      controller.comicSourceModel = later;
      await controller.refresh(context, 'comic-t13', 'Title');
    });

    expect(controller.sourceModel, same(origin),
        reason: 'switching sources must not rewrite the mapping origin');
    expect(controller.boundComicId, 'later-id');
  });
}
