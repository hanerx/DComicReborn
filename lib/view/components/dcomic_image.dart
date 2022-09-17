import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:dcomic/generated/l10n.dart';

class DComicImage extends StatelessWidget {
  final ImageEntity imageEntity;
  final TextOverflow? errorMessageOverflow;
  final BoxFit? fit;
  final Color? customErrorMessageColor;

  const DComicImage(this.imageEntity,
      {super.key,
      this.errorMessageOverflow,
      this.fit,
      this.customErrorMessageColor});

  @override
  Widget build(BuildContext context) {
    return _buildImageWidget(context);
  }

  Widget _buildImageWidget(BuildContext context) {
    switch (imageEntity.imageType) {
      case ImageType.unknown:
        return _buildErrorWidget(context, S.of(context).ImageTypeNotSupport);
      case ImageType.network:
        return CachedNetworkImage(
          fit: fit,
          imageUrl: imageEntity.imageUrl,
          progressIndicatorBuilder: (context, url, downloadProgress) => Center(
              child:
                  CircularProgressIndicator(value: downloadProgress.progress)),
          httpHeaders: imageEntity.imageHeaders,
          errorWidget: (context, url, error) =>
              _buildErrorWidget(context, "$url Load Failed: $error"),
        );
      case ImageType.local:
        return Image.file(
          File(imageEntity.imageUrl),
          fit: fit,
          errorBuilder: (context, object, error) =>
              _buildErrorWidget(context, "$object Load Failed: $error"),
        );
    }
  }

  Widget _buildErrorWidget(BuildContext context, String errorMessage) {
    return Center(
      child: Column(
        children: [
          const Expanded(child: SizedBox()),
          Icon(
            Icons.broken_image,
            size: 60,
            color: customErrorMessageColor ?? Theme.of(context).disabledColor,
          ),
          Text(
            errorMessage,
            style: TextStyle(
                color:
                    customErrorMessageColor ?? Theme.of(context).disabledColor,
                overflow: errorMessageOverflow),
          ),
          const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}
