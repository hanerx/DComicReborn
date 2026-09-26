import 'dart:async';
import 'dart:math' as math;

import 'package:dcomic/providers/network_diagnostics_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> showNetworkDiagnosticsDialog(
  BuildContext context, {
  required NetworkDiagnosticsController controller,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (dialogContext) =>
        _NetworkDiagnosticsDialog(controller: controller),
  );
}

class _NetworkDiagnosticsDialog extends StatefulWidget {
  const _NetworkDiagnosticsDialog({required this.controller});

  final NetworkDiagnosticsController controller;

  @override
  State<_NetworkDiagnosticsDialog> createState() =>
      _NetworkDiagnosticsDialogState();
}

class _NetworkDiagnosticsDialogState extends State<_NetworkDiagnosticsDialog> {
  static const double _nearBottomThreshold = 48;

  final ScrollController _scrollController = ScrollController();
  _CopyResult? _copyResult;

  bool get _isChinese =>
      Localizations.localeOf(context).languageCode.startsWith('zh');

  String _localized(String chinese, String english) =>
      _isChinese ? chinese : english;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(widget.controller.start());
      }
    });
  }

  void _handleControllerChanged() {
    if (!mounted) return;

    final shouldFollow =
        !_scrollController.hasClients ||
        _scrollController.position.extentAfter <= _nearBottomThreshold;
    setState(() {});

    if (shouldFollow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });
    }
  }

  Future<void> _copyReport() async {
    final reportSnapshot = widget.controller.report;
    try {
      await Clipboard.setData(ClipboardData(text: reportSnapshot));
      if (!mounted) return;
      setState(() => _copyResult = _CopyResult.success);
    } catch (_) {
      if (!mounted) return;
      setState(() => _copyResult = _CopyResult.failure);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    widget.controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final colors = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final contentHeight = math.min(
      520.0,
      math.max(160.0, mediaQuery.size.height * 0.55),
    );
    final report = controller.report;

    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Row(
        children: [
          Expanded(child: Text(_localized('网络诊断', 'Network diagnostics'))),
          if (controller.isRunning) ...[
            const SizedBox(width: 16),
            SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                semanticsLabel: _localized('诊断进行中', 'Diagnostics in progress'),
              ),
            ),
          ],
        ],
      ),
      content: SizedBox(
        width: 680,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_copyResult != null) ...[
              Semantics(
                liveRegion: true,
                child: Row(
                  children: [
                    Icon(
                      _copyResult == _CopyResult.success
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      size: 18,
                      color: _copyResult == _CopyResult.success
                          ? colors.primary
                          : colors.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _copyResult == _CopyResult.success
                            ? _localized(
                                '已复制当前诊断报告。',
                                'Current diagnostic report copied.',
                              )
                            : _localized(
                                '复制失败，请重试。',
                                'Could not copy. Please try again.',
                              ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _copyResult == _CopyResult.success
                              ? colors.primary
                              : colors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              height: contentHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  border: Border.all(color: colors.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Scrollbar(
                  controller: _scrollController,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: double.infinity,
                      child: SelectableText(
                        report.isEmpty
                            ? _localized('正在准备诊断…', 'Preparing diagnostics…')
                            : report,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontFamily: 'monospace', height: 1.45),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.privacy_tip_outlined,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _localized(
                      '报告包含 IP 地址，分享前请检查内容。',
                      'This report contains IP addresses. Review it before sharing.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_localized('关闭', 'Close')),
        ),
        FilledButton.icon(
          onPressed: _copyReport,
          icon: const Icon(Icons.copy_outlined),
          label: Text(_localized('复制报告', 'Copy report')),
        ),
      ],
    );
  }
}

enum _CopyResult { success, failure }
