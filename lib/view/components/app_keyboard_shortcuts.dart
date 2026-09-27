import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Routes Escape through normal back handling, including nested navigators.
class AppKeyboardShortcuts extends StatelessWidget {
  const AppKeyboardShortcuts({super.key, required this.child});

  final Widget child;

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    if (event.logicalKey != LogicalKeyboardKey.escape ||
        keyboard.isAltPressed ||
        keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    // Consume repeats as well, so holding Escape cannot unwind the whole stack.
    if (event is KeyDownEvent) {
      final context = FocusManager.instance.primaryFocus?.context;
      if (context != null) {
        final route = ModalRoute.of(context);
        // Drawers use local history, which need not change the root navigator's
        // pop notification. Dismiss these and nested popups before page routes.
        final localOverlay =
            route is PopupRoute || route?.willHandlePopInternally == true;
        unawaited(
          Navigator.maybeOf(context, rootNavigator: !localOverlay)?.maybePop(),
        );
      }
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    onKeyEvent: _handleKey,
    child: child,
  );
}
