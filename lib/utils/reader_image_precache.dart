import 'dart:math';

import 'package:dcomic/utils/image_utils.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Sequential disk prefetch; visible image widgets still load on demand.
class ReaderImagePrecache {
  ReaderImagePrecache({BaseCacheManager? cacheManager, required this.onError})
    : _cache = cacheManager;

  BaseCacheManager? _cache;
  final void Function(Object, StackTrace) onError;
  List<ImageEntity> _pages = const [];
  final Set<int> _attempted = {};
  int _revision = 0;
  int _cursor = 0;
  int _remaining = 0;
  Future<void>? _running;

  /// [count] is the number of following pages, or zero for the entire chapter.
  /// Replaces pending work without duplicating the request already in flight.
  Future<void> update({
    required List<ImageEntity> pages,
    required int currentPage,
    required int count,
  }) {
    RangeError.checkValueInInterval(count, 0, 9, 'count');
    if (!identical(pages, _pages)) {
      _pages = pages;
      _attempted.clear();
    }
    _revision++;
    _cursor = currentPage;
    _remaining = currentPage < 0 || currentPage >= pages.length
        ? 0
        : count == 0
        ? pages.length
        : min(count + 1, pages.length - currentPage);
    return _running ??= Future<void>.microtask(_drain)
        .whenComplete(() => _running = null);
  }

  /// Lets an in-flight transfer finish, but starts no more obsolete requests.
  void clear() {
    _revision++;
    _remaining = 0;
    _pages = const [];
    _attempted.clear();
  }

  Future<void> _drain() async {
    while (_remaining > 0) {
      final pages = _pages;
      final revision = _revision;
      final index = _cursor;
      _cursor = (_cursor + 1) % pages.length;
      _remaining--;
      final page = pages[index];
      if (page.imageType != ImageType.network || _attempted.contains(index)) {
        continue;
      }
      try {
        final cache = _cache ??= DefaultCacheManager();
        final cached = await cache.getFileFromCache(page.imageUrl);
        // Navigation can change the window while the cache lookup is pending.
        if (revision != _revision) continue;
        _attempted.add(index);
        if (cached == null) {
          await cache.downloadFile(
            page.imageUrl,
            authHeaders: page.imageHeaders,
          );
        }
      } catch (error, stack) {
        // Prefetch is best-effort; the visible image owns its error UI/retry.
        onError(error, stack);
      }
    }
  }
}
