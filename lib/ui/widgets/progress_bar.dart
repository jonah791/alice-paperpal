/// Kori 风格滚动进度条
import 'package:flutter/material.dart';

class ScrollProgressBar extends StatefulWidget {
  final ScrollController controller;
  const ScrollProgressBar({super.key, required this.controller});
  @override
  State<ScrollProgressBar> createState() => _ScrollProgressBarState();
}

class _ScrollProgressBarState extends State<ScrollProgressBar> {
  double _progress = 0;
  @override
  void initState() { super.initState(); widget.controller.addListener(_onScroll); }
  void _onScroll() {
    if (!widget.controller.hasClients) return;
    final p = widget.controller.position;
    final v = p.maxScrollExtent > 0 ? (p.pixels / p.maxScrollExtent).clamp(0.0, 1.0) : 0.0;
    if (v != _progress) setState(() => _progress = v);
  }
  @override
  void dispose() { widget.controller.removeListener(_onScroll); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: _progress, minHeight: 2,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
    );
  }
}
