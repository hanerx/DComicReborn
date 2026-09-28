import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:dcomic/utils/reader_info_settings.dart';
import 'package:flutter/material.dart';

/// A compact, non-interactive reader status panel intended as a direct child of
/// the reader's [Stack]. The surrounding reader is responsible for providing a
/// [SafeArea].
class ReaderInfoOverlay extends StatefulWidget {
  const ReaderInfoOverlay({
    super.key,
    required this.position,
    required this.batteryFormat,
    required this.pageFormat,
    required this.showChapter,
    required this.showTime,
    required this.currentPage,
    required this.totalPages,
    required this.chapterName,
  });

  final ReaderInfoPosition position;
  final ReaderBatteryFormat batteryFormat;
  final ReaderPageFormat pageFormat;
  final bool showChapter;
  final bool showTime;

  /// Zero-based image page index. A terminal comments page may equal
  /// [totalPages] and is clamped to the final image page for display.
  final int currentPage;

  /// Number of image pages, excluding any terminal comments page.
  final int totalPages;
  final String chapterName;

  @override
  State<ReaderInfoOverlay> createState() => _ReaderInfoOverlayState();
}

class _ReaderInfoOverlayState extends State<ReaderInfoOverlay>
    with WidgetsBindingObserver {
  Battery? _battery;
  StreamSubscription<BatteryState>? _batterySubscription;
  Timer? _refreshTimer;
  BatteryState? _batteryState;
  int? _batteryLevel;
  int _batteryRequestGeneration = 0;
  DateTime _now = DateTime.now();
  bool _isAppActive = true;

  bool get _showsBattery => widget.batteryFormat != ReaderBatteryFormat.hidden;

  bool get _needsRefresh => _isAppActive && (_showsBattery || widget.showTime);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _isAppActive =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    if (_showsBattery && _isAppActive) {
      _startBatteryUpdates();
    }
    _scheduleRefresh();
  }

  @override
  void didUpdateWidget(covariant ReaderInfoOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final showedBattery = oldWidget.batteryFormat != ReaderBatteryFormat.hidden;
    if (showedBattery != _showsBattery) {
      if (_showsBattery && _isAppActive) {
        _startBatteryUpdates();
      } else {
        _stopBatteryUpdates();
      }
    }
    if (showedBattery != _showsBattery ||
        oldWidget.showTime != widget.showTime) {
      if (widget.showTime) {
        _now = DateTime.now();
      }
      _scheduleRefresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isActive = state == AppLifecycleState.resumed;
    if (_isAppActive == isActive) {
      return;
    }
    _isAppActive = isActive;
    if (isActive) {
      if (widget.showTime && mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
      if (_showsBattery) {
        _startBatteryUpdates();
      }
      _scheduleRefresh();
    } else {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      _stopBatteryUpdates();
    }
  }

  void _startBatteryUpdates() {
    if (!_isAppActive || !_showsBattery || _batterySubscription != null) {
      return;
    }
    final battery = _battery ??= Battery();
    _batterySubscription = battery.onBatteryStateChanged.listen(
      _handleBatteryState,
      onError: (Object _) {},
    );
    unawaited(_loadBatteryLevel());
  }

  void _stopBatteryUpdates() {
    _batteryRequestGeneration++;
    final subscription = _batterySubscription;
    _batterySubscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    _batteryState = null;
    _batteryLevel = null;
  }

  Future<void> _loadBatteryLevel() async {
    final battery = _battery;
    if (battery == null || !_isAppActive || !_showsBattery) {
      return;
    }
    final requestGeneration = ++_batteryRequestGeneration;
    try {
      final level = await battery.batteryLevel;
      if (!mounted ||
          !_isAppActive ||
          !_showsBattery ||
          requestGeneration != _batteryRequestGeneration) {
        return;
      }
      setState(() {
        _batteryLevel = level >= 0 && level <= 100 ? level : null;
      });
    } catch (_) {
      if (!mounted ||
          !_isAppActive ||
          !_showsBattery ||
          requestGeneration != _batteryRequestGeneration) {
        return;
      }
      setState(() {
        // Clear any stale reading rather than presenting it as current when
        // the platform service becomes unavailable.
        _batteryLevel = null;
      });
    }
  }

  void _handleBatteryState(BatteryState state) {
    if (!mounted || !_isAppActive || !_showsBattery) {
      return;
    }
    setState(() {
      _batteryState = state;
    });
    unawaited(_loadBatteryLevel());
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    if (!_needsRefresh) {
      return;
    }

    final now = DateTime.now();
    final elapsedInMinute = Duration(
      seconds: now.second,
      milliseconds: now.millisecond,
      microseconds: now.microsecond,
    );
    _refreshTimer = Timer(
      const Duration(minutes: 1) - elapsedInMinute,
      _refresh,
    );
  }

  void _refresh() {
    _refreshTimer = null;
    if (!mounted || !_needsRefresh) {
      return;
    }
    if (widget.showTime) {
      setState(() {
        _now = DateTime.now();
      });
    }
    if (_showsBattery) {
      unawaited(_loadBatteryLevel());
    }
    _scheduleRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _stopBatteryUpdates();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chapterName = widget.chapterName.trim();
    final showsChapter = widget.showChapter && chapterName.isNotEmpty;
    if (!_showsBattery &&
        widget.pageFormat == ReaderPageFormat.hidden &&
        !showsChapter &&
        !widget.showTime) {
      return const SizedBox.shrink();
    }

    final items = <Widget>[];
    void addItem(Widget item) {
      if (items.isNotEmpty) {
        items.add(const SizedBox(width: 8));
      }
      items.add(item);
    }

    if (_showsBattery) {
      addItem(_buildBattery());
    }
    if (widget.pageFormat != ReaderPageFormat.hidden) {
      addItem(Text(_pageText()));
    }
    if (showsChapter) {
      addItem(
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Text(
            chapterName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
    if (widget.showTime) {
      addItem(Text(_timeText()));
    }

    final isTop = switch (widget.position) {
      ReaderInfoPosition.topLeft || ReaderInfoPosition.topRight => true,
      ReaderInfoPosition.bottomLeft || ReaderInfoPosition.bottomRight => false,
    };
    final isLeft = switch (widget.position) {
      ReaderInfoPosition.topLeft || ReaderInfoPosition.bottomLeft => true,
      ReaderInfoPosition.topRight || ReaderInfoPosition.bottomRight => false,
    };
    final alignment = switch ((isTop, isLeft)) {
      (true, true) => Alignment.topLeft,
      (true, false) => Alignment.topRight,
      (false, true) => Alignment.bottomLeft,
      (false, false) => Alignment.bottomRight,
    };

    return Positioned(
      left: 8,
      right: 8,
      top: isTop ? 8 : null,
      bottom: isTop ? null : 8,
      child: IgnorePointer(
        child: Align(
          alignment: alignment,
          child: Container(
            key: const ValueKey('reader-info-panel'),
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DefaultTextStyle(
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                height: 1,
                fontWeight: FontWeight.w500,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: items,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBattery() {
    final levelText = _batteryLevel == null ? '--%' : '$_batteryLevel%';
    final isCharging = _batteryState == BatteryState.charging;
    final icon = Semantics(
      label: _batteryLevel == null
          ? 'Battery level unavailable'
          : 'Battery level $_batteryLevel percent',
      child: _BatteryGraphic(level: _batteryLevel),
    );

    final children = <Widget>[];
    if (widget.batteryFormat == ReaderBatteryFormat.icon ||
        widget.batteryFormat == ReaderBatteryFormat.iconAndNumber) {
      children.add(icon);
      if (isCharging) {
        children.add(
          const Icon(Icons.bolt, size: 10, color: Colors.amberAccent),
        );
      }
    }
    if (widget.batteryFormat == ReaderBatteryFormat.iconAndNumber) {
      children.add(const SizedBox(width: 3));
    }
    if (widget.batteryFormat == ReaderBatteryFormat.number ||
        widget.batteryFormat == ReaderBatteryFormat.iconAndNumber) {
      children.add(Text(levelText));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  String _pageText() {
    final total = widget.totalPages > 0 ? widget.totalPages : 0;
    final current = total == 0 ? 0 : (widget.currentPage + 1).clamp(1, total);
    return switch (widget.pageFormat) {
      ReaderPageFormat.hidden => '',
      ReaderPageFormat.current => '$current',
      ReaderPageFormat.currentAndTotal => '$current/$total',
      ReaderPageFormat.percentage =>
        total == 0 ? '0%' : '${(current * 100 / total).round()}%',
    };
  }

  String _timeText() {
    final hour = _now.hour.toString().padLeft(2, '0');
    final minute = _now.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _BatteryGraphic extends StatelessWidget {
  const _BatteryGraphic({required this.level});

  final int? level;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('reader-info-battery-icon'),
      width: 19,
      height: 10,
      child: CustomPaint(
        painter: _BatteryPainter(level),
        child: level == null
            ? const Center(
                child: Text(
                  '?',
                  style: TextStyle(color: Colors.white, fontSize: 7, height: 1),
                ),
              )
            : null,
      ),
    );
  }
}

class _BatteryPainter extends CustomPainter {
  const _BatteryPainter(this.level);

  final int? level;
  static final Paint _fillPaint = Paint()..color = Colors.white;
  static final Paint _outlinePaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.5, 0.5, 15, size.height - 1),
      const Radius.circular(2),
    );
    canvas.drawRRect(body, _outlinePaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(16.5, 3, 2, 4),
        const Radius.circular(0.75),
      ),
      _fillPaint,
    );

    if (level case final level?) {
      const horizontalInset = 2.0;
      final fillWidth = 12 * level.clamp(0, 100) / 100;
      if (fillWidth > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(horizontalInset, 2, fillWidth, size.height - 4),
            const Radius.circular(1),
          ),
          _fillPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BatteryPainter oldDelegate) =>
      oldDelegate.level != level;
}
