import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:flutter/material.dart';
import 'package:dcomic/generated/l10n.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class DComicImage extends StatelessWidget {
  final ImageEntity imageEntity;
  final TextOverflow? errorMessageOverflow;
  final BoxFit? fit;
  final Color? customErrorMessageColor;
  final bool showErrorMessage;
  final double errorLogoSize;
  final double? width;

  const DComicImage(this.imageEntity,
      {super.key,
      this.errorMessageOverflow,
      this.fit,
      this.customErrorMessageColor,
      this.showErrorMessage = true,
      this.errorLogoSize = 60,
      this.width});

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
          cacheManager: DefaultCacheManager(),
          width: width,
        );
      case ImageType.local:
        return Image.file(
          File(imageEntity.imageUrl),
          fit: fit,
          errorBuilder: (context, object, error) =>
              _buildErrorWidget(context, "$object Load Failed: $error"),
          width: width,
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
                size: errorLogoSize,
                color:
                    customErrorMessageColor ?? Theme.of(context).disabledColor,
              ),
            ] +
            _showErrorMessage(context, errorMessage),
      ),
    );
  }

  List<Widget> _showErrorMessage(BuildContext context, String errorMessage) {
    if (showErrorMessage) {
      return [
        Text(
          errorMessage,
          style: TextStyle(
              color: customErrorMessageColor ?? Theme.of(context).disabledColor,
              overflow: errorMessageOverflow),
        ),
        const Expanded(child: SizedBox())
      ];
    } else {
      return [const Expanded(child: SizedBox())];
    }
  }
}
