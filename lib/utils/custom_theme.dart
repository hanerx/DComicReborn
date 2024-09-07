import 'package:flutter/material.dart';

class CustomTheme{
  final BuildContext context;
  late final ThemeData _theme=Theme.of(context);
  late final ColorScheme _colors = _theme.colorScheme;

  CustomTheme(this.context);


  CustomTheme.of(this.context);

  Color get foregroundColor=>_colors.brightness == Brightness.dark ? _colors.onSurface : _colors.onPrimary;
}