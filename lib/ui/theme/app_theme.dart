/// PaperPal 主题系统 — 融合 Kori 配色 + Alice 奇幻主题
///
/// 7 个主题变体: Blue / Cyan / Green / Orange / Red / Black / Alice
/// 每个变体有完整 light/dark ColorScheme（含 M3 所有 surface 层级）
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/config.dart';
import '../../core/tokens/design_tokens.dart';
import '../widgets/page_transition.dart';
import 'themes/theme_variant.dart';
import 'themes/kori_blue.dart';
import 'themes/kori_cyan.dart';
import 'themes/kori_green.dart';
import 'themes/kori_orange.dart';
import 'themes/kori_red.dart';
import 'themes/kori_black.dart';
import 'themes/alice.dart';

extension AppThemeModeX on AppThemeMode {
  ThemeMode toFlutterThemeMode() {
    return switch (this) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };
  }
}

/// All 7 theme variants with their light/dark ColorScheme pairs.
(ColorScheme light, ColorScheme dark) colorSchemeForVariant(ThemeVariant variant) {
  return switch (variant) {
    ThemeVariant.blue => (LightBlueColors, DarkBlueColors),
    ThemeVariant.cyan => (LightCyanColors, DarkCyanColors),
    ThemeVariant.green => (LightGreenColors, DarkGreenColors),
    ThemeVariant.orange => (LightOrangeColors, DarkOrangeColors),
    ThemeVariant.red => (LightRedColors, DarkRedColors),
    ThemeVariant.black => (LightBlackColors, DarkBlackColors),
    ThemeVariant.alice => (LightAliceColors, DarkAliceColors),
  };
}

class AppTheme {
  AppTheme._();

  /// Build complete ThemeData from a variant + brightness.
  static ThemeData fromVariant(ThemeVariant variant, Brightness brightness, {bool amoled = false}) {
    final (light, dark) = colorSchemeForVariant(variant);
    final isDark = brightness == Brightness.dark;
    var colors = isDark ? dark : light;

    // AMOLED mode: push background/surface to pure black
    if (isDark && amoled) {
      colors = colors.copyWith(
        background: const Color(0xFF000000),
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
        ? (amoled ? const Color(0xFF000000) : colors.background)
        : colors.background;

    final Color tc = isDark ? colors.onSurface : colors.onSurface;

    const sans = GoogleFonts.inter;
    const serif = GoogleFonts.playfairDisplay;

    final textTheme = TextTheme(
      displayLarge: serif(fontSize: DesignTokens.fs9xl, fontWeight: FontWeight.w700, color: tc),
      displayMedium: serif(fontSize: DesignTokens.fs8xl, fontWeight: FontWeight.w700, color: tc),
      displaySmall: serif(fontSize: DesignTokens.fs7xl, fontWeight: FontWeight.w600, color: tc),
      headlineLarge: serif(fontSize: DesignTokens.fs6xl, fontWeight: FontWeight.w600, color: tc),
      headlineMedium: serif(fontSize: DesignTokens.fs5xl, fontWeight: FontWeight.w600, color: tc),
      headlineSmall: serif(fontSize: DesignTokens.fs4xl, fontWeight: FontWeight.w500, color: tc),
      titleLarge: serif(fontSize: DesignTokens.fs3xl, fontWeight: FontWeight.w500, color: tc),
      titleMedium: serif(fontSize: DesignTokens.fsXl, fontWeight: FontWeight.w500, color: tc),
      titleSmall: serif(fontSize: DesignTokens.fsLg, fontWeight: FontWeight.w500, color: tc),
      bodyLarge: sans(fontSize: DesignTokens.fsXl, fontWeight: FontWeight.w400, color: tc),
      bodyMedium: sans(fontSize: DesignTokens.fsLg, fontWeight: FontWeight.w400, color: tc),
      bodySmall: sans(fontSize: DesignTokens.fsSm, fontWeight: FontWeight.w400, color: tc),
      labelLarge: sans(fontSize: DesignTokens.fsLg, fontWeight: FontWeight.w500, color: tc),
      labelMedium: sans(fontSize: DesignTokens.fsSm, fontWeight: FontWeight.w500, color: tc),
      labelSmall: sans(fontSize: DesignTokens.fsXs, fontWeight: FontWeight.w500, color: tc),
    );

    final cardTheme = CardThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        side: BorderSide(color: colors.primary.withValues(alpha: DesignTokens.opacityFaint)),
      ),
      elevation: DesignTokens.borderNone,
      margin: const EdgeInsets.only(bottom: DesignTokens.spGap),
      color: isDark ? colors.surfaceContainerLow : colors.surface,
    );

    final inputTheme = InputDecorationTheme(
      filled: true,
      fillColor: isDark ? colors.surfaceContainerLow : colors.surfaceContainerLowest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        borderSide: BorderSide(color: colors.outline.withValues(alpha: DesignTokens.opacityMedium)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        borderSide: BorderSide(color: colors.outline.withValues(alpha: DesignTokens.opacityMedium)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        borderSide: BorderSide(color: colors.primary, width: DesignTokens.borderLg),
      ),
      contentPadding: padSym(h: DesignTokens.sp4, v: DesignTokens.sp2),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colors,
      scaffoldBackgroundColor: scaffoldBg,
      textTheme: textTheme,
      cardTheme: cardTheme,
      inputDecorationTheme: inputTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: DesignTokens.fsLg,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: DesignTokens.borderNone,
        backgroundColor: scaffoldBg,
        foregroundColor: colors.onSurface,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        labelType: NavigationRailLabelType.all,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? colors.surfaceContainerLow : colors.surface,
        indicatorColor: colors.secondaryContainer,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.windows: const KoriPageTransition(),
          TargetPlatform.android: const KoriPageTransition(),
          TargetPlatform.iOS: const KoriPageTransition(),
        },
      ),
    );
  }

  // Shortcuts for the default Alice theme (backward compatibility)
  static ThemeData get light => fromVariant(ThemeVariant.alice, Brightness.light);
  static ThemeData get dark => fromVariant(ThemeVariant.alice, Brightness.dark);
}
