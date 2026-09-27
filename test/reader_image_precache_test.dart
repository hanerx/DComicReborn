import 'dart:async';
import 'dart:io';

import 'package:dcomic/utils/image_utils.dart';
import 'package:dcomic/utils/reader_image_precache.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

class _CachedFile extends Fake implements FileInfo {}

class _Cache extends Fake implements BaseCacheManager {
  final downloaded = <String>[];
  final cached = <String, FileInfo>{};
  final started = <String, Completer<void>>{};
  final blocked = <String, Completer<void>>{};
  final failed = <String>{};
  final headers = <String, Map<String, String>?>{};

  @override
  Future<FileInfo?> getFileFromCache(
    String key, {
    bool ignoreMemCache = false,
  }) async => cached[key];

  @override
  Future<FileInfo> downloadFile(
    String url, {
    String? key,
    Map<String, String>? authHeaders,
    bool force = false,
  }) async {
    downloaded.add(url);
    headers[url] = authHeaders;
    started[url]?.complete();
    await blocked[url]?.future;
    if (failed.contains(url)) throw const HttpException('diagnostic failure');
    return cached[url] = _CachedFile();
  }
}

List<ImageEntity> _pages(String chapter, int count) => List.generate(
  count,
  (i) => ImageEntity(
    ImageType.network,
    '$chapter/$i',
    imageHeaders: {'Referer': chapter},
  ),
);

void main() {
  test(
    'finite window follows jumps, reuses cache, and excludes comments',
    () async {
      final cache = _Cache();
      final errors = <Object>[];
      final loader = ReaderImagePrecache(
        cacheManager: cache,
        onError: (e, _) => errors.add(e),
      );
      final pages = _pages('a', 10);
      await loader.update(pages: pages, currentPage: 0, count: 2);
      expect(cache.downloaded, ['a/0', 'a/1', 'a/2']);
      await loader.update(pages: pages, currentPage: 6, count: 2);
      expect(cache.downloaded, ['a/0', 'a/1', 'a/2', 'a/6', 'a/7', 'a/8']);
      await loader.update(pages: pages, currentPage: 1, count: 1);
      expect(cache.downloaded, ['a/0', 'a/1', 'a/2', 'a/6', 'a/7', 'a/8']);
      await loader.update(pages: pages, currentPage: 9, count: 9);
      expect(cache.downloaded.last, 'a/9');
      final beforeComments = List.of(cache.downloaded);
      await loader.update(pages: pages, currentPage: 10, count: 2);
      expect(cache.downloaded, beforeComments);
      expect(cache.headers['a/6'], {'Referer': 'a'});
      expect(errors, isEmpty);
    },
  );

  test(
    'whole chapter starts at current page and also downloads earlier pages',
    () async {
      final cache = _Cache();
      final loader = ReaderImagePrecache(
        cacheManager: cache,
        onError: (e, s) => fail('$e'),
      );
      await loader.update(pages: _pages('a', 5), currentPage: 3, count: 0);
      expect(cache.downloaded, ['a/3', 'a/4', 'a/0', 'a/1', 'a/2']);
    },
  );

  test(
    'jump and count change replace pending work while one download finishes',
    () async {
      final cache = _Cache();
      cache.started['a/0'] = Completer<void>();
      cache.blocked['a/0'] = Completer<void>();
      final loader = ReaderImagePrecache(
        cacheManager: cache,
        onError: (e, s) => fail('$e'),
      );
      final pages = _pages('a', 10);
      final first = loader.update(pages: pages, currentPage: 0, count: 0);
      await cache.started['a/0']!.future;
      final next = loader.update(pages: pages, currentPage: 7, count: 1);
      cache.blocked['a/0']!.complete();
      await Future.wait([first, next]);
      expect(cache.downloaded, ['a/0', 'a/7', 'a/8']);
    },
  );

  test('chapter switch and exit stop old pending downloads', () async {
    final cache = _Cache();
    cache.started['a/0'] = Completer<void>();
    cache.blocked['a/0'] = Completer<void>();
    final loader = ReaderImagePrecache(
      cacheManager: cache,
      onError: (e, s) => fail('$e'),
    );
    final first = loader.update(
      pages: _pages('a', 5),
      currentPage: 0,
      count: 0,
    );
    await cache.started['a/0']!.future;
    final next = loader.update(pages: _pages('b', 3), currentPage: 0, count: 1);
    cache.blocked['a/0']!.complete();
    await Future.wait([first, next]);
    expect(cache.downloaded, ['a/0', 'b/0', 'b/1']);

    cache.started['c/0'] = Completer<void>();
    cache.blocked['c/0'] = Completer<void>();
    final last = loader.update(pages: _pages('c', 3), currentPage: 0, count: 0);
    await cache.started['c/0']!.future;
    loader.clear();
    cache.blocked['c/0']!.complete();
    await last;
    expect(cache.downloaded, ['a/0', 'b/0', 'b/1', 'c/0']);
  });

  test(
    'local pages and a failed request do not prevent remaining prefetch',
    () async {
      final cache = _Cache()..failed.add('a/1');
      final errors = <Object>[];
      final loader = ReaderImagePrecache(
        cacheManager: cache,
        onError: (e, _) => errors.add(e),
      );
      final pages = _pages('a', 4);
      pages[0] = ImageEntity(ImageType.asset, 'cover.png');
      await loader.update(pages: pages, currentPage: 0, count: 0);
      expect(cache.downloaded, ['a/1', 'a/2', 'a/3']);
      expect(errors.single, isA<HttpException>());
    },
  );
}
