/// Kori 风格欢迎页
import 'package:flutter/material.dart';
import '../../core/tokens/design_tokens.dart';

class WelcomePage extends StatelessWidget {
  final VoidCallback onComplete;
  const WelcomePage({super.key, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.auto_stories, size: 36, color: colors.onPrimaryContainer),
              ),
              const SizedBox(height: 24),
              Text('PaperPal', style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w700,
              )),
              const SizedBox(height: 8),
              Text(
                '一个入口，万种文档，有灵魂的 AI 伙伴',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              FilledButton(
                onPressed: onComplete,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('开始使用'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
