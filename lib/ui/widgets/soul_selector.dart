import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../../core/models/soul.dart';
import '../../core/services/soul_service.dart';
import '../../core/di/dependencies.dart';
import 'avatar_helpers.dart';

final _log = Logger('SoulSelector');

class SoulSelector extends StatefulWidget {
  const SoulSelector({super.key});

  @override
  State<SoulSelector> createState() => _SoulSelectorState();
}

class _SoulSelectorState extends State<SoulSelector> {
  bool _creating = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deps = Dependencies.of(context);
    final soulService = deps.soulService;
    final active = soulService.getActiveOrDefault();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                buildDefaultAvatar(active.name, 40, deps.avatarService.colorForName(active.name)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('当前伙伴', style: theme.textTheme.labelSmall),
                      Text(active.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      Text(active.description, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('切换灵魂', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _buildPresetGrid(theme, soulService, active),
            const SizedBox(height: 12),
            if (soulService.custom.isNotEmpty) ...[
              Text('自定义灵魂', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              ...soulService.custom.map((s) => _buildCustomTile(context, theme, soulService, s, active)),
            ],
            const SizedBox(height: 8),
            if (_creating)
              _buildCreator(context, theme, soulService)
            else
              OutlinedButton.icon(
                onPressed: () => setState(() => _creating = true),
                icon: const Icon(Icons.add),
                label: const Text('创建新伙伴'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetGrid(ThemeData theme, SoulService soulService, Soul active) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: soulService.presets.map((s) {
        final isActive = s.id == active.id;
        return ChoiceChip(
          selected: isActive,
          label: Text(s.name, style: TextStyle(fontSize: 13, color: isActive ? theme.colorScheme.secondary : null)),
          onSelected: (_) async {
            await soulService.setActiveSoul(s);
            setState(() {});
          },
          selectedColor: theme.colorScheme.secondaryContainer,
          backgroundColor: Colors.transparent,
          side: BorderSide(
            color: isActive ? theme.colorScheme.secondary : theme.colorScheme.outline,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCustomTile(BuildContext context, ThemeData theme, SoulService soulService, Soul s, Soul active) {
    final isActive = s.id == active.id;
    final deps = Dependencies.of(context);
    return ListTile(
      dense: true,
      leading: buildDefaultAvatar(s.name, 28, deps.avatarService.colorForName(s.name)),
      title: Text(s.name, style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive) const Icon(Icons.check, size: 16),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16),
            onPressed: () => _deleteSoul(context, soulService, s),
          ),
        ],
      ),
      onTap: () async {
        await soulService.setActiveSoul(s);
        setState(() {});
      },
    );
  }

  Widget _buildCreator(BuildContext context, ThemeData theme, SoulService soulService) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    bool loading = false;

    return StatefulBuilder(
      builder: (ctx, setLocalState) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('描述你想要的 AI 伙伴', style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '给伙伴起个名字',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '用自然语言描述（越具体越好）',
                hintText: '像一个毒舌但靠谱的算法工程师，用讽刺的语气指出论文的漏洞...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => _creating = false),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: loading ? null : () async {
                    if (nameController.text.trim().isEmpty) return;
                    setLocalState(() => loading = true);
                    try {
                      final deps = Dependencies.of(context);
                      final soul = await deps.soulService.createCustomSoul(
                        nameController.text.trim(),
                        descController.text.trim(),
                        deps.llmProvider,
                      );
                      await deps.soulService.setActiveSoul(soul);
                      setState(() {
                        _creating = false;
                      });
                    } catch (e) {
                      _log.warning('create failed: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('创建失败，请稍后重试')),
                        );
                      }
                    }
                    setLocalState(() => loading = false);
                  },
                  icon: loading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome),
                  label: const Text('生成并保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _deleteSoul(BuildContext context, SoulService soulService, Soul s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除伙伴'),
        content: Text('确定删除"${s.name}"吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () async {
            await soulService.deleteCustomSoul(s.id);
            setState(() {});
            if (ctx.mounted) Navigator.pop(ctx);
          }, child: const Text('删除')),
        ],
      ),
    );
  }
}
