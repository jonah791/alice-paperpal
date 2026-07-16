/// PaperPal 搜索页 — Kori 风格
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:logging/logging.dart';
import '../../core/models/search_result.dart';
import '../../core/models/paper.dart';
import '../../core/di/dependencies.dart';
import '../widgets/paper_card.dart';
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
  final _queryCtrl = TextEditingController();
  List<SearchResult> _results = [];
  bool _loading = false;
  String _msg = '';

  @override
  void initState() {
    super.initState();
    searchPageAction.addListener(_onAction);
  }
  @override
  void dispose() {
    searchPageAction.removeListener(_onAction);
    _queryCtrl.dispose();
    super.dispose();
  }
  void _onAction() { searchPageAction.value = null; }

  String _errMsg(Object e) {
    final s = e.toString();
    if (s.contains('401')) return 'API Key 无效';
    if (s.contains('timeout')) return '请求超时';
    return '搜索失败，请重试';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      children: [
        // 搜索栏 — Kori TopSearchBar 风格
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: colors.surfaceBright,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 56,
              child: TextField(
                controller: _queryCtrl,
                decoration: InputDecoration(
                  hintText: '搜索 arXiv + Semantic Scholar',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.search, size: 20),
                  ),
                  suffixIcon: _loading
                      ? const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                      : null,
                  filled: true,
                  fillColor: theme.inputDecorationTheme.fillColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onSubmitted: (v) => _search(v.trim()),
              ),
            ),
          ),
        ),
        // 操作行
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            _btn('搜索', Icons.search, () => _search(_queryCtrl.text.trim())),
            const SizedBox(width: 8),
            _btn('上传 PDF', Icons.upload_file, _uploadPdf),
            const SizedBox(width: 8),
            _btn('导入', Icons.insert_drive_file, _importAny),
            const Spacer(),
            TextButton.icon(
              onPressed: _importZotero,
              icon: const Icon(Icons.bookmark, size: 16),
              label: const Text('Zotero', style: TextStyle(fontSize: 13)),
            ),
          ]),
        ),
        if (_msg.isNotEmpty && _results.isEmpty)
          Expanded(child: Center(child: Text(_msg, style: theme.textTheme.bodyMedium))),
        if (_results.isNotEmpty)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _results.length,
              itemBuilder: (ctx, i) => _buildResult(_results[i]),
            ),
          ),
      ],
    );
  }

  Widget _btn(String label, IconData icon, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: _loading ? null : onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildResult(SearchResult r) {
    final existing = context.paperService.papers.where((p) =>
      p.title == r.title || (p.doi.isNotEmpty && p.doi == r.doi)).isNotEmpty;

    // 构建一个临时 Paper 对象来复用 PaperCard
    final fakePaper = Paper(
      id: '',
      title: r.title,
      authors: r.authors,
      year: r.year,
      source: r.source,
      status: PaperStatus.parsed,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PaperCard(
        paper: fakePaper,
        onTap: () {
          if (existing) {
            final p = context.paperService.papers.where((pp) =>
              pp.title == r.title || (pp.doi.isNotEmpty && pp.doi == r.doi)).firstOrNull;
            if (p != null) Navigator.push(context, MaterialPageRoute(builder: (_) => ReadPage(paper: p)));
          } else {
            _importResult(r);
          }
        },
      ),
    );
  }

  // ── Actions ──
  Future<void> _search(String q) async {
    if (q.isEmpty) return;
    setState(() { _loading = true; _msg = ''; _results = []; });
    try {
      final (r, e) = await context.paperService.search(q);
      if (mounted) setState(() { _loading = false; _results = r; _msg = e ?? (r.isEmpty ? '无结果' : ''); });
    } catch (e) { if (mounted) setState(() { _loading = false; _msg = _errMsg(e); }); }
  }

  Future<void> _uploadPdf() async {
    final f = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (f == null || f.files.isEmpty) return;
    await _importFile(File(f.files.first.path!));
  }

  Future<void> _importAny() async {
    final svc = context.docConversion;
    final f = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: svc.supportedExtensions);
    if (f == null || f.files.isEmpty) return;
    final file = File(f.files.first.path!);
    if (file.path.endsWith('.pdf')) { await _importFile(file); return; }
    setState(() => _loading = true);
    try {
      final conv = await svc.convertToMarkdown(file);
      if (mounted) {
        if (!conv.success) { _snack('转换失败'); return; }
        final paper = await context.paperService.importPdf(file, title: conv.title);
        _onImported(paper);
      }
    } catch (e) { if (mounted) _snack('导入失败'); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _importResult(SearchResult r) async {
    setState(() => _loading = true);
    try {
      final p = await context.paperService.importFromSearch(r);
      if (mounted) _onImported(p);
    } catch (e) { if (mounted) _snack('导入失败'); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _importFile(File f) async {
    setState(() => _loading = true);
    try { final p = await context.paperService.importPdf(f); if (mounted) _onImported(p); }
    catch (e) { if (mounted) _snack('导入失败'); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _importZotero() async {
    final z = context.zoteroService;
    if (!z.isConfigured) { _snack('请设置 ZOTERO_API_KEY'); return; }
    setState(() => _loading = true);
    try {
      final items = await z.importFromZotero();
      if (mounted) { _results = items; _msg = ''; _loading = false; }
    } catch (e) { if (mounted) _snack('Zotero 失败'); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  void _onImported(Paper? p) {
    if (p == null || p.status == PaperStatus.error) { _snack('导入失败'); return; }
    _snack('导入成功');
    paperToView.value = p.id;
  }

  void _snack(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s), behavior: SnackBarBehavior.floating));
  }
}
