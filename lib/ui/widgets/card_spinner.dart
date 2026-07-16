/// Kori 风格加载指示器 — 简洁 Material 3 风格
import 'package:flutter/material.dart';

class CardSpinner extends StatelessWidget {
  final double size;
  const CardSpinner({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 3,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
