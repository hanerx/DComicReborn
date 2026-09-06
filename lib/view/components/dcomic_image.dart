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
          progressIndicatorBuilder: (context, url, downloadProgress) =>
              _buildPlaceholder(context),
          httpHeaders: imageEntity.imageHeaders,
          errorWidget: (context, url, error) => _buildLoadErrorWidget(context),
          cacheManager: DefaultCacheManager(),
          width: width,
        );
      case ImageType.local:
        return Image.file(
          File(imageEntity.imageUrl),
          fit: fit,
          errorBuilder: (context, object, error) =>
              _buildLoadErrorWidget(context),
          width: width,
        );
      case ImageType.asset:
        return Image.asset(
          imageEntity.imageUrl,
          fit: fit,
          errorBuilder: (context, object, error) =>
              _buildLoadErrorWidget(context),
          width: width,
        );
    }
  }

  Widget _buildPlaceholder(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }

  Widget _buildLoadErrorWidget(BuildContext context) {
    return _buildErrorWidget(
        context,
        Localizations.localeOf(context).languageCode == 'zh'
            ? '图片加载失败'
            : 'Image load failed');
  }

  Widget _buildErrorWidget(BuildContext context, String errorMessage) {
    var color =
        customErrorMessageColor ?? Theme.of(context).colorScheme.outline;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined,
                size: errorLogoSize, color: color),
            ..._showErrorMessage(context, errorMessage, color),
          ],
        ),
      ),
    );
  }

  List<Widget> _showErrorMessage(
      BuildContext context, String errorMessage, Color color) {
    if (!showErrorMessage) {
      return const [];
    }
    return [
      const SizedBox(height: 4),
      Text(
        errorMessage,
        textAlign: TextAlign.center,
        style: TextStyle(
            color: color,
            fontSize: 12,
            overflow: errorMessageOverflow ?? TextOverflow.clip),
      ),
    ];
  }
}
