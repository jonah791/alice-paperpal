/// PaperPal 主题系统 — Kori 风格 ColorScheme.fromSeed
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/config.dart';
import '../widgets/page_transition.dart';
import 'themes/theme_variant.dart';

extension AppThemeModeX on AppThemeMode {
  ThemeMode toFlutterThemeMode() {
    return switch (this) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };
  }
}

(int lightSeed, int darkSeed) _seedFor(ThemeVariant v) {
  return switch (v) {
    ThemeVariant.blue => (0xFF415F91, 0xFFAAC7FF),
    ThemeVariant.cyan => (0xFF00897B, 0xFF4FD8D8),
    ThemeVariant.green => (0xFF43A047, 0xFFA5D6A7),
    ThemeVariant.orange => (0xFFE65100, 0xFFFFCC80),
    ThemeVariant.red => (0xFFD81B60, 0xFFEF9A9A),
    ThemeVariant.black => (0xFF424242, 0xFFBDBDBD),
    ThemeVariant.alice => (0xFF5C2D91, 0xFFD1A3FF),
  };
}

ColorScheme _makeScheme(ThemeVariant variant, Brightness brightness) {
  final (lightSeed, darkSeed) = _seedFor(variant);
  final isDark = brightness == Brightness.dark;
  return ColorScheme.fromSeed(seedColor: Color(isDark ? darkSeed : lightSeed), brightness: brightness);
}

/// 公开函数（供 theme_selector 等使用）
ColorScheme colorSchemeForVariant(ThemeVariant variant, [Brightness brightness = Brightness.light]) {
  return _makeScheme(variant, brightness);
}

class AppTheme {
  AppTheme._();

  static ThemeData fromVariant(ThemeVariant variant, Brightness brightness, {bool amoled = false}) {
    var colors = _makeScheme(variant, brightness);
    final isDark = brightness == Brightness.dark;

    if (isDark && amoled) {
      colors = colors.copyWith(
        surface: const Color(0xFF000000),
        surfaceDim: const Color(0xFF000000),
        surfaceBright: const Color(0xFF0D0D0D),
        surfaceContainerLowest: const Color(0xFF000000),
        surfaceContainerLow: const Color(0xFF0A0A0A),
        surfaceContainer: const Color(0xFF121212),
        surfaceContainerHigh: const Color(0xFF1A1A1A),
        surfaceContainerHighest: const Color(0xFF222222),
      );
    }

    final scaffoldBg = isDark ? (amoled ? const Color(0xFF000000) : colors.surface) : colors.surface;
    final tc = colors.onSurface;
    const sans = GoogleFonts.inter;
    const serif = GoogleFonts.playfairDisplay;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colors,
      scaffoldBackgroundColor: scaffoldBg,
      textTheme: TextTheme(
        displayLarge: serif(fontSize: 57, fontWeight: FontWeight.w700, color: tc),
        displayMedium: serif(fontSize: 45, fontWeight: FontWeight.w700, color: tc),
        displaySmall: serif(fontSize: 36, fontWeight: FontWeight.w600, color: tc),
        headlineLarge: serif(fontSize: 32, fontWeight: FontWeight.w600, color: tc),
        headlineMedium: serif(fontSize: 28, fontWeight: FontWeight.w600, color: tc),
        headlineSmall: serif(fontSize: 24, fontWeight: FontWeight.w600, color: tc),
        titleLarge: serif(fontSize: 22, fontWeight: FontWeight.w600, color: tc),
        titleMedium: serif(fontSize: 16, fontWeight: FontWeight.w500, color: tc),
        titleSmall: serif(fontSize: 14, fontWeight: FontWeight.w500, color: tc),
        bodyLarge: sans(fontSize: 16, fontWeight: FontWeight.w400, color: tc),
        bodyMedium: sans(fontSize: 14, fontWeight: FontWeight.w400, color: tc),
        bodySmall: sans(fontSize: 12, fontWeight: FontWeight.w400, color: tc),
        labelLarge: sans(fontSize: 14, fontWeight: FontWeight.w500, color: tc),
        labelMedium: sans(fontSize: 12, fontWeight: FontWeight.w500, color: tc),
        labelSmall: sans(fontSize: 11, fontWeight: FontWeight.w500, color: tc),
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        color: isDark ? colors.surfaceContainerLow : colors.surface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? colors.surfaceContainerLow : colors.surfaceContainerLowest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
      ),
      dividerTheme: DividerThemeData(color: colors.outlineVariant),
      appBarTheme: AppBarTheme(
        centerTitle: false, elevation: 0,
        backgroundColor: scaffoldBg, foregroundColor: colors.onSurface,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.windows: KoriPageTransition(),
        TargetPlatform.android: KoriPageTransition(),
      }),
    );
  }

  static ThemeData get light => fromVariant(ThemeVariant.alice, Brightness.light);
  static ThemeData get dark => fromVariant(ThemeVariant.alice, Brightness.dark);
}
