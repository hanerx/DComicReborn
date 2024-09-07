import 'package:flutter/material.dart';

class ThemeModel {
  final String name;
  final Color? color;
  final ThemeMode? mode;
  final IconData? icon;

  const ThemeModel({
    required this.name,
    this.color,
    this.mode,
    this.icon,
  });

  static final light = ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    colorSchemeSeed: Colors.blue,
  );

  static final dark = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorSchemeSeed: Colors.blue,
  );

  static final themes = [
    const ThemeModel(
      name: 'System',
      mode: ThemeMode.system,
      icon: Icons.phone_android,
    ),
    const ThemeModel(
      name: 'Light',
      mode: ThemeMode.light,
      icon: Icons.light_mode,
    ),
    const ThemeModel(
      name: 'Dark',
      mode: ThemeMode.dark,
      icon: Icons.dark_mode,
    ),
    const ThemeModel(
      name: 'Blue',
      color: Colors.blue,
    ),
    const ThemeModel(
      name: 'Red',
      color: Colors.red,
    ),
    const ThemeModel(
      name: 'Pink',
      color: Colors.pink,
    ),
    const ThemeModel(
      name: 'Purple',
      color: Colors.purple,
    ),
    const ThemeModel(
      name: 'DeepPurple',
      color: Colors.deepPurple,
    ),
    const ThemeModel(
      name: 'Indigo',
      color: Colors.indigo,
    ),
    const ThemeModel(
      name: 'LightBlue',
      color: Colors.lightBlue,
    ),
    const ThemeModel(
      name: 'Cyan',
      color: Colors.cyan,
    ),
    const ThemeModel(
      name: 'Teal',
      color: Colors.teal,
    ),
    const ThemeModel(
      name: 'LightGreen',
      color: Colors.lightGreen,
    ),
    const ThemeModel(
      name: 'Lime',
      color: Colors.lime,
    ),
    const ThemeModel(
      name: 'Yellow',
      color: Colors.yellow,
    ),
    const ThemeModel(
      name: 'Amber',
      color: Colors.amber,
    ),
    const ThemeModel(
      name: 'Orange',
      color: Colors.orange,
    ),
    const ThemeModel(
      name: 'DeepOrange',
      color: Colors.deepOrange,
    ),
    const ThemeModel(
      name: 'Brown',
      color: Colors.brown,
    ),
    const ThemeModel(
      name: 'Grey',
      color: Colors.grey,
    ),
    const ThemeModel(
      name: 'BlueGrey',
      color: Colors.blueGrey,
    ),
  ];
}