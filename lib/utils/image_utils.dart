
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

enum ImageType{
  unknown,
  network,
  local
}

class ImageEntity{
  ImageType imageType;

  String imageUrl;

  Map<String,String>? imageHeaders;

  ImageEntity(this.imageType, this.imageUrl,{this.imageHeaders});
}