/// Kori 风格自适应宽屏布局 — 宽屏显示侧栏 + 内容
/// 窄屏模式由 main.dart 的 Scaffold.drawer 处理
library;

import 'package:flutter/material.dart';

class AdaptiveDrawer extends StatelessWidget {
  final Widget drawer;
  final Widget body;

  const AdaptiveDrawer({
    super.key,
    required this.drawer,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 280,
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: SafeArea(child: drawer),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: body),
      ],
    );
  }
}
