import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:logging/logging.dart';
import '../../core/models/paper.dart';
import '../../core/models/note.dart';
import '../../core/services/export_service.dart';
import '../../core/interfaces/services.dart';
import '../../core/di/dependencies.dart';
import '../../core/tokens/design_tokens.dart';
import '../widgets/explain_dialog.dart';
import '../widgets/progress_bar.dart';
import '../widgets/qa_panel.dart';
import '../widgets/notes_panel.dart';
import '../widgets/mermaid_widget.dart';
import '../widgets/find_bar.dart';

final _log = Logger('ReadPage');

class ReadPage extends StatefulWidget {
  final Paper paper;
  const ReadPage({super.key, required this.paper});

  @override
  State<ReadPage> createState() => _ReadPageState();
}

class _ReadPageState extends State<ReadPage> {
  String? _markdown;
  String? _translation;
  bool _loading = true;
  _ViewMode _viewMode = _ViewMode.translated;
  double _fontSize = DesignTokens.fsLg;
  bool _showNotes = false;
  bool _showFind = false;
  bool _hasMermaidBlocks = false;
  final _scrollController = ScrollController();
  final _qaKey = GlobalKey<QAPanelState>();
  final _notesKey = GlobalKey<NotesPanelState>();
  final _findBarKey = GlobalKey<FindBarState>();

