import 'dart:async';
import 'dart:io';

import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

ComicListItemEntity _searchHit(String title, String comicId) =>
    ComicListItemEntity(
        title, ImageEntity(ImageType.unknown, ''), {}, (_) {}, comicId);

/// Network-boundary fake: only [searchComicDetail] stands in for the network,
/// everything else (mapping storage) uses the real database.
class _FakeSource extends BaseComicSourceModel {
  _FakeSource(this.sourceId, {List<ComicListItemEntity> results = const []})
      : searchResults = results {
    addTearDown(dispose);
  }

  /// A source whose search hangs on a gate the test controls, for races
  /// between an in-flight auto-match and an explicit bind/delete.
  _FakeSource.gated(this.sourceId) : searchResults = const [] {
    searchGate = Completer<List<ComicListItemEntity>>();
    searchStarted = Completer<void>();
    addTearDown(dispose);
  }

  final String sourceId;
  final List<ComicListItemEntity> searchResults;

  /// When set, [searchComicDetail] throws it instead of returning results.
  Object? searchError;

  Completer<List<ComicListItemEntity>>? searchGate;

  /// Completes once [searchComicDetail] has been entered, which is only
  /// reachable after the mapping row lookup found nothing.
  Completer<void>? searchStarted;

  @override
  ComicSourceEntity get type => ComicSourceEntity(sourceId, sourceId);

  @override
  Future<BaseComicDetailModel?> getComicDetail(String comicId, String title) =>
      Future.value();

