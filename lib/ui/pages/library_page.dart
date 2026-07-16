/// PaperPal 文库页 — Kori 风格卡片列表
import 'package:flutter/material.dart';
import '../../core/models/paper.dart';
import '../../core/di/dependencies.dart';
import '../../core/tokens/design_tokens.dart';
import '../widgets/paper_card.dart';
import 'read_page.dart';
import 'comparison_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final _selected = <String>{};
  var _filterIdx = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      children: [
        // 标题栏
        Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Row(
            children: [
              Text('论文库', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              if (_selected.length >= 2) ...[
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: _compare,
                  icon: const Icon(Icons.compare_arrows, size: 16),
                  label: const Text('对比'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: _deleteSelected,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('删除'),
                ),
                const SizedBox(width: 8),
                TextButton(onPressed: () => setState(() => _selected.clear()), child: const Text('取消')),
              ],
            ],
          ),
        ),
        // 筛选栏 — Kori FilterChip 风格
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['全部', '⭐ 星标', '已解析', '已翻译', '错误'].asMap().entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(e.value, style: const TextStyle(fontSize: 12)),
                    selected: _filterIdx == e.key,
                    onSelected: (_) => setState(() => _filterIdx = e.key),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        // 列表
        Expanded(
          child: StreamBuilder<List<Paper>>(
            stream: context.paperService.paperStream,
            initialData: context.paperService.papers,
            builder: (ctx, snap) {
              var papers = snap.data ?? [];
              papers = switch (_filterIdx) {
                1 => papers.where((p) => p.starred).toList(),
                2 => papers.where((p) => p.status == PaperStatus.parsed).toList(),
                3 => papers.where((p) => p.status == PaperStatus.translated).toList(),
                4 => papers.where((p) => p.status == PaperStatus.error).toList(),
                _ => papers,
              };
              papers = papers.toList()..sort((a, b) =>
                (b.lastReadAt ?? b.importedAt ?? DateTime(0))
                    .compareTo(a.lastReadAt ?? a.importedAt ?? DateTime(0)));

              if (papers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.library_books_outlined, size: 64, color: colors.onSurfaceVariant),
                      const SizedBox(height: 16),
                      Text('没有论文', style: theme.textTheme.titleMedium),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: papers.length,
                itemBuilder: (ctx, i) {
                  final p = papers[i];
                  final sel = _selected.contains(p.id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PaperCard(
                      paper: p,
                      isSelected: sel,
                      isSelectionMode: _selected.isNotEmpty,
                      onTap: () {
                        if (_selected.isNotEmpty) {
                          _toggle(p.id);
                        } else if (p.status == PaperStatus.parsed || p.status == PaperStatus.translated) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ReadPage(paper: p)));
                        }
                      },
                      onLongPress: () => _toggle(p.id),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _toggle(String id) {
    setState(() { if (_selected.contains(id)) _selected.remove(id); else _selected.add(id); });
  }

  void _compare() {
    if (_selected.length < 2) return;
    final papers = context.paperService.papers.where((p) => _selected.contains(p.id)).toList();
    _selected.clear();
    Navigator.push(context, MaterialPageRoute(builder: (_) => ComparisonPage(papers: papers)));
  }

  Future<void> _deleteSelected() async {
    final ids = _selected.toList();
    _selected.clear();
    for (final id in ids) await context.paperService.deletePaper(id);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已删除 ${ids.length} 篇'), behavior: SnackBarBehavior.floating));
  }
}
