import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../../core/models/paper.dart';
import '../../main.dart';
import 'read_page.dart';

final _log = Logger('LibraryPage');

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deps = Dependencies.of(context);
    final papers = deps.paperService.papers;

    if (papers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_books_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('还没有论文', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('去搜索页找一篇吧', style: theme.textTheme.bodySmall),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: papers.length,
      itemBuilder: (context, index) => _buildPaperCard(context, papers.elementAt(index), theme),
    );
  }

  Widget _buildPaperCard(BuildContext context, Paper paper, ThemeData theme) {
    final statusText = switch (paper.status) {
      PaperStatus.importing => '导入中...',
      PaperStatus.downloading => '下载中...',
      PaperStatus.parsing => '解析中...',
      PaperStatus.parsed => '已解析',
      PaperStatus.translating => '翻译中...',
      PaperStatus.translated => '已翻译',
      PaperStatus.error => '错误',
    };

    final isReadable = paper.status == PaperStatus.parsed || paper.status == PaperStatus.translated;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isReadable
            ? () {
                _log.info('open: ${paper.title}');
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ReadPage(paper: paper)),
                );
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(paper.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
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
              Chip(label: Text(statusText, style: const TextStyle(fontSize: 11))),
            ],
          ),
        ),
      ),
    );
  }
}