  @override
  Future<List<ComicListItemEntity>> searchComicDetail(String keyword,
      {int page = 0}) async {
    final started = searchStarted;
    if (started != null && !started.isCompleted) {
      started.complete();
    }
    final gate = searchGate;
    if (gate != null) {
      return await gate.future;
    }
    final error = searchError;
    if (error != null) {
      throw error;
    }
    return searchResults;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('comic_binding_');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(directory.path);
  });

  setUp(() async {
    await (await DatabaseInstance.instance)
        .database
        .delete('ComicMappingEntity');
  });

  tearDownAll(() async {
    await (await DatabaseInstance.instance).close();
    await directory.delete(recursive: true);
  });

  test('one binding can be used from either endpoint after reloading', () async {
    final copy = _FakeSource('copy');
    final zai = _FakeSource('zai');
    await zai.bindComicIdFromSourceModel('copy-book', 'zai-book', copy);
    final reloadedCopy = _FakeSource('copy')
      ..searchError = StateError('stored binding must work offline');
    final reloadedZai = _FakeSource('zai')
      ..searchError = StateError('stored binding must work offline');

    expect(await reloadedCopy.resolveComicId('zai-book', 'Different', zai),
        'copy-book');
    expect(await reloadedZai.resolveComicId('copy-book', 'Comic', copy),
        'zai-book');
  });

  test('unbinding from either endpoint removes the relationship for both',
      () async {
    final copy = _FakeSource('copy')
      ..searchError = StateError('explicit unbind must prevent search');
    final zai = _FakeSource('zai')
      ..searchError = StateError('explicit unbind must prevent search');
    await zai.bindComicIdFromSourceModel('copy-book', 'zai-book', copy);
    await copy.bindComicIdFromSourceModel('zai-book', '', zai);

    expect(await zai.resolveComicId('copy-book', 'Comic', copy), isNull);
    expect(await copy.resolveComicId('zai-book', 'Comic', zai), isNull);
    await zai.bindComicIdFromSourceModel('copy-book', 'zai-book', copy);
    expect(await copy.resolveComicId('zai-book', 'Comic', zai), 'copy-book');
    expect(await zai.resolveComicId('copy-book', 'Comic', copy), 'zai-book');
  });

  test('rebinding displaces the old relationship without resurrecting it',
      () async {
    final copy = _FakeSource('copy')
      ..searchError = StateError('displaced bindings must prevent search');
    final zai = _FakeSource('zai')
      ..searchError = StateError('existing bindings must prevent search');
    await zai.bindComicIdFromSourceModel('copy-book', 'old-zai', copy);
    await zai.bindComicIdFromSourceModel('copy-book', 'new-zai', copy);

    expect(await copy.resolveComicId('old-zai', 'Comic', zai), isNull);
    expect(await copy.resolveComicId('new-zai', 'Comic', zai), 'copy-book');
    expect(await zai.resolveComicId('copy-book', 'Comic', copy), 'new-zai');
  });

  test('a late automatic match cannot undo an unbind from the other endpoint',
      () async {
    final copy = _FakeSource('copy');
    final zai = _FakeSource.gated('zai');
    final pending = zai.resolveComicId('copy-book', 'Comic', copy);
    await zai.searchStarted!.future;
    await zai.bindComicIdFromSourceModel('copy-book', 'zai-book', copy);
    await copy.bindComicIdFromSourceModel('zai-book', '', zai);
    zai.searchGate!.complete([_searchHit('Comic', 'zai-book')]);

    expect(await pending, isNull);
    expect(await zai.resolveComicId('copy-book', 'Comic', copy), isNull);
  });

  test('an automatic match also creates one shared relationship', () async {
    final copy = _FakeSource('copy')
      ..searchError = StateError('automatic binding must be shared');
    final zai = _FakeSource('zai', results: [_searchHit('Comic', 'zai-book')]);

    expect(await zai.resolveComicId('copy-book', 'Comic', copy), 'zai-book');
    expect(await copy.resolveComicId('zai-book', 'Comic', zai), 'copy-book');
  });

  test('an automatic match cannot take an occupied counterpart', () async {
    final copy = _FakeSource('copy');
    final zai = _FakeSource.gated('zai');
    final pending = zai.resolveComicId('copy-book', 'Comic', copy);
    await zai.searchStarted!.future;
    await copy.bindComicIdFromSourceModel('zai-book', 'another-copy', zai);
    zai.searchGate!.complete([_searchHit('Comic', 'zai-book')]);

    expect(await pending, isNull);
    expect(await copy.resolveComicId('zai-book', 'Comic', zai), 'another-copy');
    expect(await zai.resolveComicId('another-copy', 'Comic', copy), 'zai-book');
  });

  test('an explicitly cleared binding stays unbound after loading again',
      () async {
    final origin = _FakeSource('origin');
    final target =
        _FakeSource('target', results: [_searchHit('Comic', 'auto-matched')]);
    await target.bindComicIdFromSourceModel('comic-1', '', origin);

    expect(await target.resolveComicId('comic-1', 'Comic', origin), isNull);

    final reloaded =
        _FakeSource('target', results: [_searchHit('Comic', 'auto-matched')]);
    expect(await reloaded.resolveComicId('comic-1', 'Comic', origin), isNull);
  });

  test('an explicit rebind after clearing recovers the binding', () async {
    final origin = _FakeSource('origin');
    final target = _FakeSource('target');
    await target.bindComicIdFromSourceModel('comic-2', '', origin);

    await target.bindComicIdFromSourceModel('comic-2', 'rebound-id', origin);

    expect(
        await target.resolveComicId('comic-2', 'Comic', origin), 'rebound-id');
  });

  test(
      'clearing one mapping leaves other books, other targets and the original id untouched',
      () async {
    final origin = _FakeSource('origin');
    final target = _FakeSource('target');
    final other = _FakeSource('other');
    await target.bindComicIdFromSourceModel('book-a', 'target-a', origin);
    await target.bindComicIdFromSourceModel('book-b', 'target-b', origin);
    await other.bindComicIdFromSourceModel('book-a', 'other-a', origin);

    await target.bindComicIdFromSourceModel('book-a', '', origin);

    expect(await target.resolveComicId('book-a', 'Book A', origin), isNull);
    expect(await target.resolveComicId('book-b', 'Book B', origin), 'target-b');
    expect(await other.resolveComicId('book-a', 'Book A', origin), 'other-a');
    expect(await origin.resolveComicId('book-a', 'Book A', origin), 'book-a');
  });

  test('same-source overrides and same-source unbind are honored', () async {
    final source = _FakeSource('main');
    final sibling = _FakeSource('main');
    await source.bindComicIdFromSourceModel('comic-4', 'override-id', source);

    expect(
        await sibling.resolveComicId('comic-4', 'Title', source), 'override-id',
        reason: 'a new instance of the same source must see the override');

    await source.bindComicIdFromSourceModel('comic-4', '', source);
    expect(await source.resolveComicId('comic-4', 'Title', source), isNull,
        reason: 'same-source unbind must not fall back to the original id');

    expect(await source.resolveComicId('fresh-4', 'Title', source), 'fresh-4');
    expect(await sibling.resolveComicId('fresh-4', 'Title', source), 'fresh-4',
        reason:
            'an absent same-source mapping must not persist an empty row that would unbind the next resolve');
  });

  test(
      'an absent cross-source mapping auto-matches by title and persists across source instances',
      () async {
    final origin = _FakeSource('origin');
    final target =
        _FakeSource('target', results: [_searchHit('Comic', 'auto-id')]);

    expect(await target.resolveComicId('comic-5', 'Comic', origin), 'auto-id');

    final reloaded =
        _FakeSource('target', results: [_searchHit('Comic', 'different-id')]);
    expect(
        await reloaded.resolveComicId('comic-5', 'Comic', origin), 'auto-id');
  });

  test(
      'traditional-Chinese search results still match a simplified-Chinese title',
      () async {
    final origin = _FakeSource('origin');
    final target = _FakeSource('target', results: [
      _searchHit('無關作品', 'noise-id'),
      _searchHit('斗羅大陸', 'zh-id'),
    ]);

    expect(await target.resolveComicId('comic-5b', '斗罗大陆', origin), 'zh-id');
  });

  test(
      'an unmatched auto-search stays transient instead of becoming a durable empty binding',
      () async {
    final origin = _FakeSource('origin');
    final target = _FakeSource('target');

    expect(await target.resolveComicId('comic-6', 'Comic', origin), isNull);

    final retry =
        _FakeSource('target', results: [_searchHit('Comic', 'late-id')]);
    expect(await retry.resolveComicId('comic-6', 'Comic', origin), 'late-id');
  });

  test(
      'a transport failure during auto-search propagates without persisting an empty binding',
      () async {
    final origin = _FakeSource('origin');
    final broken = _FakeSource('target')
      ..searchError = Exception('network unreachable');

    await expectLater(broken.resolveComicId('comic-7', 'Comic', origin),
        throwsA(isA<Exception>()));

    final retry =
        _FakeSource('target', results: [_searchHit('Comic', 'late-id')]);
    expect(await retry.resolveComicId('comic-7', 'Comic', origin), 'late-id');
  });

  test('a late auto-match cannot overwrite an explicit delete', () async {
    final origin = _FakeSource('origin');
    final target = _FakeSource.gated('target');

    final pending = target.resolveComicId('comic-8', 'Comic', origin);
    await target.searchStarted!.future;
    await target.bindComicIdFromSourceModel('comic-8', '', origin);
    target.searchGate!.complete([_searchHit('Comic', 'auto-id')]);
    await pending;

    final fresh =
        _FakeSource('target', results: [_searchHit('Comic', 'auto-id')]);
    expect(await fresh.resolveComicId('comic-8', 'Comic', origin), isNull,
        reason: 'the explicit delete must stay durable after the late match');
  });

  test('a late auto-match cannot overwrite an explicit rebind', () async {
    final origin = _FakeSource('origin');
    final target = _FakeSource.gated('target');

    final pending = target.resolveComicId('comic-9', 'Comic', origin);
    await target.searchStarted!.future;
    await target.bindComicIdFromSourceModel('comic-9', 'explicit-id', origin);
    target.searchGate!.complete([_searchHit('Comic', 'auto-id')]);
    await pending;

    final fresh = _FakeSource('target');
    expect(
        await fresh.resolveComicId('comic-9', 'Comic', origin), 'explicit-id');
  });
}
