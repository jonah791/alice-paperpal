/// Kori 风格灵魂选择器
import 'package:flutter/material.dart';
import '../../core/di/dependencies.dart';
import '../../core/interfaces/services.dart';
import '../../core/models/soul.dart';
import 'avatar_helpers.dart';

class SoulSelector extends StatefulWidget {
  const SoulSelector({super.key});

  @override
  State<SoulSelector> createState() => _SoulSelectorState();
}

class _SoulSelectorState extends State<SoulSelector> {
  List<Soul> _allSouls = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ss = context.soulService;
    final active = ss.activeSoul;
    _allSouls = [...ss.presets, ...ss.custom];
    if (active != null && !_allSouls.any((s) => s.id == active.id)) {
      _allSouls.insert(0, active);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final ss = context.soulService;
    final active = ss.activeSoul;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...(_allSouls.map((s) {
          final isActive = active?.id == s.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Card(
              elevation: 0,
              color: isActive ? colors.primaryContainer : colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: isActive
                    ? BorderSide(color: colors.primary.withValues(alpha: 0.3))
                    : BorderSide.none,
              ),
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                leading: buildDefaultAvatar(s.name, 28, context.avatarService.colorForName(s.name)),
                title: Text(s.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(s.description, style: const TextStyle(fontSize: 11), maxLines: 1),
                trailing: isActive ? Icon(Icons.check_circle, size: 18, color: colors.primary) : null,
                onTap: () async {
                  await ss.setActiveSoul(s);
                  if (mounted) setState(() {});
                },
              ),
            ),
          );
        })),
      ],
    );
  }
}
