import 'package:dcomic/providers/base_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_adaptive_ui/flutter_adaptive_ui.dart';

enum NavigatorType { defaultNavigator, left, home, right, large }

class NavigatorProvider extends BaseProvider {
  final GlobalKey<NavigatorState> _homeNavigator = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _leftNavigator = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _rightNavigator = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _largeNavigator = GlobalKey<NavigatorState>();

  final BuildContext _context;

  NavigatorProvider(this._context);

  NavigatorState? getNavigator(
      BuildContext context, NavigatorType navigatorType) {
    if (Screen.fromContext(context).isHandset) {
      return Navigator.of(_context);
    }
    switch (navigatorType) {
      case NavigatorType.defaultNavigator:
        return Navigator.of(_context);
      case NavigatorType.left:
        return _leftNavigator.currentState;
      case NavigatorType.home:
        return _homeNavigator.currentState;
      case NavigatorType.right:
        return _rightNavigator.currentState;
      case NavigatorType.large:
        return _largeNavigator.currentState;
    }
  }

  GlobalKey<NavigatorState> get homeNavigator => _homeNavigator;

  GlobalKey<NavigatorState> get leftNavigator => _leftNavigator;

  GlobalKey<NavigatorState> get rightNavigator => _rightNavigator;

  GlobalKey<NavigatorState> get largeNavigator => _largeNavigator;
}
