/// Kori 风格主题选择器
library;

import 'package:flutter/material.dart';
import '../../core/tokens/design_tokens.dart';
import '../theme/themes/theme_variant.dart';
import '../theme/app_theme.dart';

/// 主题选择器 — 显示色块和名称
class ThemeSelector extends StatelessWidget {
  final ThemeVariant current;
  final ValueChanged<ThemeVariant> onChanged;

  const ThemeSelector({
    super.key,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('主题配色', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: ThemeVariant.values.map((v) {
              final lightScheme = colorSchemeForVariant(v, Brightness.light);
              final darkScheme = colorSchemeForVariant(v, Brightness.dark);
              final isSelected = v == current;
              return GestureDetector(
                onTap: () => onChanged(v),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? colors.primary
                              : colors.outlineVariant,
                          width: isSelected ? 2.5 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Column(
                          children: [
                            Expanded(
                              child: Container(color: lightScheme.primary),
                            ),
                            Expanded(
                              child: Container(color: darkScheme.primary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      v.labelCn,
                      style: TextStyle(
                        fontSize: DesignTokens.fsXs,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? colors.primary : colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
