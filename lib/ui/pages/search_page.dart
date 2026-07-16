import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:logging/logging.dart';
import '../../core/api/zotero_api.dart';
import '../../core/models/search_result.dart';
import '../../core/models/paper.dart';
import '../../core/di/dependencies.dart';
import '../../core/tokens/design_tokens.dart';
import '../widgets/card_spinner.dart';
import 'read_page.dart';

final _log = Logger('SearchPage');

enum SearchPageAction { search, importUrl }
final searchPageAction = ValueNotifier<SearchPageAction?>(null);
final paperToView = ValueNotifier<String?>(null);

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
  String _statusMessage = '';
  bool _showUrlInput = false;
  Paper? _lastImportedPaper;

  @override
  void initState() {
    super.initState();
    searchPageAction.addListener(_onTrayAction);
  }

  @override
  void dispose() {
    searchPageAction.removeListener(_onTrayAction);
    _queryController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  String _errorDetail(Object e) {
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('Connection refused') || s.contains('连接')) return '网络连接失败';
    if (s.contains('TimeoutException') || s.contains('timed out')) return '请求超时';
    if (s.contains('401') || s.contains('Unauthorized') || s.contains('401')) return 'API Key 无效或过期';
    if (s.contains('429') || s.contains('Rate limit')) return '请求过于频繁，请稍后重试';
    if (s.contains('500') || s.contains('Internal Server')) return '服务端错误，请稍后重试';
    if (s.contains('FileSystemException') || s.contains('No such file')) return '文件不存在或无法访问';
    final clean = s.replaceAll(RegExp(r'(Exception|Error|Instance of|DioException|\[\w+\])'), '').trim();
    if (clean.length > 80) return '${clean.substring(0, 80)}...';
    return clean.isNotEmpty ? clean : '未知错误';
  }

  void _onTrayAction() {
    final action = searchPageAction.value;
    if (action == null || !mounted) return;
    searchPageAction.value = null;
    setState(() {
      _showUrlInput = action == SearchPageAction.importUrl;
    });
  }

  bool _isImported(SearchResult r) {
    final papers = context.paperService.papers;
    return papers.any((p) => p.title == r.title);
  }

  Paper? _importedPaper(SearchResult r) {
    try {
      return context.paperService.papers.firstWhere((p) => p.title == r.title);
    } catch (_) {
      return null;
    }
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _loading = true;
      _statusMessage = '';
      _results = [];
    });

    try {
      if (!context.networkService.isOnline) {
        if (mounted) {
          setState(() {
            _loading = false;
            _statusMessage = '网络不可用，请检查网络连接后重试';
          });
        }
        return;
      }

      final (results, error) = await context.searchService.search(query);
      if (!mounted) return;

      if (error != null) {
        setState(() { _loading = false; _statusMessage = error; });
        return;
      }

      setState(() {
        _loading = false;
        _results = results;
        if (results.isEmpty) _statusMessage = '未找到相关论文，试试其他关键词';
      });
    } catch (e) {
      if (!mounted) return;
      _log.warning('search failed: $e');
      setState(() { _loading = false; _statusMessage = '搜索出错: ${_errorDetail(e)}'; });
    }
  }

  Future<void> _importUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() { _loading = true; _statusMessage = '正在导入...'; });

    String? pdfUrl = url;
    String? title;
    final arxivMatch = RegExp(r'arxiv\.org/abs/(\d+\.\d+)').firstMatch(url);
    if (arxivMatch != null) {
      pdfUrl = 'https://arxiv.org/pdf/${arxivMatch.group(1)}.pdf';
      title = 'arXiv ${arxivMatch.group(1)}';
    }

    try {
      final ss = context.searchService;
      final ps3 = context.paperService;
      final tempDir = await Directory.systemTemp.createTemp('paperwise_');
      final result = SearchResult(title: title ?? url, authors: [], pdfUrl: pdfUrl, source: 'url');
      final file = await ss.downloadPdf(result, tempDir.path,
        onProgress: (received, total) {
          if (total > 0) { final pct = (received / total * 100).toInt(); _statusMessage = '下载中... $pct%'; if (mounted) setState(() {}); }
        },
      );
      if (file == null) { setState(() { _statusMessage = '下载失败'; _loading = false; }); return; }

      final paper = await ps3.importPdf(file, title: title);
      if (paper == null || paper.status == PaperStatus.error) {
        setState(() { _statusMessage = '解析失败: ${paper?.errorMessage ?? "请检查 MinerU API Key"}'; _loading = false; });
      } else {
        setState(() { _statusMessage = '导入成功: ${paper.title}'; _loading = false; _urlController.clear(); _showUrlInput = false; _lastImportedPaper = paper; });
      }
    } catch (e) {
      _log.warning('importUrl failed: $e');
      setState(() { _statusMessage = '导入失败: ${_errorDetail(e)}'; _loading = false; });
    }
  }

  Future<void> _uploadPdf() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      if (!mounted || result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.path == null) return;
      setState(() => _statusMessage = '正在导入...');
      final paper = await context.paperService.importPdf(File(file.path!), title: file.name.replaceAll('.pdf', ''));
      if (!mounted) return;
      if (paper == null || paper.status == PaperStatus.error) {
        setState(() => _statusMessage = '解析失败: ${paper?.errorMessage ?? "请检查 MinerU API Key"}');
      } else {
        setState(() { _statusMessage = '导入成功: ${paper.title}'; _lastImportedPaper = paper; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusMessage = '导入失败: ${_errorDetail(e)}');
    }
  }

  /// Import any supported file format via MarkItDown bridge.
  Future<void> _importAnyFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf', 'docx', 'pptx', 'xlsx', 'xls',
          'epub', 'html', 'htm', 'md', 'txt',
          'csv', 'json', 'xml',
          'png', 'jpg', 'jpeg', 'gif', 'webp',
        ],
      );
      if (!mounted || result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.path == null) return;

      setState(() => _statusMessage = '正在转换 ${file.name}...');
      final converter = context.docConversion;
      final conversion = await converter.convertToMarkdown(File(file.path!));

      if (!conversion.success) {
        setState(() { _statusMessage = '转换失败: ${conversion.error ?? "未知错误"}'; _loading = false; });
        return;
      }

      final ps = context.paperService;
      final paper = await ps.importPdf(File(file.path!), title: conversion.title);
      if (!mounted) return;
      if (paper == null || paper.status == PaperStatus.error) {
        setState(() => _statusMessage = '导入失败: ${paper?.errorMessage ?? "请检查 API Key"}');
      } else {
        setState(() { _statusMessage = '导入成功: ${conversion.title}'; _lastImportedPaper = paper; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已导入: ${conversion.title}')));
      }
    } catch (e) {
      if (mounted) setState(() => _statusMessage = '导入失败: ${_errorDetail(e)}');
    }
  }

  String _fileLocalName(File f) => f.path.split(Platform.pathSeparator).last;

  Future<void> _importFolder() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], allowMultiple: true);
      if (!mounted || result == null || result.files.isEmpty) return;
      final pdfs = result.files.where((f) => f.path != null).map((f) => File(f.path!)).toList();
      if (pdfs.isEmpty) { setState(() => _statusMessage = '未选择 PDF 文件'); return; }
      setState(() => _statusMessage = '正在导入 ${pdfs.length} 篇论文...');
      var success = 0, failed = 0;
      for (var i = 0; i < pdfs.length; i++) {
        final file = pdfs[i];
        final fileName = _fileLocalName(file);
        setState(() => _statusMessage = '导入中 (${i + 1}/${pdfs.length}): $fileName');
        try {
          final paper = await context.paperService.importPdf(file, title: fileName.replaceAll('.pdf', ''));
          if (paper != null && paper.status != PaperStatus.error) { success++; }
          else { failed++; }
        } catch (e) { failed++; }
      }
      if (mounted) {
        setState(() => _statusMessage = '导入完成: $success 成功, $failed 失败');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('批量导入完成: $success 篇成功, $failed 篇失败')));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusMessage = '批量导入失败: ${_errorDetail(e)}');
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
          Container(
            padding: padSym(h: Spacing.lg, v: Spacing.sm),
            color: _lastImportedPaper != null ? theme.colorScheme.primaryContainer.withValues(alpha: 0.15) : null,
            child: Row(
              children: [
                Expanded(child: Text(_statusMessage, style: theme.textTheme.bodySmall)),
                if (_lastImportedPaper != null && _lastImportedPaper!.status != PaperStatus.error)
                  TextButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ReadPage(paper: _lastImportedPaper!)))
                        .then((_) { _lastImportedPaper = null; if (mounted) setState(() {}); });
                    },
                    child: const Text('查看'),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: padOnly(l: Spacing.lg, t: Spacing.lg, r: Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 520;
              final searchField = TextField(
                controller: _queryController,
                decoration: InputDecoration(
                  hintText: '搜索论文标题或关键词...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusLg)),
                  filled: true, fillColor: theme.colorScheme.surfaceContainerHighest,
                  contentPadding: padSym(h: DesignTokens.sp4, v: DesignTokens.sp3),
                ),
                onSubmitted: (_) => _search(),
              );
              if (isWide) {
                return Row(
                  children: [
                    Expanded(child: searchField),
                    const SizedBox(width: Spacing.gap),
                    _searchButton(),
                    const SizedBox(width: Spacing.gap),
                    _uploadButton(),
                    const SizedBox(width: Spacing.gap),
                    _importAnyButton(),
                    const SizedBox(width: Spacing.gap),
                    _folderButton(),
                    const SizedBox(width: Spacing.gap),
                    _linkButton(),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  searchField,
                  const SizedBox(height: Spacing.gap),
                  Wrap(
                    spacing: Spacing.gap,
                    runSpacing: Spacing.sm,
                    children: [
                      _searchButton(),
                      _uploadButton(),
                      _importAnyButton(),
                      _linkButton(),
                      _zoteroButton(),
                    ],
                  ),
                ],
              );
            },
          ),
          if (_showUrlInput) ...[
            const SizedBox(height: Spacing.gap),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      hintText: '粘贴 arXiv 链接或 PDF 直链...',
                      prefixIcon: const Icon(Icons.link),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusLg)),
                      filled: true, fillColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                    onSubmitted: (_) => _importUrl(),
                  ),
                ),
                const SizedBox(width: Spacing.gap),
                FilledButton.tonalIcon(
                  onPressed: _importUrl,
                  icon: const Icon(Icons.download, size: DesignTokens.iconMd),
                  label: const Text('导入'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static final _fadeTween = Tween<double>(begin: 0.0, end: 1.0);

  Widget _buildBody(ThemeData theme) {
    if (_loading) return const Center(child: CardSpinner());

    if (_results.isEmpty) {
      return Center(
        child: TweenAnimationBuilder<double>(
          tween: _fadeTween,
          duration: const Duration(milliseconds: 500),
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(offset: Offset(0, DesignTokens.sp10 * (1 - value)), child: child),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: DesignTokens.sp12, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: Spacing.lg),
              Text('输入关键词搜索论文', style: theme.textTheme.bodyLarge),
              const SizedBox(height: Spacing.sm),
              Text('或点击"导入文件"支持 PDF / DOCX / PPTX / EPUB / HTML / Markdown...', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: padSym(h: Spacing.lg),
      itemCount: _results.length,
      itemBuilder: (context, index) => TweenAnimationBuilder<double>(
        tween: _fadeTween,
        duration: const Duration(milliseconds: 500),
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, DesignTokens.sp10 * (1 - value)), child: child),
        ),
        child: _buildResultCard(_results[index], theme),
      ),
    );
  }

  Widget _buildResultCard(SearchResult result, ThemeData theme) {
    final imported = _isImported(result);
    final existing = _importedPaper(result);
    final colors = theme.colorScheme;

    return Card(
      margin: padOnly(b: DesignTokens.spGap),
      elevation: imported ? 0 : 1,
      color: imported ? colors.secondaryContainer.withValues(alpha: 0.2) : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: imported
            ? BorderSide(color: colors.secondary.withValues(alpha: 0.3))
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          if (imported && existing != null) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ReadPage(paper: existing)));
            return;
          }
          if (result.pdfUrl.isEmpty) { setState(() => _statusMessage = '该论文无开放获取 PDF 链接'); return; }
          setState(() => _statusMessage = '正在下载: ${result.title}');
          try {
            final paper = await context.paperService.importFromSearch(result,
              onProgress: (received, total) {
                if (total > 0 && mounted) setState(() => _statusMessage = '下载中... ${(received / total * 100).toInt()}%');
              },
            );
            if (paper == null) { setState(() => _statusMessage = '下载失败，请检查网络或重试'); }
            else if (paper.status == PaperStatus.error) { setState(() => _statusMessage = '解析失败: ${paper.errorMessage ?? "请检查 MinerU API Key"}'); }
            else { setState(() { _statusMessage = '导入成功: ${paper.title}'; _lastImportedPaper = paper; }); }
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败: ${_errorDetail(e)}')));
          }
        },
        child: Padding(
          padding: padAll(Spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      result.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (imported)
                    Padding(
                      padding: padOnly(l: Spacing.sm),
                      child: Container(
                        padding: padSym(h: 8, v: 2),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '已导入',
                          style: TextStyle(
                            fontSize: DesignTokens.fsXs,
                            color: colors.onPrimaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),

              // Authors
              if (result.authors.isNotEmpty)
                Padding(
                  padding: padOnly(b: 6),
                  child: Text(
                    result.authors.join(', '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              // Abstract preview (Kori-style content preview)
              if (result.abstract.isNotEmpty)
                Padding(
                  padding: padOnly(b: 8),
                  child: Text(
                    result.abstract,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.8),
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              // Bottom row: meta info
              Row(
                children: [
                  _metaChip(result.year.toString(), colors),
                  const SizedBox(width: 6),
                  _metaChip(result.source, colors),
                  if (result.citationCount > 0) ...[
                    const SizedBox(width: 6),
                    _metaChip('☆ ${result.citationCount}', colors),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaChip(String text, ColorScheme colors) {
    return Container(
      padding: padSym(h: 8, v: 3),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: DesignTokens.fsXs,
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _searchButton() {
    return FilledButton.icon(
      onPressed: _loading ? null : _search,
      icon: _loading
          ? const SizedBox(width: DesignTokens.iconMd, height: DesignTokens.iconMd, child: CircularProgressIndicator(strokeWidth: DesignTokens.borderXl))
          : const Icon(Icons.search),
      label: const Text('搜索'),
    );
  }

  Widget _uploadButton() {
    return OutlinedButton.icon(
      onPressed: _uploadPdf,
      icon: const Icon(Icons.upload_file),
      label: const Text('上传 PDF'),
    );
  }

  Widget _importAnyButton() {
    return FilledButton.tonalIcon(
      onPressed: _importAnyFile,
      icon: const Icon(Icons.insert_drive_file, size: DesignTokens.iconMd),
      label: const Text('导入文件'),
      style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
    );
  }

  Widget _folderButton() {
    return OutlinedButton.icon(
      onPressed: _importFolder,
      icon: const Icon(Icons.folder_open),
      label: const Text('批量 PDF'),
    );
  }

  Widget _zoteroButton() {
    return OutlinedButton.icon(
      onPressed: _importFromZotero,
      icon: const Icon(Icons.bookmark, size: DesignTokens.iconMd),
      label: const Text('Zotero'),
    );
  }

  Widget _linkButton() {
    return OutlinedButton.icon(
      onPressed: () => setState(() => _showUrlInput = !_showUrlInput),
      icon: Icon(_showUrlInput ? Icons.expand_less : Icons.link),
      label: const Text('贴链接'),
    );
  }

  Future<void> _importFromZotero() async {
    try {
      final zotero = context.zoteroService;
      if (!zotero.isConfigured) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请设置环境变量 ZOTERO_API_KEY 和 ZOTERO_USER_ID')),
          );
        }
        return;
      }
      final items = await zotero.importFromZotero();
      if (!mounted) return;
      if (items.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zotero 文库为空'))); return; }

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('从 Zotero 导入'),
          content: SizedBox(width: 400, child: ListView.builder(
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i];
              return ListTile(
                dense: true,
                title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(item.authors.join(', '), maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: FilledButton.tonal(
                  onPressed: () async {
                    final ps = context.paperService;
                    final result = SearchResult(title: item.title, authors: item.authors, year: item.year, abstract: item.abstract, pdfUrl: item.pdfUrl, doi: item.doi, source: 'zotero');
                    await ps.importFromSearch(result);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('导入'),
                ),
              );
            },
          )),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭'))],
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Zotero 导入失败: ${_errorDetail(e)}')));
    }
  }
}
