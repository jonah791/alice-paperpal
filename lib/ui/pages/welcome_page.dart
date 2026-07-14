import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/tokens/design_tokens.dart';

class WelcomePage extends StatelessWidget {
  final VoidCallback onComplete;
  const WelcomePage({super.key, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suits = ['♠', '♥', '♦', '♣'];

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 80,
              child: Stack(
                children: [
                  for (int i = 0; i < 12; i++)
                    Positioned(
                      top: i < 4 ? 0 : (i < 8 ? 20 : 40),
                      left: (i % 4) * 80.0 + 10,
                      child: Transform.rotate(
                        angle: (i % 4 - 1.5) * 0.15,
                        child: Text(
                          suits[i % 4],
                          style: TextStyle(
                            fontSize: 48,
                            color: theme.colorScheme.secondary.withValues(alpha: 0.06),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.lg),
            Text(
              'PaperPal',
              style: GoogleFonts.playfairDisplay(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                foreground: Paint()
                  ..shader = LinearGradient(
                    colors: [
                      theme.colorScheme.secondary,
                      const Color(0xFFFFE08A),
                      theme.colorScheme.secondary.withValues(alpha: 0.7),
                    ],
                  ).createShader(const Rect.fromLTWH(0, 0, 200, 50)),
              ),
            ),
            const SizedBox(height: Spacing.gap),
            Text(
              '— 掉进兔子洞，开启论文阅读之旅 —',
              style: GoogleFonts.playfairDisplay(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: DesignTokens.sp10),
            FilledButton(
              onPressed: onComplete,
              child: const Text('进入奇妙世界'),
            ),
          ],
        ),
      ),
    );
  }
}
