import 'dart:io';

import 'package:dcomic/downloads/download_models.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class DownloadCache {
  final BaseCacheManager? _manager;
  final DateTime Function() _now;

  DownloadCache({this._manager, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  Future<bool> copyValid(DownloadRequest request, File staging) async {
    final key = request.cacheKey;
    if (key == null || key.isEmpty) return false;
    final expectedIdentity = imageCacheIdentity(
      request.url.toString(),
      request.headers,
    );
    if (key != expectedIdentity && request.integrity.normalizedSha256 == null) {
      return false;
    }
    final FileInfo? info;
    try {
      info = await (_manager ?? DefaultCacheManager()).getFileFromCache(key);
    } on Object {
      return false;
    }
    if (info == null) return false;
    if (!info.validTill.isAfter(_now()) ||
        info.originalUrl != request.url.toString() ||
        info.statusCode != HttpStatus.ok) {
      return false;
    }

    final source = File(info.file.path);
    try {
      if (!await source.exists()) return false;
      final expectedLength = await source.length();
      if (expectedLength <= 0) return false;
      await staging.parent.create(recursive: true);
      if (await staging.exists()) await staging.delete();
      await source.openRead().pipe(staging.openWrite(mode: FileMode.writeOnly));
      if (!await staging.exists() || await staging.length() != expectedLength) {
        if (await staging.exists()) await staging.delete();
        return false;
      }
      return true;
    } on Object {
      if (await staging.exists()) {
        try {
          await staging.delete();
        } on Object {
          // A failed best-effort cleanup is still a cache miss. The network
          // path prepares a fresh staging file before enqueueing.
        }
      }
      return false;
    }
  }
}
