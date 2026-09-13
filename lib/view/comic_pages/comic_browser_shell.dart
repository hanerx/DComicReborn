import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/utils/layout_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Both navigators stay mounted when the window crosses the split breakpoint.
/// Reading is pushed on the root navigator, outside this browsing workspace.
class ComicBrowserShell extends StatelessWidget {
  const ComicBrowserShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final navigation = context.watch<NavigatorProvider>();
    return LayoutBuilder(
      builder: (context, constraints) {
        final split = constraints.maxWidth >= AppLayout.expandedBreakpoint;
        final browseWidth = split
            ? (constraints.maxWidth * 0.4).clamp(320.0, 560.0)
            : constraints.maxWidth;
        final detailWidth = split
            ? constraints.maxWidth - browseWidth - 1
            : constraints.maxWidth;
        final identity = navigation.detailIdentity;
        final detailBuilder = navigation.detailBuilder;
        return Provider<ComicBrowserLayout>.value(
          value: split
              ? ComicBrowserLayout.splitPane
              : ComicBrowserLayout.singlePane,
          child: PopScope<Object?>(
            canPop: !navigation.hasDetail,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop && navigation.hasDetail) {
                navigation.detailNavigator.currentState?.maybePop();
              }
            },
            child: Material(
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: browseWidth,
                    child: Offstage(
                      offstage: !split && navigation.hasDetail,
                      child: TickerMode(
                        enabled: split || !navigation.hasDetail,
                        child: _PaneMediaQuery(
                          width: browseWidth,
                          height: constraints.maxHeight,
                          removeLeft: false,
                          removeRight: split,
                          child: NavigatorPopHandler<Object?>(
                            enabled: !navigation.hasDetail,
                            onPopWithResult: (result) {
                              if (detailBuilder == null) {
                                navigation.browseNavigator.currentState
                                    ?.maybePop(result);
                              }
                            },
                            child: Navigator(
                              key: navigation.browseNavigator,
                              onGenerateRoute: (_) => MaterialPageRoute<void>(
                                builder: (_) => child,
                                settings: const RouteSettings(
                                  name: 'ComicBrowser',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (split)
                    Positioned(
                      left: browseWidth,
                      top: 0,
                      bottom: 0,
                      child: const VerticalDivider(width: 1, thickness: 1),
                    ),
                  Positioned(
                    // A stable key preserves the detail navigator when the divider
                    // is inserted or removed during a width change.
                    key: const ValueKey('detail-pane'),
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: detailWidth,
                    child: Offstage(
                      offstage: !split && !navigation.hasDetail,
                      child: TickerMode(
                        enabled: split || navigation.hasDetail,
                        child: _PaneMediaQuery(
                          width: detailWidth,
                          height: constraints.maxHeight,
                          removeLeft: split,
                          removeRight: false,
                          child: Navigator(
                            key: navigation.detailNavigator,
                            pages: [
                              const MaterialPage<void>(
                                key: ValueKey('no-comic'),
                                child: _NoComicSelected(),
                              ),
                              if (detailBuilder != null)
                                MaterialPage<void>(
                                  key: ValueKey(identity),
                                  name: 'ComicDetailPage',
                                  child: Builder(
                                    builder: (context) =>
                                        detailBuilder(context, split),
                                  ),
                                ),
                            ],
                            onDidRemovePage: (page) {
                              if (page.key ==
                                  ValueKey(navigation.detailIdentity)) {
                                navigation.closeDetail();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PaneMediaQuery extends StatelessWidget {
  const _PaneMediaQuery({
    required this.width,
    required this.height,
    required this.removeLeft,
    required this.removeRight,
    required this.child,
  });

  final double width;
  final double height;
  final bool removeLeft;
  final bool removeRight;
  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context)
        .removePadding(removeLeft: removeLeft, removeRight: removeRight)
        .copyWith(size: Size(width, height)),
    child: child,
  );
}

class _NoComicSelected extends StatelessWidget {
  const _NoComicSelected();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_stories_outlined,
                size: 56,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 20),
              Text(
                zh ? '选择一本漫画' : 'Select a comic',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                zh
                    ? '在左侧浏览漫画，在这里查看详情和章节'
                    : 'Browse on the left to see details and chapters here',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
