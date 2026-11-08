import 'dart:convert';

import 'package:crypto/crypto.dart';

enum ImageType {
  unknown,
  network,
  local,
  // Append new types: existing enum indices are persisted in the database.
  asset
}

/// Returns the opaque disk-cache identity shared by readers and downloads.
///
/// Every request header participates because servers may vary image bytes on
/// arbitrary custom headers. Only the digest is exposed to avoid persisting
/// credentials in cache database keys.
String imageCacheIdentity(String url, Map<String, String>? headers) {
  final canonicalHeaders = (headers ?? const <String, String>{})
      .entries
      .map((entry) => [entry.key.toLowerCase(), entry.value])
      .toList(growable: false)
    ..sort((left, right) {
      final nameOrder = left[0].compareTo(right[0]);
      return nameOrder != 0 ? nameOrder : left[1].compareTo(right[1]);
    });
  final bytes = utf8.encode(jsonEncode([url, canonicalHeaders]));
  return 'dcomic-image-v1:${sha256.convert(bytes)}';
}

class ImageEntity {
  ImageType imageType;

  String imageUrl;

  Map<String, String>? imageHeaders;

  ImageEntity(this.imageType, this.imageUrl, {this.imageHeaders});
}
