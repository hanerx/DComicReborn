import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:dcomic/utils/reader_image_fit.dart';
import 'package:dcomic/view/components/dcomic_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Resolves an [ImageEntity] through the same cache-backed source types used by
/// [DComicImage]. Resolving twice is safe because Flutter's image cache shares
/// the decoded image between this size probe and the visible image widget.
ImageProvider<Object>? _readerImageProvider(ImageEntity image) {
  return switch (image.imageType) {
    ImageType.network => CachedNetworkImageProvider(
      image.imageUrl,
      headers: image.imageHeaders,
      cacheManager: DefaultCacheManager(),
    ),
    ImageType.local => FileImage(File(image.imageUrl)),
    ImageType.asset => AssetImage(image.imageUrl),
    ImageType.unknown => null,
  };
}

/// Reports the intrinsic logical size of an image and removes its stream
/// listener when it is replaced or disposed.
class ReaderImageSizeBuilder extends StatefulWidget {
  const ReaderImageSizeBuilder({
    super.key,
    required this.image,
    required this.builder,
  });

  final ImageEntity image;
  final Widget Function(BuildContext context, Size? imageSize) builder;

  @override
  State<ReaderImageSizeBuilder> createState() => _ReaderImageSizeBuilderState();
}

class _ReaderImageSizeBuilderState extends State<ReaderImageSizeBuilder> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? _imageSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ReaderImageSizeBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image.imageType != widget.image.imageType ||
        oldWidget.image.imageUrl != widget.image.imageUrl ||
        oldWidget.image.imageHeaders != widget.image.imageHeaders) {
      _resolve();
    }
  }

  void _resolve() {
    _removeListener();
    _imageSize = null;
    final provider = _readerImageProvider(widget.image);
    if (provider == null) return;
    final stream = provider.resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener((info, _) {
      final size = Size(
        info.image.width / info.scale,
        info.image.height / info.scale,
      );
      info.dispose();
      _removeListener();
      if (_imageSize == size || !mounted) return;
      setState(() => _imageSize = size);
    }, onError: (_, _) => _removeListener());
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  void _removeListener() {
    final stream = _stream;
    final listener = _listener;
    if (stream != null && listener != null) stream.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _imageSize);
}

Size readerImageDisplaySize({
  required Size viewportSize,
  required Size imageSize,
  required ReaderImageFit fit,
}) {
  if (viewportSize.isEmpty || imageSize.isEmpty) return Size.zero;
  final widthScale = viewportSize.width / imageSize.width;
  final heightScale = viewportSize.height / imageSize.height;
  final scale = switch (fit) {
    ReaderImageFit.contain => math.min(widthScale, heightScale),
    ReaderImageFit.cover => math.max(widthScale, heightScale),
    ReaderImageFit.fitWidth => widthScale,
    ReaderImageFit.fitHeight => heightScale,
    ReaderImageFit.original => 1.0,
    ReaderImageFit.actualSize => 1.0,
    ReaderImageFit.stretch => 1.0,
  };
  return fit == ReaderImageFit.stretch
      ? viewportSize
      : Size(imageSize.width * scale, imageSize.height * scale);
}

/// Lays out an already-resolved page image. The vertical reader owns vertical
/// scrolling, so only native-size horizontal overflow gets a nested scroller.
class ReaderPageImageLayout extends StatelessWidget {
  const ReaderPageImageLayout({
    super.key,
    required this.viewportSize,
    required this.imageSize,
    required this.fit,
    required this.readingAxis,
    required this.child,
  });

  final Size viewportSize;
  final Size imageSize;
  final ReaderImageFit fit;
  final Axis readingAxis;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final displaySize = readerImageDisplaySize(
      viewportSize: viewportSize,
      imageSize: imageSize,
      fit: fit,
    );
    final verticalNative =
        readingAxis == Axis.vertical && fit == ReaderImageFit.actualSize;
    final verticalFitWidth =
        readingAxis == Axis.vertical && fit == ReaderImageFit.fitWidth;
    final outerHeight = verticalNative || verticalFitWidth
        ? displaySize.height
        : viewportSize.height;
    final image = SizedBox.fromSize(size: displaySize, child: child);

    if (verticalNative) {
      return SizedBox(
        width: viewportSize.width,
        height: outerHeight,
        child: ColoredBox(
          color: Colors.black,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: math.max(viewportSize.width, displaySize.width),
              height: displaySize.height,
              child: Center(child: image),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: viewportSize.width,
      height: outerHeight,
      child: ClipRect(
        child: ColoredBox(
          color: Colors.black,
          child: OverflowBox(
            alignment: Alignment.center,
            minWidth: 0,
            minHeight: 0,
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            child: image,
          ),
        ),
      ),
    );
  }
}

/// Resolves and renders an image for the vertically scrolling reader.
class VerticalReaderPageImage extends StatelessWidget {
  const VerticalReaderPageImage({
    super.key,
    required this.image,
    required this.viewportSize,
    required this.fit,
  });

  final ImageEntity image;
  final Size viewportSize;
  final ReaderImageFit fit;

  @override
  Widget build(BuildContext context) {
    return ReaderImageSizeBuilder(
      image: image,
      builder: (context, imageSize) {
        if (imageSize == null) {
          return SizedBox.fromSize(
            size: viewportSize,
            child: ColoredBox(
              color: Colors.black,
              child: DComicImage(
                image,
                fit: BoxFit.contain,
                width: viewportSize.width,
                height: viewportSize.height,
                placeholderHeight: viewportSize.height,
                placeholderColor: Colors.black,
              ),
            ),
          );
        }
        return ReaderPageImageLayout(
          viewportSize: viewportSize,
          imageSize: imageSize,
          fit: fit,
          readingAxis: Axis.vertical,
          child: DComicImage(
            image,
            fit: BoxFit.fill,
            placeholderColor: Colors.black,
          ),
        );
      },
    );
  }
}
