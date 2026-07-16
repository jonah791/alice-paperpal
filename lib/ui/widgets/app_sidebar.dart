/// Kori 风格侧边栏 — 导航 + 论文分类
library;

import 'package:flutter/material.dart';
import '../../core/tokens/design_tokens.dart';

/// 侧边栏菜单项
enum NavItem {
  search('搜索', Icons.search, 'search'),
  library('论文库', Icons.library_books, 'library'),
  templates('笔记模板', Icons.description_outlined, 'templates'),
  settings('设置', Icons.settings, 'settings');

  final String label;
  final IconData icon;
  final String id;
  const NavItem(this.label, this.icon, this.id);
}

/// Kori 风格侧边栏
class AppSidebar extends StatelessWidget {
  final NavItem selectedItem;
  final int paperCount;
  final int starredCount;
  final int templateCount;
  final void Function(NavItem) onItemSelected;
  final VoidCallback? onThemeToggle;
  final bool isDark;

  const AppSidebar({
    super.key,
    required this.selectedItem,
    this.paperCount = 0,
    this.starredCount = 0,
    this.templateCount = 0,
    required this.onItemSelected,
    this.onThemeToggle,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // App logo area
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              const SizedBox(width: 12),
              Text(
                'PaperPal',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Playfair Display',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Nav items
        ...NavItem.values.map((item) => _NavItemTile(
          item: item,
          isSelected: item == selectedItem,
          badge: item == NavItem.search
              ? null
              : item == NavItem.library ? '$paperCount'
              : item == NavItem.templates ? '$templateCount'
              : null,
          onTap: () => onItemSelected(item),
        )),

        const Spacer(),

        // Theme toggle at bottom
        if (onThemeToggle != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: IconButton(
              icon: Icon(
                isDark ? Icons.light_mode : Icons.dark_mode,
                size: DesignTokens.iconMd,
              ),
              tooltip: isDark ? '浅色模式' : '深色模式',
              onPressed: onThemeToggle,
            ),
          ),
      ],
    );
  }
}

class _NavItemTile extends StatelessWidget {
  final NavItem item;
  final bool isSelected;
  final String? badge;
  final VoidCallback onTap;

  const _NavItemTile({
    required this.item,
    required this.isSelected,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected ? colors.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(item.icon, size: 20,
                    color: isSelected ? colors.onSecondaryContainer : colors.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? colors.onSecondaryContainer : colors.onSurfaceVariant,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge!,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
