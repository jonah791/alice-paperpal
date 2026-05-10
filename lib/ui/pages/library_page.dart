import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../../core/models/paper.dart';
import '../../main.dart';
import 'read_page.dart';
import 'comparison_page.dart';

final _log = Logger('LibraryPage');

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deps = Dependencies.of(context);
    final papers = deps.paperService.papers;

    return Column(
      children: [
        if (_selected.length >= 2)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Text('已选 ${_selected.length} 篇', style: theme.textTheme.bodySmall),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: _compareSelected,
                  icon: const Icon(Icons.compare_arrows, size: 16),
                  label: const Text('对比'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() => _selected.clear()),
                  child: const Text('取消'),
                ),
              ],
            ),
          ),
        Expanded(
          child: papers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.library_books_outlined, size: 64,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(height: 16),
                      Text('还没有论文', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('去搜索页找一篇吧', style: theme.textTheme.bodySmall),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: papers.length,
                  itemBuilder: (context, index) =>
                      _buildPaperCard(context, papers.elementAt(index), theme),
                ),
        ),
      ],
    );
  }

  Widget _buildPaperCard(BuildContext context, Paper paper, ThemeData theme) {
    final isSelected = _selected.contains(paper.id);
    final isReadable = paper.status == PaperStatus.parsed || paper.status == PaperStatus.translated;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? theme.colorScheme.primaryContainer : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
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
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (_selected.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
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
                    Text(paper.title,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    if (paper.authors.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(paper.authors.join(', '),
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Chip(label: Text(_statusText(paper.status), style: const TextStyle(fontSize: 11))),
            ],
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
    final deps = Dependencies.of(context);
    final papers = deps.paperService.papers.where((p) => _selected.contains(p.id)).toList();
    _selected.clear();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ComparisonPage(papers: papers)),
    );
  }

  String _statusText(PaperStatus s) => switch (s) {
    PaperStatus.importing => '导入中...',
    PaperStatus.downloading => '下载中...',
    PaperStatus.parsing => '解析中...',
    PaperStatus.parsed => '已解析',
    PaperStatus.translating => '翻译中...',
    PaperStatus.translated => '已翻译',
    PaperStatus.error => '错误',
  };
}
