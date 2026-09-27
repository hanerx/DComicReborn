import 'dart:async';

import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/base_provider.dart';
import 'package:dcomic/utils/navigation_performance.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

enum NavigatorType { defaultNavigator, root }

enum ComicBrowserLayout { singlePane, splitPane }

class NavigatorProvider extends BaseProvider {
  NavigatorProvider(BuildContext context);

  late final NavigationPerformanceObserver rootPerformanceObserver =
      NavigationPerformanceObserver(navigatorName: 'root');
  late final NavigationPerformanceObserver browsePerformanceObserver =
      NavigationPerformanceObserver(navigatorName: 'browse');
  late final NavigationPerformanceObserver detailPerformanceObserver =
      NavigationPerformanceObserver(navigatorName: 'detail');

  late final List<NavigationPerformanceObserver> performanceObservers = [
    rootPerformanceObserver,
    browsePerformanceObserver,
    detailPerformanceObserver,
  ];

  final browseNavigator = GlobalKey<NavigatorState>();
  final detailNavigator = GlobalKey<NavigatorState>();
  Object? _detailIdentity;
  Widget Function(BuildContext, bool)? _detailBuilder;
  Completer<void>? _detailClosed;

  Object? get detailIdentity => _detailIdentity;
  Widget Function(BuildContext, bool)? get detailBuilder => _detailBuilder;
  bool get hasDetail => _detailBuilder != null;

  Future<void> showDetail({
    required Object identity,
    required Widget Function(BuildContext, bool) builder,
  }) {
    if (_detailIdentity == identity) return _detailClosed!.future;
    _detailClosed?.complete();
    _detailClosed = Completer<void>();
    _detailIdentity = identity;
    _detailBuilder = builder;
    notifyListeners();
    return _detailClosed!.future;
  }

  void closeDetail() {
    if (!hasDetail) return;
    _detailIdentity = null;
    _detailBuilder = null;
    // Detail links push the browse stack synchronously, before the shell rebuilds.
    browsePerformanceObserver.setCovered(
      NavigationCoverageSource.browserShell,
      false,
    );
    _detailClosed?.complete();
    _detailClosed = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _detailClosed?.complete();
    for (final observer in performanceObservers) {
      observer.dispose();
    }
    super.dispose();
  }

  NavigatorState? getNavigator(
    BuildContext context,
    NavigatorType navigatorType,
  ) {
    if (navigatorType == NavigatorType.root) {
      return Navigator.of(context, rootNavigator: true);
    }
    final navigator = Navigator.of(context);
    // Author/category links in a detail pane belong to the browsing stack.
    if (identical(navigator, detailNavigator.currentState)) {
      if (context.read<ComicBrowserLayout>() == ComicBrowserLayout.singlePane) {
        closeDetail();
      }
      return browseNavigator.currentState;
    }
    return navigator;
  }
}

class AppBarProvider extends BaseProvider {
  List<AppBar?> _appBarList = [AppBar(title: const Text("Loading..."))];
  List<String> stack = ["Default"];
  final BuildContext _context;

  AppBarProvider(this._context) {
    _appBarList = <AppBar?>[AppBar(title: Text(S.of(_context).AppName))];
  }

  AppBar? addAppBar(BuildContext context, AppBar? appBar, String stackName) {
    if (!stack.contains(stackName)) {
      _appBarList.add(appBar);
      stack.add(stackName);
      logger.i("New Stack AppBar $stackName");
      Future.delayed(const Duration()).then((value) => notifyListeners());
    }
    return null;
  }

  void pop() {
    if (_appBarList.length > 1) {
      _appBarList.removeLast();
      stack.removeLast();
    }
  }

  AppBar? get currentAppBar => _appBarList.last;
}
