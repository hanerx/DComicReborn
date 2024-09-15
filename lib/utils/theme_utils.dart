import 'package:flutter/material.dart';

class ThemeModel {
  final String name;
  final Color? color;

  const ThemeModel({
    required this.name,
    this.color,
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

  static final themes = <String, ThemeModel>{
    'Blue': const ThemeModel(
      name: 'Blue',
      color: Colors.blue,
    ),
    'Red': const ThemeModel(
      name: 'Red',
      color: Colors.red,
    ),
    'Pink': const ThemeModel(
      name: 'Pink',
      color: Colors.pink,
    ),
    'Purple': const ThemeModel(
      name: 'Purple',
      color: Colors.purple,
    ),
    'DeepPurple': const ThemeModel(
      name: 'DeepPurple',
      color: Colors.deepPurple,
    ),
    'Indigo': const ThemeModel(
      name: 'Indigo',
      color: Colors.indigo,
    ),
    'LightBlue': const ThemeModel(
      name: 'LightBlue',
      color: Colors.lightBlue,
    ),
    'Cyan': const ThemeModel(
      name: 'Cyan',
      color: Colors.cyan,
    ),
    'Teal': const ThemeModel(
      name: 'Teal',
      color: Colors.teal,
    ),
    'LightGreen': const ThemeModel(
      name: 'LightGreen',
      color: Colors.lightGreen,
    ),
    'Lime': const ThemeModel(
      name: 'Lime',
      color: Colors.lime,
    ),
    'Yellow': const ThemeModel(
      name: 'Yellow',
      color: Colors.yellow,
    ),
    'Amber': const ThemeModel(
      name: 'Amber',
      color: Colors.amber,
    ),
    'Orange': const ThemeModel(
      name: 'Orange',
      color: Colors.orange,
    ),
    'DeepOrange': const ThemeModel(
      name: 'DeepOrange',
      color: Colors.deepOrange,
    ),
    'Brown': const ThemeModel(
      name: 'Brown',
      color: Colors.brown,
    ),
    'Grey': const ThemeModel(
      name: 'Grey',
      color: Colors.grey,
    ),
    'BlueGrey': const ThemeModel(
      name: 'BlueGrey',
      color: Colors.blueGrey,
    ),
  };
}