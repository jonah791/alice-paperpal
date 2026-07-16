/// PaperPal 阅读页 — Kori 风格 Markdown 阅读器
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import '../../core/models/paper.dart';
import '../../core/di/dependencies.dart';
import '../../core/interfaces/services.dart';
import '../../core/tokens/design_tokens.dart';
import '../widgets/progress_bar.dart';

final _log = Logger('ReadPage');

class ReadPage extends StatefulWidget {
  final Paper paper;
  const ReadPage({super.key, required this.paper});
  @override
  State<ReadPage> createState() => _ReadPageState();
}

class _ReadPageState extends State<ReadPage> {
  String? _md, _trans;
  bool _loading = true;
  bool _showTrans = true;
  final _scrollCtrl = ScrollController();

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => _load()); }

  Future<void> _load() async {
    final ps = context.paperService;
    _md = await ps.getMarkdown(widget.paper.id);
    _trans = await ps.getTranslation(widget.paper.id);
    if (_md != null) ps.touchPaper(widget.paper.id);
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    if (_scrollCtrl.hasClients) {
      context.paperService.updatePaper(widget.paper.copyWith(scrollPosition: _scrollCtrl.position.pixels));
    }
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = _showTrans ? (_trans ?? _md ?? '') : (_md ?? '');

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.paper.title, style: const TextStyle(fontSize: 14)),
        actions: [
          if (_trans != null)
            IconButton(
              icon: Icon(_showTrans ? Icons.translate : Icons.text_fields, size: 20),
              tooltip: _showTrans ? '原文' : '译文',
              onPressed: () => setState(() => _showTrans = !_showTrans),
            ),
          IconButton(
            icon: Icon(widget.paper.starred ? Icons.star : Icons.star_border, color: widget.paper.starred ? Colors.amber : null, size: 20),
            onPressed: () async {
              final p = widget.paper.copyWith(starred: !widget.paper.starred);
              await context.paperService.updatePaper(p);
              setState(() {});
            },
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'summary') _summarize();
              if (v == 'pdf') _openPdf();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'summary', child: Text('摘要')),
              const PopupMenuItem(value: 'pdf', child: Text('打开 PDF')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                ScrollProgressBar(controller: _scrollCtrl),
                SingleChildScrollView(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: SelectableText(
                      text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.8,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _summarize() async {
    try {
      final s = await context.paperService.summarize(widget.paper.id);
      if (mounted) {
        showDialog(context: context, builder: (ctx) => AlertDialog(
          title: const Text('摘要'),
          content: SingleChildScrollView(child: SelectableText(s, style: const TextStyle(height: 1.6))),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭'))],
        ));
      }
    } catch (e) { _log.warning('summarize failed: $e'); }
  }

  Future<void> _openPdf() async {
    final pdf = await context.paperService.getPdfFile(widget.paper.id);
    if (pdf != null) {
      try { await context.configService.platform.openFile(pdf.path); }
      catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('无法打开 PDF'), behavior: SnackBarBehavior.floating)); }
    }
  }
}
