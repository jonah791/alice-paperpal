/// Kori 风格骨架屏加载器
import 'package:flutter/material.dart';

class SkeletonLoader extends StatelessWidget {
  final double height;
  final BorderRadiusGeometry? borderRadius;
  final double width;
  const SkeletonLoader({
    super.key,
    this.height = 16,
    this.borderRadius,
    this.width = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
    );
  }
}
