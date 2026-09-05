enum ImageType {
  unknown,
  network,
  local,
  // Append new types: existing enum indices are persisted in the database.
  asset
}

class ImageEntity {
  ImageType imageType;

  String imageUrl;

  Map<String, String>? imageHeaders;

  ImageEntity(this.imageType, this.imageUrl, {this.imageHeaders});
}
