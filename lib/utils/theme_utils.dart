import 'package:flutter/material.dart';

class ThemeModel {
  final String name;
  final Color? color;

  const ThemeModel({
    required this.name,
    this.color,
  });

  static final light = buildTheme(brightness: Brightness.light);
  static final dark = buildTheme(brightness: Brightness.dark);

  static ThemeData buildTheme({
    required Brightness brightness,
    Color? seedColor,
    bool useMaterial3 = true,
  }) {
    final isDark = brightness == Brightness.dark;
    final colors = ColorScheme.fromSeed(
      seedColor: seedColor ?? Colors.blue,
      brightness: brightness,
    ).copyWith(
      surface: isDark ? const Color(0xFF141619) : const Color(0xFFFAFAF8),
      surfaceContainerLowest: isDark ? const Color(0xFF101214) : Colors.white,
      surfaceContainerLow:
          isDark ? const Color(0xFF1B1E22) : const Color(0xFFF2F3F1),
      surfaceContainer:
          isDark ? const Color(0xFF22262B) : const Color(0xFFEDEEEB),
      surfaceContainerHigh:
          isDark ? const Color(0xFF292D33) : const Color(0xFFE7E9E5),
      surfaceContainerHighest:
          isDark ? const Color(0xFF30353B) : const Color(0xFFE1E4DF),
      onSurface: isDark ? const Color(0xFFE6E8EB) : const Color(0xFF20252B),
      onSurfaceVariant:
          isDark ? const Color(0xFFADB4BE) : const Color(0xFF56616D),
      outlineVariant:
          isDark ? const Color(0xFF373E46) : const Color(0xFFDDE1DC),
    );
    final base = ThemeData(
      brightness: brightness,
      useMaterial3: useMaterial3,
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
    );
    final text = base.textTheme.copyWith(
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
      titleSmall: base.textTheme.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.5),
      bodySmall: base.textTheme.bodySmall?.copyWith(
        color: colors.onSurfaceVariant,
        height: 1.4,
      ),
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    return base.copyWith(
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: shape,
        margin: const EdgeInsets.all(4),
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        thickness: 0.7,
        space: 24,
      ),
      iconTheme: IconThemeData(color: colors.onSurfaceVariant, size: 22),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: colors.onSurfaceVariant,
        titleTextStyle: text.titleSmall?.copyWith(fontSize: 16),
        subtitleTextStyle: text.bodySmall,
        shape: shape,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerLow,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.onSurface,
          side: BorderSide(color: colors.outlineVariant),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: colors.surfaceContainerLow,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: text.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colors.primary,
        unselectedLabelColor: colors.onSurfaceVariant,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontSize: 14),
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

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
