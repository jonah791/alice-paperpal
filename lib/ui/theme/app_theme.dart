/// PaperPal 主题系统 — Kori 风格
///
/// 7 个主题变体: Blue / Cyan / Green / Orange / Red / Black / Alice
/// 使用 ColorScheme.fromSeed 确保 Flutter 3.41 兼容
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/config.dart';
import '../../core/tokens/design_tokens.dart';
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

// ─── Seed Colors ────────────────────────────────────────────────

(int, int) _seedFor(ThemeVariant v) {
  return switch (v) {
    ThemeVariant.blue => (0xFF415F91, 0xFFAAC7FF),
    ThemeVariant.cyan => (0xFF006A6A, 0xFF4FD8D8),
    ThemeVariant.green => (0xFF2E7D32, 0xFFA5D6A7),
    ThemeVariant.orange => (0xFFE65100, 0xFFFFCC80),
    ThemeVariant.red => (0xFFC62828, 0xFFEF9A9A),
    ThemeVariant.black => (0xFF424242, 0xFFBDBDBD),
    ThemeVariant.alice => (0xFF5C2D91, 0xFFD1A3FF),
  };
}

ColorScheme _makeScheme(ThemeVariant variant, Brightness brightness) {
  final (lightSeed, darkSeed) = _seedFor(variant);
  final isDark = brightness == Brightness.dark;
  final seed = Color(isDark ? darkSeed : lightSeed);

  final base = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
  );

  return base;
}

/// 公开的 ColorScheme 获取函数（供 theme_selector 等组件使用）
ColorScheme colorSchemeForVariant(ThemeVariant variant, [Brightness brightness = Brightness.light]) {
  return _makeScheme(variant, brightness);
}

class AppTheme {
  AppTheme._();

  /// Build complete ThemeData from a variant + brightness.
  static ThemeData fromVariant(ThemeVariant variant, Brightness brightness, {bool amoled = false}) {
    final colors = _makeScheme(variant, brightness);
    final isDark = brightness == Brightness.dark;

    // 最终颜色方案：AMOLED 覆盖 surface
    var finalColors = colors;
    if (isDark && amoled) {
      finalColors = colors.copyWith(
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

    final scaffoldBg = isDark
        ? (amoled ? const Color(0xFF000000) : finalColors.surface)
        : finalColors.surface;

    final tc = finalColors.onSurface;

    const sans = GoogleFonts.inter;
    const serif = GoogleFonts.playfairDisplay;

    final textTheme = TextTheme(
      displayLarge: serif(fontSize: 57, fontWeight: FontWeight.w700, color: tc),
      displayMedium: serif(fontSize: 45, fontWeight: FontWeight.w700, color: tc),
      displaySmall: serif(fontSize: 36, fontWeight: FontWeight.w600, color: tc),
      headlineLarge: serif(fontSize: 32, fontWeight: FontWeight.w600, color: tc),
      headlineMedium: serif(fontSize: 28, fontWeight: FontWeight.w600, color: tc),
      headlineSmall: serif(fontSize: 24, fontWeight: FontWeight.w500, color: tc),
      titleLarge: serif(fontSize: 20, fontWeight: FontWeight.w500, color: tc),
      titleMedium: serif(fontSize: 16, fontWeight: FontWeight.w500, color: tc),
      titleSmall: serif(fontSize: 14, fontWeight: FontWeight.w500, color: tc),
      bodyLarge: sans(fontSize: 16, fontWeight: FontWeight.w400, color: tc),
      bodyMedium: sans(fontSize: 14, fontWeight: FontWeight.w400, color: tc),
      bodySmall: sans(fontSize: 12, fontWeight: FontWeight.w400, color: tc),
      labelLarge: sans(fontSize: 14, fontWeight: FontWeight.w500, color: tc),
      labelMedium: sans(fontSize: 12, fontWeight: FontWeight.w500, color: tc),
      labelSmall: sans(fontSize: 11, fontWeight: FontWeight.w500, color: tc),
    );

    final cardTheme = CardThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: finalColors.outline.withValues(alpha: 0.1)),
      ),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? finalColors.surfaceContainerLow : finalColors.surface,
    );

    final inputTheme = InputDecorationTheme(
      filled: true,
      fillColor: isDark ? finalColors.surfaceContainerLow : finalColors.surfaceContainerLowest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: finalColors.outline.withValues(alpha: 0.4)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: finalColors.outline.withValues(alpha: 0.4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: finalColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: finalColors,
      scaffoldBackgroundColor: scaffoldBg,
      textTheme: textTheme,
      cardTheme: cardTheme,
      inputDecorationTheme: inputTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: finalColors.primary,
          foregroundColor: finalColors.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: finalColors.outlineVariant,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: scaffoldBg,
        foregroundColor: finalColors.onSurface,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.windows: KoriPageTransition(),
          TargetPlatform.android: KoriPageTransition(),
          TargetPlatform.iOS: KoriPageTransition(),
        },
      ),
    );
  }

  // Shortcuts for the default Alice theme (backward compatibility)
  static ThemeData get light => fromVariant(ThemeVariant.alice, Brightness.light);
  static ThemeData get dark => fromVariant(ThemeVariant.alice, Brightness.dark);
}
