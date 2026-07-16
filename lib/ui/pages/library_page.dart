/// Kori 风格论文库
library;

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'search_page.dart' show searchPageAction, SearchPageAction;
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

enum _SortMode { lastRead, imported, title }

class _LibraryPageState extends State<LibraryPage> {
  final _selected = <String>{};
  var _filterStatus = PaperStatus.values.length;
  var _sortMode = _SortMode.lastRead;
  final _searchController = TextEditingController();
  var _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Paper> _sorted(List<Paper> papers) {
    var result = papers;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((p) =>
        p.title.toLowerCase().contains(q) ||
        p.authors.any((a) => a.toLowerCase().contains(q))
      ).toList();
    }
    result = result.toList()..sort((a, b) {
      switch (_sortMode) {
        case _SortMode.lastRead:
          return (b.lastReadAt ?? b.importedAt ?? DateTime(2000))
              .compareTo(a.lastReadAt ?? a.importedAt ?? DateTime(2000));
        case _SortMode.imported:
          return (b.importedAt ?? DateTime(2000))
              .compareTo(a.importedAt ?? DateTime(2000));
        case _SortMode.title:
          return a.title.compareTo(b.title);
      }
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      children: [
        _buildSelectionBar(theme),
        _buildFilterBar(theme),
        // Search field
        Padding(
          padding: padSym(h: Spacing.lg, v: Spacing.sm),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '在文库中搜索...',
              prefixIcon: const Icon(Icons.search, size: DesignTokens.iconSm),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: colors.surfaceContainerHighest,
              isDense: true,
              contentPadding: padSym(v: Spacing.sm, h: Spacing.md),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: DesignTokens.iconSm),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
            ),
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Paper>>(
            stream: context.paperService.paperStream,
            initialData: context.paperService.papers,
            builder: (context, snapshot) {
              final allPapers = snapshot.data ?? [];
              final filtered = switch (_filterStatus) {
                0 => allPapers,
                1 => allPapers.where((p) => p.starred).toList(),
                _ => allPapers.where((p) => p.status == PaperStatus.values[_filterStatus - 2]).toList(),
              };
              final papers = _sorted(filtered);

              if (allPapers.isEmpty) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Padding(
                    padding: const EdgeInsets.all(Spacing.lg),
                    child: ListView(
                      children: List.generate(5, (i) => const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: SkeletonLoader(height: 80, borderRadius: BorderRadius.all(Radius.circular(12))),
                      )),
                    ),
                  );
                }
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.library_books_outlined, size: 64, color: colors.onSurfaceVariant),
                      const SizedBox(height: 16),
                      Text('还没有论文', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('搜索论文或直接上传 PDF', style: theme.textTheme.bodySmall),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => searchPageAction.value = SearchPageAction.search,
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text('去搜索'),
                      ),
                    ],
                  ),
                );
              }

              if (papers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.filter_alt_off, size: 48, color: colors.onSurfaceVariant),
                      const SizedBox(height: 16),
                      Text(_filterStatus != 0 || _searchQuery.isNotEmpty
                          ? '当前筛选条件下没有论文' : '没有匹配的论文',
                        style: theme.textTheme.bodyMedium),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  _buildSortBar(theme, papers.length),
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.only(
                        left: 16, right: 16,
                        bottom: _selected.isEmpty ? 4 : 0,
                      ),
                      itemCount: papers.length,
                      itemBuilder: (context, index) =>
                          _buildPaperCard(papers[index], theme, colors),
                    ),
                  ),
                  if (_selected.isEmpty && papers.isNotEmpty)
                    Padding(
                      padding: padSym(h: Spacing.lg, v: 4),
                      child: Text('长按卡片可多选对比或删除',
                        style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant.withValues(alpha: 0.4))),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPaperCard(Paper paper, ThemeData theme, ColorScheme colors) {
    final isSelected = _selected.contains(paper.id);
    final isReadable = paper.status == PaperStatus.parsed || paper.status == PaperStatus.translated;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 400),
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, 8 * (1 - value)), child: child),
        ),
        child: Card(
          elevation: isSelected ? 0 : 1,
          color: isSelected ? colors.primaryContainer : colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSelected
                ? BorderSide(color: colors.primary.withValues(alpha: 0.4))
                : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              if (_selected.isNotEmpty) {
                _toggleSelection(paper.id);
              } else if (isReadable) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => ReadPage(paper: paper)));
              }
            },
            onLongPress: () => _toggleSelection(paper.id),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selection checkbox
                  if (_selected.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 12, top: 2),
                      child: Icon(
                        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 20,
                        color: isSelected ? colors.primary : colors.onSurfaceVariant,
                      ),
                    ),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                paper.title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (paper.starred)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.star, size: 14, color: Colors.amber),
                              ),
                          ],
                        ),
                        if (paper.authors.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            paper.authors.join(', '),
                            style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // Status badge
                            Container(
                              padding: padSym(h: 8, v: 3),
                              decoration: BoxDecoration(
                                color: paper.status.color(context).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                paper.status.label,
                                style: TextStyle(
                                  fontSize: DesignTokens.fsXs,
                                  color: paper.status.color(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (paper.lastReadAt != null)
                              Text(
                                _timeAgo(paper.lastReadAt!),
                                style: TextStyle(
                                  fontSize: DesignTokens.fsXs,
                                  color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Menu
                  if (_selected.isEmpty)
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'delete') _confirmDelete(paper);
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'delete', child: Text('删除')),
                      ],
                      icon: Icon(Icons.more_vert, size: 18, color: colors.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSortBar(ThemeData theme, int count) {
    return Padding(
      padding: padSym(h: Spacing.lg, v: 4),
      child: Row(
        children: [
          Text('$count 篇', style: theme.textTheme.bodySmall),
          const Spacer(),
          DropdownButton<_SortMode>(
            value: _sortMode,
            underline: const SizedBox(),
            isDense: true,
            style: TextStyle(fontSize: DesignTokens.fsSm, color: theme.colorScheme.primary),
            items: const [
              DropdownMenuItem(value: _SortMode.lastRead, child: Text('最近阅读')),
              DropdownMenuItem(value: _SortMode.imported, child: Text('最新导入')),
              DropdownMenuItem(value: _SortMode.title, child: Text('标题 A-Z')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _sortMode = v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionBar(ThemeData theme) {
    if (_selected.length < 2) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.gap),
      color: theme.colorScheme.primaryContainer,
      child: Row(
        children: [
          Text('已选 ${_selected.length} 篇', style: theme.textTheme.bodySmall),
          const Spacer(),
          if (_selected.length >= 2)
            FilledButton.tonalIcon(
              onPressed: _compareSelected,
              icon: const Icon(Icons.compare_arrows, size: 16),
              label: const Text('对比'),
            ),
          const SizedBox(width: Spacing.gap),
          FilledButton.tonalIcon(
            onPressed: _deleteSelected,
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('删除'),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.errorContainer,
              foregroundColor: theme.colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(width: Spacing.gap),
          TextButton(onPressed: () => setState(() => _selected.clear()), child: const Text('取消')),
        ],
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme) {
    final filterLabels = [
      '全部', '⭐ 星标',
      '导入中', '解析中', '已解析', '翻译中', '已翻译', '错误',
    ];

    return Container(
      padding: padSym(h: Spacing.lg, v: Spacing.sm),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.dividerColor))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(filterLabels.length, (i) {
            final selected = _filterStatus == i;
            final status = i <= 1 ? null : PaperStatus.values[i - 2];
            return Padding(
              padding: padOnly(r: Spacing.sm),
              child: FilterChip(
                label: Text(filterLabels[i], style: const TextStyle(fontSize: DesignTokens.fsSm)),
                selected: selected,
                selectedColor: status?.color(context).withValues(alpha: 0.15),
                checkmarkColor: status?.color(context),
                onSelected: (_) => setState(() => _filterStatus = i),
              ),
            );
          }),
        ),
      ),
    );
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selected.contains(id)) _selected.remove(id);
      else _selected.add(id);
    });
  }

  void _compareSelected() {
    if (_selected.length < 2) return;
    final papers = context.paperService.papers.where((p) => _selected.contains(p.id)).toList();
    _selected.clear();
    Navigator.push(context, MaterialPageRoute(builder: (_) => ComparisonPage(papers: papers)));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已删除 $deleted 篇论文')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('删除失败，请重试')));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已删除: ${paper.title}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('删除失败')));
      }
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 30) return '${diff.inDays} 天前';
    return '${(diff.inDays / 30).floor()} 个月前';
  }
}

extension _StatusX on PaperStatus {
  Color color(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return switch (this) {
      PaperStatus.importing || PaperStatus.downloading => cs.tertiary,
      PaperStatus.parsing => cs.primary,
      PaperStatus.parsed => cs.secondary,
      PaperStatus.translating => cs.primary,
      PaperStatus.translated => Colors.green,
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
