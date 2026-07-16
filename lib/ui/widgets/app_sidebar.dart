/// Kori 风格侧边栏 — 从 NavigationDrawerContent.kt 移植
/// 项高度 52dp、间距 4dp、选中用 NavigationDrawerItem
import 'package:flutter/material.dart';
import '../../core/tokens/design_tokens.dart';
import '../../core/di/dependencies.dart';
import '../../core/interfaces/services.dart';

enum NavItem {
  library('文库', Icons.library_books_outlined),
  search('搜索', Icons.search),
  templates('模板', Icons.auto_stories),
  settings('设置', Icons.settings_outlined);

  final String label;
  final IconData icon;
  const NavItem(this.label, this.icon);
}

class AppSidebar extends StatelessWidget {
  final NavItem selectedItem;
  final void Function(NavItem) onItemSelected;
  final VoidCallback onThemeToggle;
  final int paperCount;
  final bool isDark;

  const AppSidebar({
    super.key,
    required this.selectedItem,
    required this.onItemSelected,
    required this.onThemeToggle,
    required this.paperCount,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final ss = context.soulService;
    final soul = ss.activeSoul ?? ss.getActiveOrDefault();

    return Column(
      children: [
        // 顶部：头像 + 灵魂名 — Kori style 56dp header
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: colors.primaryContainer,
                child: Text(
                  soul.name.isNotEmpty ? soul.name[0].toUpperCase() : '?',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onPrimaryContainer),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(soul.name, style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                )),
              ),
              // 切换主题按钮
              IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode : Icons.dark_mode,
                  size: 20,
                ),
                onPressed: onThemeToggle,
                style: IconButton.styleFrom(
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                ),
              ),
            ],
          ),
        ),
        // 导航项 — Kori: 52dp height, 4dp spacing
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: NavItem.values.map((item) {
              final isSelected = item == selectedItem;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SizedBox(
                  height: 52,
                  child: NavigationDrawerDestination(
                    icon: Icon(item.icon, size: 20),
                    selectedIcon: Icon(item.icon, size: 20, color: colors.primary),
                    label: Row(
                      children: [
                        Text(item.label, style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        )),
                        if (item == NavItem.library && paperCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$paperCount',
                              style: TextStyle(fontSize: 10, color: colors.onPrimaryContainer),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const Spacer(),
        // 版本号
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('PaperPal v0.5.0', style: TextStyle(
            fontSize: 10, color: colors.onSurfaceVariant.withValues(alpha: 0.4),
          )),
        ),
      ],
    );
  }
}

/// NavigationDrawerDestination 的 Material3 通配
class NavigationDrawerDestination extends StatelessWidget {
  final Widget icon;
  final Widget selectedIcon;
  final Widget label;
  final bool selected;

  const NavigationDrawerDestination({
    super.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: selected ? colors.secondaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              selected ? selectedIcon : icon,
              const SizedBox(width: 12),
              Expanded(child: label),
            ],
          ),
        ),
      ),
    );
  }
}
