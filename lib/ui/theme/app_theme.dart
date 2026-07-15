import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/config.dart';
import '../../core/tokens/design_tokens.dart';
import '../widgets/page_transition.dart';

extension AppThemeModeX on AppThemeMode {
  ThemeMode toFlutterThemeMode() {
    return switch (this) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };
  }
}

class AppTheme {
  AppTheme._();

  static ColorScheme _darkColors() {
    return const ColorScheme.dark(
      primary: Color(0xFFE8B84B),
      onPrimary: Color(0xFF1A1025),
      secondary: Color(0xFF9B6DF7),
      onSecondary: Color(0xFFFFFFFF),
      surface: Color(0xFF120C1F),
      onSurface: Color(0xFFEDE4D8),
    );
  }

  static ColorScheme _lightColors() {
    return const ColorScheme.light(
      primary: Color(0xFFC28A2C),
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFF6D28D9),
      onSecondary: Color(0xFFFFFFFF),
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF1A1025),
    );
  }

  static Color _textColor(Brightness b) =>
      b == Brightness.dark ? const Color(0xFFEDE4D8) : const Color(0xFF1A1025);

  static TextTheme _textTheme(Brightness brightness) {
    final Color tc = _textColor(brightness);
    const sans = GoogleFonts.inter;
    const serif = GoogleFonts.playfairDisplay;

    return TextTheme(
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
  }

  static CardThemeData _cardTheme(Brightness brightness) {
    final Color gold = brightness == Brightness.dark
        ? const Color(0xFFE8B84B)
        : const Color(0xFFC28A2C);

    return CardThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        side: BorderSide(color: gold.withValues(alpha: DesignTokens.opacityFaint)),
      ),
      elevation: DesignTokens.borderNone,
      margin: const EdgeInsets.only(bottom: DesignTokens.spGap),
    );
  }

  static InputDecorationTheme _inputTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final Color fill = isDark ? const Color(0xFF120C1F) : const Color(0xFFF5F0EB);
    final Color gold = isDark ? const Color(0xFFE8B84B) : const Color(0xFFC28A2C);

    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        borderSide: BorderSide(color: gold.withValues(alpha: DesignTokens.opacityMedium)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        borderSide: BorderSide(color: gold.withValues(alpha: DesignTokens.opacityMedium)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        borderSide: BorderSide(color: gold, width: DesignTokens.borderLg),
      ),
      contentPadding: padSym(h: DesignTokens.sp4, v: DesignTokens.sp2),
    );
  }

  static ElevatedButtonThemeData _buttonTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final Color gold = isDark ? const Color(0xFFE8B84B) : const Color(0xFFC28A2C);
    final Color onGold = isDark ? const Color(0xFF1A1025) : const Color(0xFFFFFFFF);

    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: onGold,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: DesignTokens.fsLg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static ThemeData _base(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme colors = isDark ? _darkColors() : _lightColors();
    final Color scaffoldBg = isDark ? const Color(0xFF07050D) : const Color(0xFFFFFBF3);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colors,
      scaffoldBackgroundColor: scaffoldBg,
      textTheme: _textTheme(brightness),
      cardTheme: _cardTheme(brightness),
      inputDecorationTheme: _inputTheme(brightness),
      elevatedButtonTheme: _buttonTheme(brightness),
      dividerTheme: DividerThemeData(
        color: colors.onSurface.withValues(alpha: DesignTokens.opacityFaint),
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
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.windows: SlideInTransitionBuilder(),
          TargetPlatform.android: SlideInTransitionBuilder(),
          TargetPlatform.iOS: SlideInTransitionBuilder(),
        },
      ),
    );
  }

  static ThemeData get light => _base(Brightness.light);
  static ThemeData get dark => _base(Brightness.dark);
}
