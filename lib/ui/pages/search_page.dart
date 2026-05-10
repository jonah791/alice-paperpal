import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:logging/logging.dart';
import '../../core/models/search_result.dart';
import '../../main.dart';

final _log = Logger('SearchPage');

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _queryController = TextEditingController();
  final _urlController = TextEditingController();
  List<SearchResult> _results = [];
  bool _loading = false;
  bool _showUrlInput = false;
  String _statusMessage = '';

  @override
  void dispose() {
    _queryController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _loading = true;
      _statusMessage = '';
      _results = [];
    });

    final deps = Dependencies.of(context);
    final results = await deps.searchService.search(query);

    setState(() {
      _loading = false;
      _results = results;
      if (results.isEmpty) {
        _statusMessage = '未找到相关论文，试试其他关键词';
      }
    });
  }

  Future<void> _importUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _loading = true;
      _statusMessage = '正在导入...';
    });

    String? pdfUrl = url;
    String? title;

    // Handle arXiv abs page
    final arxivMatch = RegExp(r'arxiv\.org/abs/(\d+\.\d+)').firstMatch(url);
    if (arxivMatch != null) {
      pdfUrl = 'https://arxiv.org/pdf/${arxivMatch.group(1)}.pdf';
      title = 'arXiv ${arxivMatch.group(1)}';
      _log.info('importUrl: arXiv $pdfUrl');
    }

    try {
      final deps = Dependencies.of(context);
      final tempDir = await Directory.systemTemp.createTemp('paperwise_');
      final savePath = '${tempDir.path}/paper.pdf';
      final dio = Dio();
      await dio.download(pdfUrl!, savePath);
      final file = File(savePath);

      final paper = await deps.paperService.importPdf(file, title: title);
      if (paper != null) {
        setState(() {
          _statusMessage = '导入成功: ${paper.title}';
          _loading = false;
          _urlController.clear();
          _showUrlInput = false;
        });
      } else {
        setState(() {
          _statusMessage = '导入失败';
          _loading = false;
        });
      }
    } catch (e) {
      _log.warning('importUrl failed: $e');
      setState(() {
        _statusMessage = '导入失败: 无法下载或解析';
        _loading = false;
      });
    }
  }

  Future<void> _uploadPdf() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) return;

    setState(() => _statusMessage = '正在导入...');
    _log.info('uploadPdf: ${file.name}');

    final deps = Dependencies.of(context);
    final paper = await deps.paperService.importPdf(
      File(file.path!),
      title: file.name.replaceAll('.pdf', ''),
    );

    if (paper != null) {
      _log.info('uploadPdf: imported ${paper.id}');
      setState(() => _statusMessage = '导入成功: ${paper.title}');
    } else {
      setState(() => _statusMessage = '导入失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        _buildSearchBar(theme),
        Expanded(child: _buildBody(theme)),
        if (_statusMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(_statusMessage, style: theme.textTheme.bodySmall),
          ),
      ],
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _queryController,
                  decoration: InputDecoration(
                    hintText: '搜索论文标题或关键词...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _loading ? null : _search,
                icon: _loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search),
                label: const Text('搜索'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _uploadPdf,
                icon: const Icon(Icons.upload_file),
                label: const Text('上传 PDF'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => setState(() => _showUrlInput = !_showUrlInput),
                icon: Icon(_showUrlInput ? Icons.expand_less : Icons.link),
                label: const Text('贴链接'),
              ),
            ],
          ),
        ),
        if (_showUrlInput)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      hintText: '粘贴 arXiv 链接或 PDF 直链...',
                      prefixIcon: const Icon(Icons.link),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                    onSubmitted: (_) => _importUrl(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: _importUrl,
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('导入'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('输入关键词开始搜索论文', style: theme.textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text('或点击"上传 PDF"导入本地论文', style: theme.textTheme.bodySmall),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _results.length,
      itemBuilder: (context, index) => _buildResultCard(_results[index], theme),
    );
  }

  Widget _buildResultCard(SearchResult result, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          setState(() => _statusMessage = '正在下载: ${result.title}');
          final deps = Dependencies.of(context);
          final paper = await deps.paperService.importFromSearch(result);
          if (paper != null) {
            _log.info('importFromSearch: ${paper.id}');
            setState(() => _statusMessage = '导入成功: ${paper.title}');
          } else {
            setState(() => _statusMessage = '下载或解析失败');
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.title,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                result.authors.join(', '),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Chip(label: Text(result.year.toString(), style: const TextStyle(fontSize: 11))),
                  const SizedBox(width: 8),
                  Chip(label: Text(result.source, style: const TextStyle(fontSize: 11))),
                  if (result.citationCount > 0) ...[
                    const SizedBox(width: 8),
                    Text('☆ ${result.citationCount}', style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
              if (result.abstract.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(result.abstract,
                    style: theme.textTheme.bodySmall,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