  late IPaperService _paperSvc;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadContent());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fontSize = context.configService.config.fontSize;
    _paperSvc = context.paperService;
  }

  Future<void> _loadContent() async {
    final ps = context.paperService;
    final md = await ps.getMarkdown(widget.paper.id);
    final translation = await ps.getTranslation(widget.paper.id);
    if (md != null) ps.touchPaper(widget.paper.id);

    setState(() {
      _markdown = md;
      _translation = translation;
      _loading = false;
      if (translation == null) _viewMode = _ViewMode.original;
      if (md != null) {
        _hasMermaidBlocks = md.contains('```mermaid');
      }
    });
    if (widget.paper.scrollPosition > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(widget.paper.scrollPosition);
        }
      });
    }
  }

  // ── Find-in-Page (MD Preview inspired) ────────────────────────

  void _toggleFind() {
    setState(() => _showFind = !_showFind);
    if (_showFind) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _findBarKey.currentState?.show();
      });
    }
  }

  FindResult _onFind(String query, {bool caseSensitive = false}) {
    final text = _getDisplayText();
    if (query.isEmpty) return const FindResult(matchPositions: []);
    final positions = <int>[];
    final source = caseSensitive ? text : text.toLowerCase();
    final q = caseSensitive ? query : query.toLowerCase();
    int start = 0;
    while (true) {
      final idx = source.indexOf(q, start);
      if (idx == -1) break;
      positions.add(idx);
      start = idx + 1;
    }
    return FindResult(matchPositions: positions);
  }

  void _onFindNavigate(int position) {
    final text = _getDisplayText();
    if (text.isEmpty || _scrollController.position.maxScrollExtent <= 0) return;
    final ratio = position / text.length;
    _scrollController.animateTo(
      ratio * _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    if (_scrollController.hasClients) {
      _paperSvc.updatePaper(widget.paper.copyWith(
        scrollPosition: _scrollController.position.pixels,
      ));
    }
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final platform = context.configService.platform;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final displayText = _getDisplayText();

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): _toggleFind,
        if (!platform.isAndroid)
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (_showFind) _toggleFind();
          },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          floatingActionButton: FloatingActionButton.small(
            heroTag: 'ask_selection',
            onPressed: _askAboutSelection,
            tooltip: '选中文本提问',
            child: const Icon(Icons.smart_toy_outlined, size: DesignTokens.iconMd),
          ),
          appBar: AppBar(
            title: Text(widget.paper.title, style: const TextStyle(fontSize: DesignTokens.fsLg)),
            actions: [
              // Search in page
              IconButton(
                icon: const Icon(Icons.search, size: DesignTokens.iconMd),
                tooltip: '在页面中搜索 (Ctrl+F)',
                onPressed: _toggleFind,
              ),
              IconButton(
                icon: Icon(
                  widget.paper.starred ? Icons.star : Icons.star_border,
                  color: widget.paper.starred ? Colors.amber : null,
                ),
                tooltip: widget.paper.starred ? '取消收藏' : '收藏',
                onPressed: _toggleStar,
              ),
              if (_translation != null)
                SegmentedButton<_ViewMode>(
                  segments: [
                    const ButtonSegment(value: _ViewMode.original, label: Text('原文')),
                    const ButtonSegment(value: _ViewMode.translated, label: Text('译文')),
                    if (!platform.isAndroid)
                      const ButtonSegment(value: _ViewMode.sideBySide, label: Text('对照')),
                  ],
                  selected: {_viewMode},
                  onSelectionChanged: (v) => setState(() => _viewMode = v.first),
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStateProperty.all(const TextStyle(fontSize: DesignTokens.fsSm)),
                  ),
                ),
              const SizedBox(width: Spacing.lg),
              if (platform.isAndroid) ...[
                IconButton(
                  icon: const Icon(Icons.font_download),
                  tooltip: '字体大小',
                  onPressed: _showFontSizePicker,
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'summary': _summarize();
                      case 'export': _showExportMenu();
                      case 'pdf': _openOriginalPdf();
                      case 'notes': _toggleNotesPanel();
                      case 'reparse': _reparseWithMineru();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'summary', child: Text('摘要')),
                    const PopupMenuItem(value: 'export', child: Text('导出')),
                    const PopupMenuItem(value: 'pdf', child: Text('打开 PDF')),
                    const PopupMenuItem(value: 'notes', child: Text('笔记')),
                    if (widget.paper.sourceType != 'mineru')
                      const PopupMenuItem(value: 'reparse', child: Text('重新解析')),
                  ],
                ),
              ] else ...[
                IconButton(
                  icon: const Icon(Icons.summarize),
                  tooltip: '生成摘要',
                  onPressed: _summarize,
                ),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  tooltip: '打开原始 PDF',
                  onPressed: _openOriginalPdf,
                ),
                IconButton(
                  icon: const Icon(Icons.font_download),
                  tooltip: '字体大小',
                  onPressed: _showFontSizePicker,
                ),
                IconButton(
                  icon: Icon(_showNotes ? Icons.notes : Icons.note_add_outlined),
                  tooltip: '笔记',
                  onPressed: _toggleNotesPanel,
                ),
              ],
              const SizedBox(width: DesignTokens.sp1),
            ],
          ),
          body: Column(
            children: [
              // Find-in-Page bar (MD Preview style)
              if (_showFind)
                FindBar(
                  key: _findBarKey,
                  onSearch: _onFind,
                  onNavigate: _onFindNavigate,
                  onDismiss: () => setState(() => _showFind = false),
                ),
              if (widget.paper.sourceType != 'mineru')
                Container(
                  width: double.infinity,
                  padding: padSym(h: Spacing.md, v: Spacing.sm),
                  color: theme.colorScheme.secondaryContainer,
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: DesignTokens.iconSm,
                          color: theme.colorScheme.onSecondaryContainer),
                      const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: Text(
                          '轻量解析模式 — PDF 以纯文本显示，公式/图表可能不完整。',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // Mermaid badge
              if (_hasMermaidBlocks)
                Container(
                  width: double.infinity,
                  padding: padSym(h: Spacing.md, v: Spacing.xs),
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  child: Row(
                    children: [
                      Icon(Icons.account_tree, size: DesignTokens.iconSm,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: Spacing.sm),
                      Text('此文档包含 Mermaid 图表',
                          style: TextStyle(
                            fontSize: DesignTokens.fsXs,
                            color: theme.colorScheme.primary,
                          )),
                    ],
                  ),
                ),
              Expanded(
                child: Stack(
                  children: [
                    ScrollProgressBar(controller: _scrollController),
                    Column(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: _viewMode == _ViewMode.sideBySide
                                    ? Row(
                                        children: [
                                          Expanded(
                                            child: _buildContent(theme, _markdown ?? '',
                                                controller: _scrollController),
                                          ),
                                          const VerticalDivider(width: 1),
                                          Expanded(
                                            child: _buildContent(theme,
                                                _translation ?? _markdown ?? ''),
                                          ),
                                        ],
                                      )
                                    : _buildContent(theme, displayText,
                                        controller: _scrollController),
                              ),
                              if (_showNotes && !platform.isAndroid)
                                SizedBox(
                                  width: 280,
                                  child: NotesPanel(
                                      key: _notesKey, paperId: widget.paper.id),
                                ),
                            ],
                          ),
                        ),
                        QAPanel(key: _qaKey, paperId: widget.paper.id),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDisplayText() {
    return switch (_viewMode) {
      _ViewMode.original => _markdown ?? '',
      _ViewMode.translated => _translation ?? _markdown ?? '',
      _ViewMode.sideBySide => '',
    };
  }

  Widget _buildContent(ThemeData theme, String text,
      {ScrollController? controller}) {
    return SingleChildScrollView(
      controller: controller,
      padding: const EdgeInsets.all(Spacing.xl),
      child: _buildArticle(text, theme),
    );
  }

  // ── Unified Segment Builder (MD Preview inspired) ─────────────
  //
  // Renders Markdown with enhanced support:
  //  - LaTeX math (existing)
  //  - Mermaid diagrams (NEW)
  //  - Code blocks with syntax hint (NEW)

  Widget _buildArticle(String text, ThemeData theme) {
    final segments = _splitSegments(text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: segments.map((seg) {
        return switch (seg) {
          _LatexSegment s => _buildLatex(s, text, theme),
          _MermaidSegment s => _buildMermaid(s, theme),
          _CodeSegment s => _buildCodeBlock(s, theme),
          _TextSegment s => _buildText(s, theme),
        };
      }).toList(),
    );
  }

  Widget _buildLatex(_LatexSegment seg, String fullText, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      margin: const EdgeInsets.symmetric(vertical: Spacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(RadiusTokens.md),
        border: Border.all(
          color: theme.colorScheme.secondary.withValues(alpha: 0.1),
        ),
      ),
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () =>
            _explainFormula(seg.latex, _findContext(fullText, seg.latex)),
        child: Math.tex(
          seg.latex,
          textStyle: TextStyle(
            fontSize: theme.textTheme.bodyMedium?.fontSize ?? DesignTokens.fsLg,
          ),
        ),
      ),
    );
  }

  Widget _buildMermaid(_MermaidSegment seg, ThemeData theme) {
    return MermaidWidget(diagramCode: seg.code);
  }

  Widget _buildCodeBlock(_CodeSegment seg, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: Spacing.sm),
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E1E2E)
            : const Color(0xFFF5F5F0),
        borderRadius: BorderRadius.circular(RadiusTokens.md),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (seg.language.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                seg.language,
                style: TextStyle(
                  fontSize: DesignTokens.fsXs,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
          SelectableText(
            seg.code,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: DesignTokens.fsSm,
              height: DesignTokens.lhNormal,
              color: isDark
                  ? const Color(0xFFCDD6F4)
                  : const Color(0xFF1E1E2E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildText(_TextSegment seg, ThemeData theme) {
    return SelectableText(
      seg.text,
      style: theme.textTheme.bodyMedium?.copyWith(
        height: DesignTokens.lhRelaxed,
        fontSize: _fontSize,
      ),
    );
  }

  // ── Segment Splitting ─────────────────────────────────────────
  //
  // Single-pass splitter that handles LaTeX, Mermaid, and code blocks.
  // Priority: Mermaid blocks > Code blocks > LaTeX > Text.

  List<_Segment> _splitSegments(String text) {
    final segments = <_Segment>[];
    // Combined pattern: mermaid blocks, code blocks, and LaTeX
    final pattern = RegExp(
      r'```mermaid\s*\n([\s\S]*?)```'
      r'|```(\w*)\s*\n([\s\S]*?)```'
      r'|\$\$[\s\S]*?\$\$'
      r'|\\\([\s\S]*?\\\)'
      r'|\\\[[\s\S]*?\\\]',
      caseSensitive: false,
    );

    var lastEnd = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        segments.add(_TextSegment(text.substring(lastEnd, match.start)));
      }

      final full = match.group(0)!;
      if (full.startsWith('```mermaid')) {
        // Mermaid block
        segments.add(_MermaidSegment(match.group(1)?.trim() ?? ''));
      } else if (full.startsWith('```')) {
        // Code block
        segments.add(_CodeSegment(
          code: (match.group(3) ?? match.group(2) ?? '').trim(),
          language: match.group(2)?.trim() ?? '',
        ));
      } else {
        // LaTeX
        segments.add(_LatexSegment(full));
      }

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      segments.add(_TextSegment(text.substring(lastEnd)));
    }

    return segments;
  }

  String _findContext(String fullText, String target) {
    final index = fullText.indexOf(target);
    if (index == -1) return '';
    final start = (index - 200).clamp(0, fullText.length);
    final end = (index + target.length + 200).clamp(0, fullText.length);
    var context = fullText.substring(start, end);
    if (start > 0) context = '...$context';
    if (end < fullText.length) context = '$context...';
    return context;
  }

  Future<void> _explainFormula(String latex, String sectionContext) async {
    await ExplainDialog.showFormula(
      context,
      paperId: widget.paper.id,
      latex: latex,
      sectionContext: sectionContext,
    );
  }

  // ── Actions ───────────────────────────────────────────────────

  Future<void> _askAboutSelection() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final selected = data?.text?.trim() ?? '';
    if (selected.isEmpty) return;

    final controller = TextEditingController();

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(Spacing.lg, Spacing.lg, Spacing.lg,
              Spacing.lg + MediaQuery.of(sheetContext).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('选中文本',
                  style: TextStyle(
                      fontSize: DesignTokens.fsSm,
                      color: Theme.of(sheetContext)
                          .colorScheme
                          .onSurfaceVariant)),
              const SizedBox(height: Spacing.sm),
              Container(
                width: double.infinity,
                padding: padAll(Spacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(sheetContext)
                      .colorScheme
                      .surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(RadiusTokens.md),
                ),
                child: Text(
                  selected.length > 200
                      ? '${selected.substring(0, 200)}...'
                      : selected,
                  style: const TextStyle(fontSize: DesignTokens.fsSm),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: Spacing.md),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: '关于这段内容，你想问什么？',
                  border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusLg)),
                  filled: true,
                  fillColor: Theme.of(sheetContext)
                      .colorScheme
                      .surfaceContainerHighest,
                ),
                onSubmitted: (q) {
                  if (q.trim().isEmpty) return;
                  Navigator.of(sheetContext).pop();
                  _qaKey.currentState?.askQuestion(
                      '关于以下段落的提问：\n\n$selected\n\n---\n\n我的问题：$q');
                },
              ),
              const SizedBox(height: Spacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        context.noteService.addNote(
                            paperId: widget.paper.id,
                            text: selected,
                            type: NoteType.highlight,
                            selectedText: selected);
                        Navigator.of(sheetContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('已添加高亮'),
                              duration: Duration(seconds: 2)),
                        );
                      },
                      icon: const Icon(Icons.highlight,
                          size: DesignTokens.iconMd),
                      label: const Text('添加高亮'),
                    ),
                  ),
                  const SizedBox(width: Spacing.gap),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        final q = controller.text.trim();
                        if (q.isEmpty) return;
                        Navigator.of(sheetContext).pop();
                        _qaKey.currentState?.askQuestion(
                            '关于以下段落的提问：\n\n$selected\n\n---\n\n我的问题：$q');
                      },
                      icon: const Icon(Icons.smart_toy_outlined,
                          size: DesignTokens.iconMd),
                      label: const Text('提问'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _summarize() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在生成摘要...')),
    );
    try {
      final summary = await context.paperService.summarize(widget.paper.id);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('论文摘要'),
            content: SingleChildScrollView(child: SelectableText(summary)),
            actions: [
              FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭'))
            ],
          ),
        );
      }
    } catch (e) {
      _log.warning('summarize failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('生成摘要失败，请重试')),
        );
      }
    }
  }

  void _toggleStar() {
    final updated = widget.paper.copyWith(starred: !widget.paper.starred);
    context.paperService.updatePaper(updated);
    setState(() {});
  }

  Future<void> _reparseWithMineru() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重新解析'),
        content: const Text('将使用 MinerU 重新解析此 PDF，替换当前内容。确认？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确认')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final cache = context.cacheService;
    final ps2 = context.paperService;
    final pdfPath = cache.pdfPath(widget.paper.id);
    if (!await File(pdfPath).exists()) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('原始 PDF 文件不存在，无法重新解析')),
        );
      }
      return;
    }

    try {
      messenger.showSnackBar(
        const SnackBar(content: Text('正在重新解析...')),
      );
      final paper = await ps2.importPdf(File(pdfPath));
      if (!mounted) return;
      if (paper == null) {
        messenger.showSnackBar(
          const SnackBar(
              content: Text('重新解析失败：请检查 MinerU API Key')),
        );
      } else if (paper.status == PaperStatus.parsed) {
        messenger.showSnackBar(
          const SnackBar(
              content: Text('重新解析完成'), duration: Duration(seconds: 2)),
        );
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => ReadPage(paper: paper)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '重新解析失败: ${paper.errorMessage ?? "未知错误"}')),
        );
      }
    } catch (e) {
      _log.warning('reparse failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('重新解析失败，请检查网络和 API Key')),
        );
      }
    }
  }

  void _showExportMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('导出 Markdown'),
              onTap: () {
                Navigator.pop(ctx);
                _exportMarkdown();
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark),
              title: const Text('导出 BibTeX 引用'),
              onTap: () {
                Navigator.pop(ctx);
                _exportBibtex();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportMarkdown() async {
    final text = _getDisplayText();
    if (text.isEmpty) return;
    try {
      await ExportService.exportMarkdown(widget.paper, text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导出成功')),
        );
      }
    } catch (e) {
      _log.warning('export failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导出失败，请重试')),
        );
      }
    }
  }

  Future<void> _exportBibtex() async {
    try {
      await ExportService.exportBibtex(widget.paper);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('BibTeX 导出成功')),
        );
      }
    } catch (e) {
      _log.warning('export bibtex failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导出失败，请重试')),
        );
      }
    }
  }

  Future<void> _openOriginalPdf() async {
    final messenger = ScaffoldMessenger.of(context);
    final cache = context.cacheService;
    final platform = context.configService.platform;
    final pdfPath = cache.pdfPath(widget.paper.id);
    if (!await File(pdfPath).exists()) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('原始 PDF 文件不存在')),
        );
      }
      return;
    }
    try {
      await platform.openFile(pdfPath);
    } catch (e) {
      _log.warning('open PDF failed: $e');
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('无法打开 PDF，请检查文件是否被移动')),
        );
      }
    }
  }

  void _showFontSizePicker() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('字体大小'),
        content: SizedBox(
          width: 200,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('预览：学术论文阅读示例',
                  style: TextStyle(fontSize: _fontSize)),
              const SizedBox(height: Spacing.lg),
              Slider(
                value: _fontSize,
                min: 10,
                max: 24,
                divisions: 14,
                label: _fontSize.round().toString(),
                onChanged: (v) => setState(() => _fontSize = v),
              ),
              Text('${_fontSize.round()} px'),
            ],
          ),
        ),
        actions: [
          FilledButton(
              onPressed: () {
                context.configService.updateConfig(
                    context.configService.config
                        .copyWith(fontSize: _fontSize));
                Navigator.pop(ctx);
              },
              child: const Text('确定'))
        ],
      ),
    );
  }

  void _toggleNotesPanel() {
    final platform = context.configService.platform;
    if (platform.isAndroid) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (ctx, scrollController) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: Text('笔记',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              const Divider(),
              Expanded(child: NotesPanel(paperId: widget.paper.id)),
            ],
          ),
        ),
      );
    } else {
      setState(() => _showNotes = !_showNotes);
    }
  }
}

enum _ViewMode { original, translated, sideBySide }

sealed class _Segment {}

class _TextSegment extends _Segment {
  final String text;
  _TextSegment(this.text);
}

class _LatexSegment extends _Segment {
  final String latex;
  _LatexSegment(this.latex);
}

class _MermaidSegment extends _Segment {
  final String code;
  _MermaidSegment(this.code);
}

class _CodeSegment extends _Segment {
  final String code;
  final String language;
  _CodeSegment({required this.code, this.language = ''});
}
