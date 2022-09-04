import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/base_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_adaptive_ui/flutter_adaptive_ui.dart';

enum NavigatorType { defaultNavigator, home, right, large }

class NavigatorProvider extends BaseProvider {
  final GlobalKey<NavigatorState> _homeNavigator = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _rightNavigator = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _largeNavigator = GlobalKey<NavigatorState>();

  final BuildContext _context;

  NavigatorProvider(this._context);

  NavigatorState? getNavigator(
      BuildContext context, NavigatorType navigatorType) {
    if (Screen.fromContext(context).isHandset) {
      return Navigator.of(context);
    }
    switch (navigatorType) {
      case NavigatorType.defaultNavigator:
        return Navigator.of(context);
      case NavigatorType.home:
        return _homeNavigator.currentState;
      case NavigatorType.right:
        return _rightNavigator.currentState;
      case NavigatorType.large:
        return _largeNavigator.currentState;
    }
  }

  GlobalKey<NavigatorState> get homeNavigator => _homeNavigator;

  GlobalKey<NavigatorState> get rightNavigator => _rightNavigator;

  GlobalKey<NavigatorState> get largeNavigator => _largeNavigator;
}

class AppBarProvider extends BaseProvider {
  List<AppBar?> _appBarList = [
    AppBar(
      title: const Text("Loading..."),
    )
  ];
  List<String> stack=["Default"];
  final BuildContext _context;

  AppBarProvider(this._context) {
    _appBarList = <AppBar?>[
      AppBar(
        title: Text(S.of(_context).AppName),
      )
    ];
  }

  AppBar? addAppBar(BuildContext context, AppBar? appBar, String stackName) {
    if (Screen.fromContext(context).isHandset) {
      return appBar;
    }
    if(!stack.contains(stackName)){
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
