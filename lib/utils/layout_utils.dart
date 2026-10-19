import 'dart:math' as math;

/// Layout decisions use logical pixels in the available pane, not device type.
abstract final class AppLayout {
  static const double navigationBreakpoint = 600;
  static const double expandedBreakpoint = 840;
  static const double contentMaxWidth = 1200;
  static const double formMaxWidth = 640;
  static const double readerMaxWidth = 800;

  static int gridColumns(
    double width, {
    int compactColumns = 3,
    double targetWidth = 160,
    double spacing = 12,
    int? itemCount,
  }) {
    if (!width.isFinite || width <= 0) return 1;
    var columns = width < navigationBreakpoint
        ? math.max(
            1,
            math.min(
              compactColumns,
              ((width + spacing) / (88 + spacing)).floor(),
            ),
          )
        : math.max(1, ((width + spacing) / (targetWidth + spacing)).floor());
    if (itemCount != null && itemCount > 0) {
      // Keep the same number of rows, but distribute finite sections evenly.
      // Four cards in a three-column pane should be 2 + 2, not 3 + 1.
      final rows = (itemCount / columns).ceil();
      columns = (itemCount / rows).ceil();
    }
    return columns;
  }

  static double panelWidth(double width) => math.min(width * 0.9, 480);
}
