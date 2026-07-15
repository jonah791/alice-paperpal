import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:logging/logging.dart';
import '../../core/models/paper.dart';
import '../../core/models/note.dart';
import '../../core/services/export_service.dart';
import '../../core/di/dependencies.dart';
import '../../core/tokens/design_tokens.dart';
import '../widgets/explain_dialog.dart';
import '../widgets/progress_bar.dart';

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
  final _qaController = TextEditingController();
  final _qaMessages = <Map<String, String>>[];
  String? _selectedTextForAsk;
  bool _qaExpanded = false;
  static const _qaPanelMin = 80.0;
  static const _qaPanelMax = 0.4;
  bool _qaLoading = false;
  double _fontSize = DesignTokens.fsLg;
  bool _showNotes = false;
  final _noteController = TextEditingController();
  List<Note> _notes = [];
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadContent());
  }

  Future<void> _loadContent() async {
    final md = await context.paperService.getMarkdown(widget.paper.id);
    final translation = await context.paperService.getTranslation(widget.paper.id);
    _notes = context.noteService.getNotesForPaper(widget.paper.id);
    // Touch (update lastReadAt) only after content is confirmed accessible
    if (md != null) context.paperService.touchPaper(widget.paper.id);

    setState(() {
      _markdown = md;
      _translation = translation;
      _loading = false;
      if (translation == null) _viewMode = _ViewMode.original;
    });
  }

  @override
  void dispose() {
    _qaController.dispose();
    _noteController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final platform = context.configService.platform;

    // Note: BottomSheet is triggered from the notes button's onPressed,
    // NOT from build() — see _toggleNotesPanel(). This avoids the
    // infinite-loop crash from addPostFrameCallback inside build().

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final displayText = _getDisplayText();

    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'ask_selection',
        onPressed: () => _askAboutSelection(),
        tooltip: '选中文本提问',
        child: const Icon(Icons.smart_toy_outlined, size: DesignTokens.iconMd),
      ),
      appBar: AppBar(
        title: Text(widget.paper.title, style: const TextStyle(fontSize: DesignTokens.fsLg)),
        actions: [
          if (_translation != null)
            SegmentedButton<_ViewMode>(
              segments: [
                ButtonSegment(value: _ViewMode.original, label: Text('原文')),
                ButtonSegment(value: _ViewMode.translated, label: Text('译文')),
                if (!platform.isAndroid)
                  ButtonSegment(value: _ViewMode.sideBySide, label: Text('对照')),
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
          if (widget.paper.sourceType != 'mineru')
            Container(
              width: double.infinity,
              padding: padSym(h: Spacing.md, v: Spacing.sm),
              color: theme.colorScheme.secondaryContainer,
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: DesignTokens.iconSm, color: theme.colorScheme.onSecondaryContainer),
                  SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      '轻量解析模式 — PDF 以纯文本显示，公式/图表可能不完整。',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSecondaryContainer),
                    ),
                  ),
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
                                Expanded(child: _buildContent(theme, _markdown ?? '', controller: _scrollController)),
                                const VerticalDivider(width: 1),
                                Expanded(child: _buildContent(theme, _translation ?? _markdown ?? '')),
                              ],
                            )
                          : _buildContent(theme, displayText, controller: _scrollController),
                    ),
                    if (_showNotes && !platform.isAndroid)
                      SizedBox(
                        width: 280,
                        child: _buildNotesPanel(theme),
                      ),
                  ],
                ),
              ),
              _buildQAPanel(theme),
            ],
          ),
        ],
      ),
    ),
  ],
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

  Widget _buildContent(ThemeData theme, String text, {ScrollController? controller}) {
    return SingleChildScrollView(
      controller: controller,
      padding: const EdgeInsets.all(Spacing.xl),
      child: _buildArticle(text, theme),
    );
  }

  Widget _buildArticle(String text, ThemeData theme) {
    final segments = _splitByLatex(text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: segments.map((seg) {
        if (seg is _LatexSegment) {
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
              onTap: () => _explainFormula(seg.latex, _findContext(text, seg.latex)),
              child: Math.tex(
                seg.latex,
                textStyle: TextStyle(
                  fontSize: theme.textTheme.bodyMedium?.fontSize ?? DesignTokens.fsLg,
                ),
              ),
            ),
          );
        }
        final textSeg = seg as _TextSegment;
        return SelectableText(
          textSeg.text,
          style: theme.textTheme.bodyMedium?.copyWith(height: DesignTokens.lhRelaxed, fontSize: _fontSize),
        );
      }).toList(),
    );
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

  List<_Segment> _splitByLatex(String text) {
    final segments = <_Segment>[];
    final pattern = RegExp(r'\$\$[\s\S]*?\$\$|\\\([\s\S]*?\\\)|\\\[[\s\S]*?\\\]');
    var lastEnd = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        segments.add(_TextSegment(text.substring(lastEnd, match.start)));
      }
      segments.add(_LatexSegment(match.group(0)!));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      segments.add(_TextSegment(text.substring(lastEnd)));
    }

    return segments;
  }

  Widget _buildQAPanel(ThemeData theme) {
    final qaHeight = _qaMessages.isEmpty
        ? _qaPanelMin
        : _qaExpanded
            ? MediaQuery.of(context).size.height * _qaPanelMax
            : (_qaMessages.length * 48 + _qaPanelMin).clamp(_qaPanelMin, 200.0);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header bar with expand toggle
          if (_qaMessages.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() => _qaExpanded = !_qaExpanded),
              child: Container(
                padding: padSym(h: Spacing.md, v: DesignTokens.sp1),
                child: Row(
                  children: [
                    Text('问答 (${_qaMessages.length})', style: TextStyle(fontSize: DesignTokens.fsXs, color: theme.colorScheme.onSurfaceVariant)),
                    const Spacer(),
                    Icon(_qaExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up, size: DesignTokens.iconSm, color: theme.colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          // Messages list
          if (_qaMessages.isNotEmpty)
            SizedBox(
              height: qaHeight,
              child: ListView.builder(
                padding: padSym(h: Spacing.gap, v: Spacing.sm),
                itemCount: _qaMessages.length,
                itemBuilder: (context, index) {
                  final msg = _qaMessages[index];
                  final isUser = msg['role'] == 'user';
                  return Padding(
                    padding: padOnly(b: DesignTokens.sp1),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isUser)
                          Padding(
                            padding: padOnly(r: DesignTokens.sp1, t: DesignTokens.sp1),
                            child: CircleAvatar(
                              radius: 10,
                              backgroundColor: theme.colorScheme.secondary,
                              child: Text('A', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSecondary, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        Flexible(
                          child: Container(
                            padding: padAll(Spacing.sm),
                            decoration: BoxDecoration(
                              color: isUser ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                            ),
                            child: Text(
                              msg['content'] ?? '',
                              style: TextStyle(fontSize: DesignTokens.fsSm, color: theme.colorScheme.onSurface),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          // Input row
          Padding(
            padding: padAll(Spacing.gap),
            child: Row(
              children: [
                Expanded(
                  child: Focus(
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter &&
                          !HardwareKeyboard.instance.isShiftPressed) {
                        node.nextFocus();
                        _askQuestion(_qaController.text);
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: _qaController,
                      decoration: InputDecoration(
                        hintText: 'Shift+Enter 换行，Enter 发送',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                        contentPadding: padSym(h: Spacing.lg, v: Spacing.sm),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        isDense: true,
                      ),
                      maxLines: 4,
                      minLines: 1,
                    ),
                  ),
                ),
                SizedBox(width: Spacing.sm),
                IconButton(
                  icon: _qaLoading
                      ? SizedBox(
                          width: DesignTokens.sp4,
                          height: DesignTokens.sp4,
                          child: CircularProgressIndicator(strokeWidth: DesignTokens.borderXl, color: theme.colorScheme.secondary),
                        )
                      : const Icon(Icons.send),
                  onPressed: _qaLoading ? null : () => _askQuestion(_qaController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _askQuestion(String question) async {
    if (question.trim().isEmpty) return;

    setState(() {
      _qaMessages.add({'role': 'user', 'content': question});
      _qaMessages.add({'role': 'assistant', 'content': ''});
      _qaLoading = true;
    });
    _qaController.clear();

    try {
  
      final buffer = StringBuffer();
      await for (final chunk in context.paperService.askQuestionStream(widget.paper.id, question)) {
        if (!mounted) break;
        buffer.write(chunk);
        setState(() {
          _qaMessages.last['content'] = buffer.toString();
        });
      }
      if (mounted) setState(() => _qaLoading = false);
    } catch (e) {
      _log.warning('askQuestion failed: $e');
      if (mounted) setState(() {
        _qaMessages.last['content'] = _describeQAError(e);
        _qaLoading = false;
      });
    }
  }

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
          padding: EdgeInsets.fromLTRB(Spacing.lg, Spacing.lg, Spacing.lg, Spacing.lg + MediaQuery.of(sheetContext).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('选中文本', style: TextStyle(fontSize: DesignTokens.fsSm, color: Theme.of(sheetContext).colorScheme.onSurfaceVariant)),
              SizedBox(height: Spacing.sm),
              Container(
                width: double.infinity,
                padding: padAll(Spacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(sheetContext).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(RadiusTokens.md),
                ),
                child: Text(selected.length > 200 ? '${selected.substring(0, 200)}...' : selected,
                  style: TextStyle(fontSize: DesignTokens.fsSm),
                  maxLines: 3, overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(height: Spacing.md),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: '关于这段内容，你想问什么？',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusLg)),
                  filled: true,
                  fillColor: Theme.of(sheetContext).colorScheme.surfaceContainerHighest,
                ),
                onSubmitted: (q) {
                  if (q.trim().isEmpty) return;
                  Navigator.of(sheetContext).pop();
                  _askQuestion('关于以下段落的提问：\n\n$selected\n\n---\n\n我的问题：$q');
                },
              ),
              SizedBox(height: Spacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    final q = controller.text.trim();
                    if (q.isEmpty) return;
                    Navigator.of(sheetContext).pop();
                    _askQuestion('关于以下段落的提问：\n\n$selected\n\n---\n\n我的问题：$q');
                  },
                  icon: const Icon(Icons.send, size: DesignTokens.iconSm),
                  label: const Text('提问'),
                ),
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
            actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('关闭'))],
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

  Future<void> _reparseWithMineru() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重新解析'),
        content: const Text('将使用 MinerU 重新解析此 PDF，替换当前内容。确认？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final pdfPath = context.cacheService.pdfPath(widget.paper.id);
    if (!await File(pdfPath).exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('原始 PDF 文件不存在，无法重新解析')),
        );
      }
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在重新解析...')),
      );
      final paper = await context.paperService.importPdf(File(pdfPath));
      if (!mounted) return;
      if (paper == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('重新解析失败：请检查 MinerU API Key')),
        );
      } else if (paper.status == PaperStatus.parsed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('重新解析完成'), duration: Duration(seconds: 2)),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ReadPage(paper: paper)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('重新解析失败: ${paper.errorMessage ?? "未知错误"}')),
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

    final pdfPath = context.cacheService.pdfPath(widget.paper.id);
    if (!await File(pdfPath).exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('原始 PDF 文件不存在')),
        );
      }
      return;
    }
    try {
      await context.configService.platform.openFile(pdfPath);
    } catch (e) {
      _log.warning('open PDF failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开 PDF，请检查文件是否被移动')),
        );
      }
    }
  }

  Widget _buildNotesPanel(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(left: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        children: [
          Expanded(
            child: _notes.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(Spacing.lg),
                      child: Text('暂无笔记\n选中文本后点击"添加笔记"',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          )),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(Spacing.gap),
                    itemCount: _notes.length,
                    itemBuilder: (ctx, i) => _buildNoteCard(_notes[i], theme),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(Spacing.gap),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _noteController,
                    decoration: InputDecoration(
                      hintText: '添加笔记...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(RadiusTokens.lg)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.gap),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                    ),
                    maxLines: 2,
                    minLines: 1,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.content_paste, size: DesignTokens.iconMd),
                  tooltip: '从选中文本创建',
                  onPressed: _addNoteWithSelection,
                ),
                IconButton(
                  icon: const Icon(Icons.send, size: DesignTokens.iconMd),
                  onPressed: () => _addNote(text: _noteController.text.trim()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteNote(Note note) async {
    await context.noteService.deleteNote(note.id);
    _notes = context.noteService.getNotesForPaper(widget.paper.id);
    setState(() {});
  }

  Widget _buildNoteCard(Note note, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.secondary,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (note.selectedText != null && note.selectedText!.isNotEmpty)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(DesignTokens.sp1),
                    margin: const EdgeInsets.only(bottom: DesignTokens.sp1),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(RadiusTokens.sm),
                    ),
                    child: Text(note.selectedText!,
                        style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                  ),
                ),
              InkWell(
                onTap: () => _deleteNote(note),
                child: Padding(
                  padding: padOnly(l: Spacing.sm),
                  child: Icon(Icons.close, size: 14, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                ),
              ),
            ],
          ),
          Text(
            note.text,
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: DesignTokens.fsSm,
            ),
          ),
          SizedBox(height: DesignTokens.sp1),
          Row(
            children: [
              if (note.type != NoteType.note)
                Container(
                  padding: padSym(h: DesignTokens.sp1, v: 1),
                  margin: padOnly(r: Spacing.sm),
                  decoration: BoxDecoration(
                    color: note.type == NoteType.highlight
                        ? Colors.amber.withValues(alpha: 0.15)
                        : theme.colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(RadiusTokens.sm),
                  ),
                  child: Text(_noteTypeLabel(note.type),
                      style: TextStyle(fontSize: DesignTokens.fsXxs, color: note.type == NoteType.highlight ? Colors.amber.shade800 : theme.colorScheme.onTertiaryContainer)),
                ),
              Text(
                _formatDate(note.createdAt),
                style: TextStyle(
                  fontSize: DesignTokens.fsXxs,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _describeQAError(Object e) {
    if (e is TimeoutException) return '回答超时，请重试或简化问题';
    return '抱歉，回答时出现错误。';
  }

  String _noteTypeLabel(NoteType t) => switch (t) {
    NoteType.note => '笔记',
    NoteType.highlight => '高亮',
    NoteType.question => '问题',
  };

  Future<void> _addNote({String? text, String? selectedText}) async {
    final content = text ?? _noteController.text.trim();
    if (content.isEmpty) return;

    await context.noteService.addNote(
      paperId: widget.paper.id,
      text: content,
      selectedText: selectedText,
    );
    _noteController.clear();
    _notes = context.noteService.getNotesForPaper(widget.paper.id);
    setState(() {});
  }

  Future<void> _addNoteWithSelection() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final selected = data?.text?.trim() ?? '';
    _noteController.clear();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final textCtrl = TextEditingController();
        return Padding(
          padding: EdgeInsets.fromLTRB(Spacing.lg, Spacing.lg, Spacing.lg, Spacing.lg + MediaQuery.of(sheetContext).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('选中内容', style: TextStyle(fontSize: DesignTokens.fsSm, color: Theme.of(sheetContext).colorScheme.onSurfaceVariant)),
              SizedBox(height: Spacing.sm),
              Container(
                width: double.infinity,
                padding: padAll(Spacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(sheetContext).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(RadiusTokens.md),
                ),
                child: Text(selected.isNotEmpty ? (selected.length > 150 ? '${selected.substring(0, 150)}...' : selected) : '(未选中文本)',
                  style: TextStyle(fontSize: DesignTokens.fsSm),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(height: Spacing.md),
              TextField(
                controller: textCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '添加笔记...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusLg)),
                  filled: true,
                  fillColor: Theme.of(sheetContext).colorScheme.surfaceContainerHighest,
                ),
                onSubmitted: (t) async {
                  if (t.trim().isEmpty) return;
                  Navigator.of(sheetContext).pop();
                  _addNote(text: t.trim(), selectedText: selected.isNotEmpty ? selected : null);
                },
              ),
              SizedBox(height: Spacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    final t = textCtrl.text.trim();
                    if (t.isEmpty) return;
                    Navigator.of(sheetContext).pop();
                    _addNote(text: t, selectedText: selected.isNotEmpty ? selected : null);
                  },
                  icon: const Icon(Icons.note_add, size: DesignTokens.iconSm),
                  label: const Text('添加笔记'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime d) =>
      '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

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
              Text('预览：学术论文阅读示例', style: TextStyle(fontSize: _fontSize)),
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
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('确定'))],
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
                child: Text('笔记', style: Theme.of(context).textTheme.titleMedium),
              ),
              const Divider(),
              Expanded(child: _buildNotesPanel(Theme.of(context))),
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
