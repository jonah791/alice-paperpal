import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../../core/models/paper.dart';
import '../../core/di/dependencies.dart';
import '../../core/tokens/design_tokens.dart';
import 'read_page.dart';
import 'comparison_page.dart';
import '../widgets/skeleton_loader.dart';

final _log = Logger('LibraryPage');

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final _selected = <String>{};
  var _filterStatus = PaperStatus.values.length; // index for "all"

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);


    return Column(
      children: [
        _buildSelectionBar(theme),
        _buildFilterBar(context, theme),
        Expanded(
          child: StreamBuilder<List<Paper>>(
            stream: context.paperService.paperStream,
            initialData: context.paperService.papers,
            builder: (context, snapshot) {
              final allPapers = snapshot.data ?? [];
              final papers = _filterStatus < PaperStatus.values.length
                  ? allPapers.where((p) => p.status == PaperStatus.values[_filterStatus]).toList()
                  : allPapers;

              if (allPapers.isEmpty) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                    return Padding(
                      padding: const EdgeInsets.all(Spacing.lg),
                      child: ListView(
                        children: List.generate(5, (i) => Padding(
                          padding: const EdgeInsets.only(bottom: Spacing.gap),
                          child: SkeletonLoader(height: 80, borderRadius: RadiusTokens.lg),
                      )),
                    ),
                  );
                }
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.library_books_outlined, size: 64,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(height: Spacing.lg),
                      Text('还没有论文', style: theme.textTheme.titleMedium),
                      const SizedBox(height: Spacing.gap),
                      Text('去搜索页找一篇吧', style: theme.textTheme.bodySmall),
                    ],
                  ),
                );
              }

              if (papers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.filter_alt_off, size: 48,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(height: Spacing.lg),
                      Text('当前筛选条件下没有论文', style: theme.textTheme.bodyMedium),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(Spacing.lg),
                itemCount: papers.length,
                itemBuilder: (context, index) =>
                    _buildPaperCard(context, papers[index], theme),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionBar(ThemeData theme) {
    if (_selected.length < 2) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.gap),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Text('已选 ${_selected.length} 篇', style: theme.textTheme.bodySmall),
          const Spacer(),
          if (_selected.length >= 2)
            FilledButton.tonalIcon(
              onPressed: _compareSelected,
              icon: const Icon(Icons.compare_arrows, size: DesignTokens.sp4),
              label: const Text('对比'),
            ),
          const SizedBox(width: Spacing.gap),
          FilledButton.tonalIcon(
            onPressed: _deleteSelected,
            icon: const Icon(Icons.delete_outline, size: DesignTokens.sp4),
            label: const Text('删除'),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.errorContainer,
              foregroundColor: theme.colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(width: Spacing.gap),
          TextButton(
            onPressed: () => setState(() => _selected.clear()),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, ThemeData theme) {
    final filterLabels = [
      '全部',
      PaperStatus.importing.label,
      PaperStatus.parsing.label,
      PaperStatus.parsed.label,
      PaperStatus.translating.label,
      PaperStatus.translated.label,
      PaperStatus.error.label,
    ];

    return Container(
      padding: padSym(h: Spacing.lg, v: Spacing.sm),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(filterLabels.length, (i) {
            final selected = _filterStatus == i;
            final status = i == 0 ? null : PaperStatus.values[i - 1];
            return Padding(
              padding: padOnly(r: Spacing.sm),
              child: FilterChip(
                label: Text(filterLabels[i], style: const TextStyle(fontSize: DesignTokens.fsSm)),
                selected: selected,
                selectedColor: status?.color(context)?.withValues(alpha: 0.2),
                checkmarkColor: status?.color(context),
                onSelected: (_) => setState(() => _filterStatus = i),
            ));
          }),
        ),
      ),
    );
  }

  Widget _buildPaperCard(BuildContext context, Paper paper, ThemeData theme) {
    final isSelected = _selected.contains(paper.id);
    final isReadable = paper.status == PaperStatus.parsed || paper.status == PaperStatus.translated;
    final suits = ['\u2660', '\u2665', '\u2666', '\u2663'];
    final suit = suits[(paper.id.hashCode) % 4];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: Spacing.gap),
        color: isSelected ? theme.colorScheme.primaryContainer : null,
        child: InkWell(
          borderRadius: BorderRadius.circular(RadiusTokens.lg),
          onTap: () {
            if (_selected.isNotEmpty) {
              _toggleSelection(paper.id);
            } else if (isReadable) {
              _log.info('open: ${paper.title}');
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ReadPage(paper: paper)),
              );
            }
          },
          onLongPress: () => _toggleSelection(paper.id),
          child: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.3),
                    width: 3,
                  ),
                ),
              ),
              child: Row(
                children: [
                  if (_selected.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: Spacing.md),
                      child: Icon(
                        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 20,
                        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(suit, style: theme.textTheme.titleSmall),
                            const SizedBox(width: Spacing.gap),
                            Expanded(
                              child: Text(paper.title,
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        if (paper.authors.isNotEmpty) ...[
                          const SizedBox(height: DesignTokens.sp1),
                          Text(paper.authors.join(', '),
                              style: theme.textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: Spacing.lg),
                  Chip(
                    label: Text(_statusText(paper.status), style: const TextStyle(fontSize: DesignTokens.fsXs)),
                    backgroundColor: paper.status.color(context).withValues(alpha: 0.1),
                    side: BorderSide(color: paper.status.color(context).withValues(alpha: 0.3)),
                  ),
                  if (_selected.isEmpty)
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'delete') _confirmDelete(paper);
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'delete', child: Text('删除')),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _compareSelected() {
    if (_selected.length < 2) return;

    final papers = context.paperService.papers.where((p) => _selected.contains(p.id)).toList();
    _selected.clear();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ComparisonPage(papers: papers)),
    );
  }

  Future<void> _deleteSelected() async {
    final ids = _selected.toList();
    setState(() => _selected.clear());
    var deleted = 0;
    try {
  
      for (final id in ids) {
        await context.paperService.deletePaper(id);
        deleted++;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除 $deleted 篇论文')),
        );
      }
    } catch (e) {
      _log.warning('deleteSelected failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  Future<void> _confirmDelete(Paper paper) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除"${paper.title}"吗？\n解析结果和笔记将一并删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
  
      await context.paperService.deletePaper(paper.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除: ${paper.title}')),
        );
      }
    } catch (e) {
      _log.warning('deletePaper failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  String _statusText(PaperStatus s) => switch (s) {
    PaperStatus.importing => '导入中',
    PaperStatus.downloading => '下载中',
    PaperStatus.parsing => '解析中',
    PaperStatus.parsed => '已解析',
    PaperStatus.translating => '翻译中',
    PaperStatus.translated => '已翻译',
    PaperStatus.error => '错误',
  };
}

extension on PaperStatus {
  Color color(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return switch (this) {
      PaperStatus.importing => cs.tertiary,
      PaperStatus.downloading => cs.tertiary,
      PaperStatus.parsing => cs.primary,
      PaperStatus.parsed => cs.secondary,
      PaperStatus.translating => cs.primary,
      PaperStatus.translated => cs.primary,
      PaperStatus.error => cs.error,
    };
  }

  String get label => switch (this) {
    PaperStatus.importing => '导入中',
    PaperStatus.downloading => '下载中',
    PaperStatus.parsing => '解析中',
    PaperStatus.parsed => '已解析',
    PaperStatus.translating => '翻译中',
    PaperStatus.translated => '已翻译',
    PaperStatus.error => '错误',
  };
}
