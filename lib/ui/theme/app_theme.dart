import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorSchemeSeed: const Color(0xFF1565C0),
    scaffoldBackgroundColor: const Color(0xFFF8F9FA),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
    ),

    navigationRailTheme: const NavigationRailThemeData(
      labelType: NavigationRailLabelType.all,
    ),
  );

  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorSchemeSeed: const Color(0xFF42A5F5),
    scaffoldBackgroundColor: const Color(0xFF121212),

    navigationRailTheme: const NavigationRailThemeData(
      labelType: NavigationRailLabelType.all,
    ),
  );
}
