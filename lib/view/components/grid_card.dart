import 'package:badges/badges.dart' as badges;
import 'package:dcomic/utils/image_utils.dart';
import 'package:dcomic/view/components/dcomic_image.dart';
import 'package:flutter/material.dart';

/// Lightweight homepage section: a plain title row above a cover grid,
/// no panel behind the covers.
class GridCard extends StatelessWidget {
  final String title;
  final IconData? sideIcon;
  final void Function()? onSideIconPressed;
  final List<Widget> children;
  final int crossAxisCount;
  final double? childAspectRatio;

  /// Cover width/height ratio applied when [childAspectRatio] is null.
  final double coverAspectRatio;

  /// Whether the grid reserves one subtitle line under the two reserved
  /// title lines, so every cover in a row keeps the same height.
  final bool reserveSubtitle;

  const GridCard(this.title,
      {super.key,
      this.sideIcon,
      this.onSideIconPressed,
      this.children = const [],
      this.crossAxisCount = 3,
      this.childAspectRatio,
      this.coverAspectRatio = 2 / 3,
      this.reserveSubtitle = false});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (sideIcon != null || onSideIconPressed != null)
                  IconButton(
                    onPressed: onSideIconPressed,
                    icon: Icon(
                      sideIcon ?? Icons.chevron_right,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          GridView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            shrinkWrap: true,
            gridDelegate: childAspectRatio != null
                ? SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: childAspectRatio!,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: GridCardItem.gridSpacing,
                  )
                : GridCardItem.coverGridDelegate(context,
                    gridWidth: constraints.maxWidth - 32,
                    crossAxisCount: crossAxisCount,
                    coverAspectRatio: coverAspectRatio,
                    hasSubtitle: reserveSubtitle),
            children: children,
          ),
        ],
      );
    });
  }
}

/// A single cover cell: the cover always fills a fixed width/height box
/// ([coverAspectRatio]) so covers in the same row are equally tall; below it
/// a left-aligned two-line title slot and, when needed, a one-line subtitle
/// slot, both sized with the current textScaler.
class GridCardItem extends StatelessWidget {
  static const double titleFontSize = 12.0;
  static const double titleLineHeight = 1.3;
  static const double subtitleLineHeight = 1.25;
  static const double coverTitleSpacing = 6.0;
  static const double titleSubtitleSpacing = 2.0;
  static const double gridSpacing = 16.0;

  final String? title;
  final String? subtitle;
  final ImageEntity image;
  final void Function()? onTap;
  final Map<badges.BadgePosition, String Function(BuildContext)>? badgeMaps;

  /// Cover width / height. Comic covers use 2/3, square artwork 1/1.
  final double coverAspectRatio;

  const GridCardItem(
      {super.key,
      this.title,
      this.subtitle,
      required this.image,
      this.onTap,
      this.badgeMaps,
      this.coverAspectRatio = 2 / 3});

  /// Height reserved below a cover: the title slot always reserves two full
  /// lines, the subtitle slot one line when present.
  static double reservedTextExtent(BuildContext context,
      {bool hasTitle = true, bool hasSubtitle = false}) {
    var scaler = MediaQuery.textScalerOf(context);
    var extent = 0.0;
    if (hasTitle) {
      extent +=
          coverTitleSpacing + scaler.scale(titleFontSize) * titleLineHeight * 2;
    }
    if (hasSubtitle) {
      extent += titleSubtitleSpacing +
          scaler.scale(titleFontSize) * subtitleLineHeight;
    }
    return extent;
  }

  /// Grid delegate whose cell height is derived from the cover aspect ratio
  /// plus the reserved text height (textScaler-aware), so long titles can
  /// never make a cover shorter than its row neighbours.
  static SliverGridDelegateWithFixedCrossAxisCount coverGridDelegate(
      BuildContext context,
      {required double gridWidth,
      required int crossAxisCount,
      double crossAxisSpacing = 12,
      double mainAxisSpacing = gridSpacing,
      double coverAspectRatio = 2 / 3,
      bool hasTitle = true,
      bool hasSubtitle = false}) {
    var columnWidth =
        (gridWidth - crossAxisSpacing * (crossAxisCount - 1)) / crossAxisCount;
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisExtent: columnWidth / coverAspectRatio +
          reservedTextExtent(context,
              hasTitle: hasTitle, hasSubtitle: hasSubtitle),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: _buildBadge(context),
    );
  }

  Widget _buildColumn(BuildContext context) {
    var theme = Theme.of(context);
    var scaler = MediaQuery.textScalerOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: coverAspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: DComicImage(
              image,
              errorMessageOverflow: TextOverflow.ellipsis,
              fit: BoxFit.cover,
            ),
          ),
        ),
        if (title != null) ...[
          const SizedBox(height: coverTitleSpacing),
          SizedBox(
            height: scaler.scale(titleFontSize) * titleLineHeight * 2,
            child: Text(
              title!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: titleFontSize,
                height: titleLineHeight,
                fontWeight: FontWeight.w500,
              ).copyWith(color: theme.colorScheme.onSurface),
            ),
          ),
        ],
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: titleSubtitleSpacing),
          SizedBox(
            height: scaler.scale(titleFontSize) * subtitleLineHeight,
            child: Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: titleFontSize,
                height: subtitleLineHeight,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBadge(BuildContext context) {
    Widget child = _buildColumn(context);
    if (badgeMaps == null) {
      return child;
    }
    for (var tuple in badgeMaps!.entries) {
      child = badges.Badge(
        badgeContent: Text(
          tuple.value(context),
          style: TextStyle(color: Theme.of(context).colorScheme.onError),
        ),
        position: tuple.key,
        badgeStyle: badges.BadgeStyle(
          shape: badges.BadgeShape.square,
          borderRadius: BorderRadius.circular(4),
          badgeColor: Theme.of(context).colorScheme.error.withAlpha(210),
        ),
        child: child,
      );
    }
    return child;
  }
}

class GridCardPlaceHolder extends StatelessWidget {
  const GridCardPlaceHolder({super.key});

  @override
  Widget build(BuildContext context) {
    var blockColor = Theme.of(context).colorScheme.surfaceContainerLow;
    return LayoutBuilder(builder: (context, constraints) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 96,
                height: 14,
                decoration: BoxDecoration(
                  color: blockColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          GridView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            shrinkWrap: true,
            gridDelegate: GridCardItem.coverGridDelegate(context,
                gridWidth: constraints.maxWidth - 32,
                crossAxisCount: 3,
                hasTitle: false),
            children: [
              for (int i = 0; i < 6; i++)
                Container(
                  decoration: BoxDecoration(
                    color: blockColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
            ],
          ),
        ],
      );
    });
  }
}
