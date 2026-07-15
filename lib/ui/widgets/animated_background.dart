import 'dart:math' as math;

import 'package:flutter/material.dart';

class AnimatedBackground extends StatefulWidget {
  final Widget child;
  const AnimatedBackground({super.key, required this.child});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;

    return Stack(
      children: [
        RepaintBoundary(
          child: Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _GradientPainter(
                    value: _controller.value,
                    primary: primary,
                    secondary: secondary,
                  ),
                );
              },
            ),
          ),
        ),
        RepaintBoundary(
          child: Positioned.fill(
            child: CustomPaint(
              painter: _SuitPatternPainter(textColor: secondary),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _GradientPainter extends CustomPainter {
  final double value;
  final Color primary;
  final Color secondary;

  _GradientPainter({
    required this.value,
    required this.primary,
    required this.secondary,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c1 = primary.withValues(alpha: 0.06);
    final c2 = secondary.withValues(alpha: 0.04);
    final w = size.width;
    final h = size.height;
    final angle = value * 2 * math.pi;

    for (int i = 0; i < 3; i++) {
      final phase = i * 2.094;
      final cx = w * (0.5 + 0.3 * math.sin(angle * 0.3 + phase));
      final cy = h * (0.5 + 0.3 * math.cos(angle * 0.2 + phase));
      final radius = w * 0.6;

      final a = i.isEven ? c1 : c2;
      final paint = Paint()..shader = RadialGradient(
        colors: [a, a.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius));

      canvas.drawRect(Offset.zero & size, paint);
    }
  }

  @override
  bool shouldRepaint(_GradientPainter oldDelegate) {
    return oldDelegate.value != value;
  }
}

class _SuitPatternPainter extends CustomPainter {
  final Color textColor;

  const _SuitPatternPainter({required this.textColor});

  @override
  void paint(Canvas canvas, Size size) {
    const suits = ['\u2660', '\u2665', '\u2666', '\u2663'];
    const spacing = 80.0;
    final textStyle = TextStyle(
      color: textColor.withValues(alpha: 0.02),
      fontSize: 24,
    );

    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        final suit = suits[
            ((x / spacing).floor() + (y / spacing).floor()) % suits.length];
        final tp = TextPainter(
          text: TextSpan(text: suit, style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x, y));
      }
    }
  }

  @override
  bool shouldRepaint(_SuitPatternPainter oldDelegate) => false;
}
