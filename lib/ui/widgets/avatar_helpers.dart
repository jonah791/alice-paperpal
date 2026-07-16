/// 头像工具
import 'package:flutter/material.dart';

Widget buildDefaultAvatar(String name, double size, int colorValue) {
  final color = Color(colorValue);
  final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
  return CircleAvatar(
    radius: size / 2,
    backgroundColor: color.withValues(alpha: 0.2),
    child: Text(initial, style: TextStyle(fontSize: size * 0.5, fontWeight: FontWeight.w600, color: color)),
  );
}
