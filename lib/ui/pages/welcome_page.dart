import 'package:flutter/material.dart';

class WelcomePage extends StatelessWidget {
  final VoidCallback onComplete;
  const WelcomePage({super.key, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 480,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PaperPal', style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('基于 MinerU + DeepSeek 的论文辅助阅读工具',
                    style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 32),
                Text('首次使用？请在设置页配置 API Key 后开始使用。', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onComplete,
                  child: const Text('进入设置'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
