/// PaperPal Search — Kori 风格搜索页
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:logging/logging.dart';
import '../../core/models/search_result.dart';
import '../../core/models/paper.dart';
import '../../core/di/dependencies.dart';
import '../widgets/card_spinner.dart';
import '../widgets/skeleton_loader.dart';
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

  void _onTrayAction() {
    final action = searchPageAction.value;
    if (action == null) return;
    searchPageAction.value = null;
    if (action == SearchPageAction.search) {
      setState(() => _showUrlInput = false);
    } else if (action == SearchPageAction.importUrl) {
      setState(() => _showUrlInput = true);
    }
  }

  String _errorDetail(Object e) {
    final s = e.toString();
    if (s.contains('401')) return 'API Key 无效或已过期';
    if (s.contains('429')) return '请求太频繁，请稍后重试';
    if (s.contains('Connection refused') || s.contains('SocketException')) return '网络连接失败';
    if (s.contains('timeout') || s.contains('Timed out')) return '请求超时';
    return '搜索失败，请重试';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kori 风格搜索标题栏
        Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Text('搜索论文', style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          )),
        ),
        // Kori 风格搜索栏
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextField(
            controller: _queryController,
            decoration: InputDecoration(
              hintText: '搜索 arXiv + Semantic Scholar...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : _queryController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _queryController.clear();
                            setState(() => _results = []);
                          },
                        )
                      : null,
              filled: true,
              fillColor: colors.surfaceContainerHighest,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
            onSubmitted: (v) => _search(v.trim()),
          ),
        ),
        // 操作按钮行
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _loading ? null : () => _search(_queryController.text.trim()),
                icon: const Icon(Icons.search, size: 16),
                label: const Text('搜索'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _loading ? null : _uploadPdf,
                icon: const Icon(Icons.upload_file, size: 16),
                label: const Text('上传 PDF'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: _loading ? null : _importAnyFile,
                icon: const Icon(Icons.insert_drive_file, size: 16),
                label: const Text('导入文件'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _loading ? null : _importFromZotero,
                icon: const Icon(Icons.bookmark, size: 16),
                label: const Text('Zotero'),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _showUrlInput = !_showUrlInput),
                icon: Icon(_showUrlInput ? Icons.close : Icons.link, size: 16),
                label: Text(_showUrlInput ? '关闭' : 'URL'),
              ),
            ],
          ),
        ),
        // URL 输入行
        if (_showUrlInput)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      hintText: 'arXiv 链接或 PDF 直链...',
                      prefixIcon: const Icon(Icons.link, size: 18),
                      filled: true,
                      fillColor: colors.surfaceContainerHighest,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _importUrl, child: const Text('导入')),
              ],
            ),
          ),
        // 导入进度
        if (_loading && _results.isEmpty)
          const Expanded(
            child: Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CardSpinner(),
                SizedBox(height: 12),
                Text('搜索中...', style: TextStyle(fontSize: 13)),
              ],
            )),
          ),
        // 状态消息
        if (_statusMessage.isNotEmpty && _results.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, size: 40, color: colors.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text(_statusMessage, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ),
        // 结果列表 — Kori 风格卡片
        if (_results.isNotEmpty)
          Expanded(
            child: Column(
              children: [
                // 结果计数
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  child: Row(
                    children: [
                      Text('${_results.length} 篇', style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      )),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _results.length,
                    itemBuilder: (ctx, i) => _buildResultCard(_results[i], theme, colors),
                  ),
                ),
              ],
            ),
          ),
        if (_lastImportedPaper != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
            child: Card(
              elevation: 0,
              color: colors.primaryContainer,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('已导入: ${_lastImportedPaper!.title}', style: const TextStyle(fontSize: 13)),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ReadPage(paper: _lastImportedPaper!),
                      )),
                      child: const Text('查看'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildResultCard(SearchResult result, ThemeData theme, ColorScheme colors) {
    final existingPaper = context.paperService.papers.where((p) =>
      p.doi.isNotEmpty && p.doi == result.doi ||
      p.title == result.title
    ).isNotEmpty;

    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => existingPaper ? _openPaper(result) : _showImportDialog(result),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题 + 状态
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(result.title, style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    )),
                  ),
                  if (existingPaper)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('已导入', style: TextStyle(
                        fontSize: 11, color: colors.secondary, fontWeight: FontWeight.w500,
                      )),
                    ),
                ],
              ),
              // 作者
              if (result.authors.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(result.authors.join(', '), style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
              // 年份 + 来源 + 引用数
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    if (result.year > 0) ...[
                      Text('${result.year}', style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
                      Text('  ·  ', style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant.withValues(alpha: 0.3))),
                    ],
                    Chip(
                      label: Text(result.source, style: const TextStyle(fontSize: 10)),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                      backgroundColor: colors.tertiary.withValues(alpha: 0.1),
                    ),
                    if (result.citationCount > 0) ...[
                      const SizedBox(width: 8),
                      Text('${result.citationCount} 引用', style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              // 摘要预览
              if (result.abstract.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(result.abstract, style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.5,
                  color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                ), maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── 搜索 ──────────────────────────────────────────────────────

  Future<void> _search(String query) async {
    if (query.isEmpty) return;
    setState(() { _loading = true; _statusMessage = ''; _results = []; });
    try {
      final (results, error) = await context.paperService.search(query);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _results = results;
        _statusMessage = error ?? (results.isEmpty ? '没有找到匹配的论文' : '');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _statusMessage = _errorDetail(e); });
    }
  }

  // ── 导入 ──────────────────────────────────────────────────────

  Future<void> _uploadPdf() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.isEmpty) return;
    await _importFile(File(result.files.first.path!));
  }

  Future<void> _importAnyFile() async {
    final svc = context.docConversion;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: svc.supportedExtensions,
    );
    if (result == null || result.files.isEmpty) return;
    final file = File(result.files.first.path!);
    final ext = file.path.split('.').last.toLowerCase();
    if (ext == 'pdf') {
      await _importFile(file);
      return;
    }
    // 非 PDF → 走 MarkItDown 转换
    setState(() => _loading = true);
    try {
      final conv = await svc.convertToMarkdown(file);
      if (!mounted) return;
      if (!conv.success) {
        _showSnackBar('转换失败: ${conv.error ?? "未知错误"}');
        return;
      }
      final paper = await context.paperService.importPdf(file, title: conv.title);
      if (mounted) _onImported(paper);
    } catch (e) {
      if (mounted) _showSnackBar('导入失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _importFile(File file) async {
    setState(() => _loading = true);
    try {
      final paper = await context.paperService.importPdf(file);
      if (mounted) _onImported(paper);
    } catch (e) {
      if (mounted) _showSnackBar('导入失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _importFromZotero() async {
    try {
      final zotero = context.zoteroService;
      if (!zotero.isConfigured) {
        _showSnackBar('请设置环境变量 ZOTERO_API_KEY 和 ZOTERO_USER_ID');
        return;
      }
      setState(() => _loading = true);
      final items = await zotero.importFromZotero();
      if (!mounted) return;
      if (items.isEmpty) { _showSnackBar('Zotero 文库为空'); return; }
      setState(() {
        _loading = false;
        _results = items;
        _statusMessage = '';
      });
    } catch (e) {
      if (mounted) _showSnackBar('Zotero 导入失败: $e');
    }
  }

  Future<void> _importUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    setState(() => _loading = true);
    try {
      final result = await context.paperService.importFromSearch(SearchResult(
        title: url.split('/').last.replaceAll('.pdf', ''),
        pdfUrl: url,
      ));
      if (mounted) _onImported(result);
    } catch (e) {
      if (mounted) _showSnackBar('导入失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onImported(Paper? paper) {
    if (paper == null || paper.status == PaperStatus.error) {
      _showSnackBar('导入失败: ${paper?.errorMessage ?? "未知错误"}');
      return;
    }
    setState(() => _lastImportedPaper = paper);
    _showSnackBar('导入成功: ${paper.title}');
  }

  void _openPaper(SearchResult result) {
    final paper = context.paperService.papers.where((p) =>
      p.doi.isNotEmpty && p.doi == result.doi ||
      p.title == result.title
    ).firstOrNull;
    if (paper != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ReadPage(paper: paper)));
    }
  }

  void _showImportDialog(SearchResult result) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('确认导入'),
      content: SingleChildScrollView(child: Text(result.title, maxLines: 3, overflow: TextOverflow.ellipsis)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(onPressed: () {
          Navigator.pop(ctx);
          _importFromSearch(result);
        }, child: const Text('导入')),
      ],
    ));
  }

  Future<void> _importFromSearch(SearchResult result) async {
    setState(() => _loading = true);
    try {
      final paper = await context.paperService.importFromSearch(result);
      if (mounted) _onImported(paper);
    } catch (e) {
      if (mounted) _showSnackBar('导入失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 13)),
      behavior: SnackBarBehavior.floating,
    ));
  }
}
