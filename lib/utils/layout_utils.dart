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
  }) {
    if (!width.isFinite || width <= 0) return 1;
    if (width < navigationBreakpoint) {
      return math.max(
        1,
        math.min(compactColumns, ((width + spacing) / (88 + spacing)).floor()),
      );
    }
    return math.max(1, ((width + spacing) / (targetWidth + spacing)).floor());
  }

  static double panelWidth(double width) => math.min(width * 0.9, 480);
}
