import 'dart:io' as io;

import 'package:dcomic/downloads/download_cache.dart';
import 'package:dcomic/downloads/download_models.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'support/download_harness.dart';

class _Cache extends Fake implements BaseCacheManager {
  final Map<String, FileInfo> entries = {};

  @override
  Future<FileInfo?> getFileFromCache(
    String key, {
    bool ignoreMemCache = false,
  }) async => entries[key];
}

class _TestPaths extends PathProviderPlatform {
  final String path;

  _TestPaths(this.path);

  @override
  Future<String?> getTemporaryPath() async => path;
}

void main() {
  late PathProviderPlatform originalPaths;
  late io.Directory directory;
  late _Cache manager;
  late DateTime now;
  late DownloadCache cache;
  Future<dynamic> cachedFile(String contents) async {
    final file = await IOFileSystem('download-cache').createFile('source.bin');
    await file.writeAsString(contents, flush: true);
    return file;
  }

  setUp(() async {
    directory = await io.Directory.systemTemp.createTemp('download_cache_');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TestPaths(directory.path);
    manager = _Cache();
    now = DateTime.utc(2026, 10, 24, 12);
    cache = DownloadCache(manager: manager, now: () => now);
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalPaths;
    await directory.delete(recursive: true);
  });

  test('matching URL and complete header identity reuses a durable copy', () async {
    const headers = {'Authorization': 'Bearer secret', 'X-Variant': 'large'};
    const url = 'http://127.0.0.1/file';
    final identity = imageCacheIdentity(url, headers);
    final source = await cachedFile('cached bytes');
    manager.entries[identity] = FileInfo(
      source,
      FileSource.Cache,
      now.add(const Duration(hours: 1)),
      url,
    );
    final staging = io.File('${directory.path}/staging/sample.part');
    final request = sampleDownloadRequest(cacheKey: identity).copyWith(
      headers: headers,
    );

    expect(await cache.copyValid(request, staging), isTrue);
    await source.delete();

    expect(await staging.readAsString(), 'cached bytes');
  });

  test('expired cache entry is a miss and does not create staging', () async {
    final source = await cachedFile('expired');
    manager.entries['http://127.0.0.1/file'] = FileInfo(
      source,
      FileSource.Cache,
      now.subtract(const Duration(seconds: 1)),
      'http://127.0.0.1/file',
    );
    final staging = io.File('${directory.path}/staging/sample.part');

    expect(
      await cache.copyValid(
        sampleDownloadRequest(cacheKey: 'http://127.0.0.1/file'),
        staging,
      ),
      isFalse,
    );
    expect(await staging.exists(), isFalse);
  });

  test('cache entry for another signed URL is never reused', () async {
    final source = await cachedFile('wrong identity');
    manager.entries['stable-key'] = FileInfo(
      source,
      FileSource.Cache,
      now.add(const Duration(hours: 1)),
      'http://127.0.0.1/file?signature=other',
    );

    expect(
      await cache.copyValid(
        sampleDownloadRequest(cacheKey: 'stable-key'),
        io.File('${directory.path}/sample.part'),
      ),
      isFalse,
    );
  });

  test('legacy URL key is not trusted without a digest', () async {
    const url = 'http://127.0.0.1/file';
    final source = await cachedFile('legacy');
    manager.entries[url] = FileInfo(
      source,
      FileSource.Cache,
      now.add(const Duration(hours: 1)),
      url,
    );

    expect(
      await cache.copyValid(
        sampleDownloadRequest(cacheKey: url),
        io.File('${directory.path}/legacy.part'),
      ),
      isFalse,
    );
  });

  test('trusted digest permits legacy cache identity for later verification', () async {
    const url = 'http://127.0.0.1/file';
    final source = await cachedFile('abc');
    manager.entries[url] = FileInfo(
      source,
      FileSource.Cache,
      now.add(const Duration(hours: 1)),
      url,
    );
    final request = sampleDownloadRequest(
      cacheKey: url,
      integrity: const DownloadIntegrity(
        sha256Hex:
            'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      ),
    );

    expect(
      await cache.copyValid(
        request,
        io.File('${directory.path}/legacy.part'),
      ),
      isTrue,
    );
  });


  test('same URL cached under different headers is a miss', () async {
    const url = 'http://127.0.0.1/file';
    final firstIdentity = imageCacheIdentity(
      url,
      const {'Authorization': 'Bearer first'},
    );
    final source = await cachedFile('private');
    manager.entries[firstIdentity] = FileInfo(
      source,
      FileSource.Cache,
      now.add(const Duration(hours: 1)),
      url,
    );
    final request = sampleDownloadRequest(cacheKey: firstIdentity).copyWith(
      headers: const {'Authorization': 'Bearer second'},
    );

    expect(
      await cache.copyValid(
        request,
        io.File('${directory.path}/sample.part'),
      ),
      isFalse,
    );
  });

  test('cache identity is deterministic, versioned, and hides credentials', () {
    final first = imageCacheIdentity(
      'https://example.test/page',
      const {'X-B': '2', 'authorization': 'Bearer secret', 'x-a': '1'},
    );
    final reordered = imageCacheIdentity(
      'https://example.test/page',
      const {'X-A': '1', 'Authorization': 'Bearer secret', 'x-b': '2'},
    );

    expect(first, reordered);
    expect(first, startsWith('dcomic-image-v1:'));
    expect(first, isNot(contains('secret')));
    expect(
      first,
      isNot(imageCacheIdentity(
        'https://example.test/page',
        const {'Authorization': 'Bearer other', 'X-A': '1', 'X-B': '2'},
      )),
    );
  });
}
