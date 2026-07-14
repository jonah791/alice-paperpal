import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../../core/models/soul.dart';
import '../../core/interfaces/services.dart';
import '../../core/di/dependencies.dart';
import '../../core/tokens/design_tokens.dart';
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

    final soulService = context.soulService;
    final active = soulService.getActiveOrDefault();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                buildDefaultAvatar(active.name, 40, context.avatarService.colorForName(active.name)),
                const SizedBox(width: Spacing.md),
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
            const SizedBox(height: Spacing.lg),
            Text('切换灵魂', style: theme.textTheme.titleSmall),
            const SizedBox(height: Spacing.gap),
            _buildPresetGrid(theme, soulService, active),
            const SizedBox(height: Spacing.md),
            if (soulService.custom.isNotEmpty) ...[
              Text('自定义灵魂', style: theme.textTheme.titleSmall),
              const SizedBox(height: Spacing.gap),
              ...soulService.custom.map((s) => _buildCustomTile(context, theme, soulService, s, active)),
            ],
            const SizedBox(height: Spacing.gap),
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

  Widget _buildPresetGrid(ThemeData theme, ISoulService soulService, Soul active) {
    return Wrap(
      spacing: Spacing.gap,
      runSpacing: Spacing.gap,
      children: soulService.presets.map((s) {
        final isActive = s.id == active.id;
        return ChoiceChip(
          selected: isActive,
          label: Text(s.name, style: TextStyle(fontSize: DesignTokens.fsMd, color: isActive ? theme.colorScheme.secondary : null)),
          onSelected: (_) async {
            await soulService.setActiveSoul(s);
            if (mounted) setState(() {});
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

  Widget _buildCustomTile(BuildContext context, ThemeData theme, ISoulService soulService, Soul s, Soul active) {
    final isActive = s.id == active.id;

    return ListTile(
      dense: true,
      leading: buildDefaultAvatar(s.name, 28, context.avatarService.colorForName(s.name)),
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
        if (mounted) setState(() {});
      },
    );
  }

  Widget _buildCreator(BuildContext context, ThemeData theme, ISoulService soulService) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    bool loading = false;

    return StatefulBuilder(
      builder: (ctx, setLocalState) => Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(RadiusTokens.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('描述你想要的 AI 伙伴', style: theme.textTheme.bodySmall),
            const SizedBox(height: Spacing.gap),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '给伙伴起个名字',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: Spacing.gap),
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
            const SizedBox(height: Spacing.gap),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => _creating = false),
                  child: const Text('取消'),
                ),
                const SizedBox(width: Spacing.gap),
                FilledButton.icon(
                  onPressed: loading ? null : () async {
                    if (nameController.text.trim().isEmpty) return;
                    setLocalState(() => loading = true);
                    try {
                  
                      final soul = await context.soulService.createCustomSoul(
                        nameController.text.trim(),
                        descController.text.trim(),
                        context.llmProvider,
                      );
                      await context.soulService.setActiveSoul(soul);
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
                      ? const SizedBox(width: DesignTokens.iconLg, height: DesignTokens.iconLg, child: CircularProgressIndicator(strokeWidth: DesignTokens.borderXl))
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

  void _deleteSoul(BuildContext context, ISoulService soulService, Soul s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除伙伴'),
        content: Text('确定删除"${s.name}"吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () async {
            await soulService.deleteCustomSoul(s.id);
            if (mounted) setState(() {});
            if (ctx.mounted) Navigator.pop(ctx);
          }, child: const Text('删除')),
        ],
      ),
    );
  }
}
