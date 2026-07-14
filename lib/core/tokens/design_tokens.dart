import 'package:flutter/material.dart';

/// Design token system — single source of truth for all UI values.
/// No hardcoded numbers anywhere else.
class DesignTokens {
  DesignTokens._();

  // ─── Grid Base ────────────────────────────────────────────────
  static const double grid = 4;

  // ─── Spacing Scale (4px grid × n) ─────────────────────────────
  static const double sp0 = 0;
  static const double sp1 = grid;         // 4
  static const double sp2 = grid * 2;     // 8
  static const double sp3 = grid * 3;     // 12
  static const double sp4 = grid * 4;     // 16
  static const double sp5 = grid * 5;     // 20
  static const double sp6 = grid * 6;     // 24
  static const double sp7 = grid * 7;     // 28
  static const double sp8 = grid * 8;     // 32
  static const double sp10 = grid * 10;   // 40
  static const double sp12 = grid * 12;   // 48
  static const double sp16 = grid * 16;   // 64

  // Semantic spacing
  static const double spInset = sp4;      // card/section padding
  static const double spInsetSm = sp3;    // small card padding
  static const double spGap = sp2;        // between elements
  static const double spGapSm = sp1;      // tight spacing
  static const double spGapLg = sp4;      // section spacing
  static const double spSection = sp6;    // between sections
  static const double spPage = sp6;       // page edge padding

  // ─── Border Radius scale ──────────────────────────────────────
  static const double radiusNone = 0;
  static const double radiusSm = sp1;     // 4
  static const double radiusMd = sp2;     // 8
  static const double radiusLg = sp3;     // 12
  static const double radiusXl = sp4;     // 16
  static const double radiusFull = 999;   // pill

  // ─── Font Size Scale (modular 1.125) ──────────────────────────
  static const double fsXxs = 10;
  static const double fsXs = 11;
  static const double fsSm = 12;
  static const double fsMd = 13;
  static const double fsLg = 14;
  static const double fsXl = 16;
  static const double fs2xl = 18;
  static const double fs3xl = 20;
  static const double fs4xl = 24;
  static const double fs5xl = 28;
  static const double fs6xl = 32;
  static const double fs7xl = 36;
  static const double fs8xl = 45;
  static const double fs9xl = 57;

  // ─── Line Height ──────────────────────────────────────────────
  static const double lhTight = 1.2;
  static const double lhNormal = 1.5;
  static const double lhRelaxed = 1.7;
  static const double lhLoose = 2.0;

  // ─── Breakpoints ──────────────────────────────────────────────
  static const double bpMobile = 600;
  static const double bpTablet = 900;
  static const double bpDesktop = 1200;

  // ─── Layout Constraints ───────────────────────────────────────
  static const double maxContentWidth = 720;
  static const double maxReadingWidth = 800;

  // ─── Icon Sizes ──────────────────────────────────────────────
  static const double iconSm = 14;
  static const double iconMd = 18;
  static const double iconLg = 24;
  static const double iconXl = 32;

  // ─── Opacity ──────────────────────────────────────────────────
  static const double opacitySubtle = 0.06;
  static const double opacityFaint = 0.10;
  static const double opacityDim = 0.25;
  static const double opacityMedium = 0.40;
  static const double opacityStrong = 0.60;
  static const double opacityHigh = 0.80;

  // ─── Border widths ───────────────────────────────────────────
  static const double borderNone = 0;
  static const double borderSm = 0.5;
  static const double borderMd = 1;
  static const double borderLg = 1.5;
  static const double borderXl = 2;
}

// ─── Edge / Padding Helper ──────────────────────────────────────

/// Shortcut: `EdgeInsets.all(DesignTokens.sp4)` → `pad(DesignTokens.sp4)`
EdgeInsetsGeometry padAll(double value) => EdgeInsets.all(value);
EdgeInsetsGeometry padSym({double h = 0, double v = 0}) =>
    EdgeInsets.symmetric(horizontal: h, vertical: v);
EdgeInsetsGeometry padOnly({
  double l = 0, double t = 0, double r = 0, double b = 0,
}) => EdgeInsets.only(left: l, top: t, right: r, bottom: b);

// ─── Responsive Extensions ──────────────────────────────────────

extension ResponsiveContext on BuildContext {
  /// Returns `true` if the shortest side is less than [DesignTokens.bpMobile].
  bool get isMobile =>
      MediaQuery.of(this).size.shortestSide < DesignTokens.bpMobile;

  /// Returns spacing scaled by viewport width factor.
  /// At 1200px+ returns original; at <600px returns scaled proportionally.
  double adaptiveSpacing(double baseSpacing) {
    final width = MediaQuery.of(this).size.width;
    final scale = (width / DesignTokens.bpDesktop).clamp(0.7, 1.0);
    return baseSpacing * scale;
  }

  /// Returns the standard page horizontal padding (responsive).
  double get pagePadding => isMobile ? DesignTokens.sp4 : DesignTokens.sp6;
}

// ─── Const helpers (can be used in const constructors) ──────────

/// Use in const contexts: `pad(Spacing.lg)` instead of `EdgeInsets.all(16)`
class Spacing {
  static const double xs = DesignTokens.sp1;
  static const double sm = DesignTokens.sp2;
  static const double md = DesignTokens.sp3;
  static const double lg = DesignTokens.sp4;
  static const double xl = DesignTokens.sp6;
  static const double xxl = DesignTokens.sp8;
  static const double section = DesignTokens.sp6;
  static const double pageH = DesignTokens.sp6;
  static const double cardInset = DesignTokens.sp4;
  static const double gap = DesignTokens.sp2;
}

class RadiusTokens {
  static const double sm = DesignTokens.radiusSm;
  static const double md = DesignTokens.radiusMd;
  static const double lg = DesignTokens.radiusLg;
  static const double xl = DesignTokens.radiusXl;
  static const double full = DesignTokens.radiusFull;
}
