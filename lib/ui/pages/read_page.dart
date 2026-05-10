import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:logging/logging.dart';
import '../../core/models/paper.dart';
import '../../main.dart';
import '../widgets/explain_dialog.dart';

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
  bool _qaLoading = false;
  double _fontSize = 14.0;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    final deps = Dependencies.of(context);
    final md = await deps.paperService.getMarkdown(widget.paper.id);
    final translation = await deps.paperService.getTranslation(widget.paper.id);

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final displayText = _getDisplayText();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.paper.title, style: const TextStyle(fontSize: 14)),
        actions: [
          if (_translation != null)
            SegmentedButton<_ViewMode>(
              segments: const [
                ButtonSegment(value: _ViewMode.original, label: Text('原文')),
                ButtonSegment(value: _ViewMode.translated, label: Text('译文')),
                ButtonSegment(value: _ViewMode.sideBySide, label: Text('对照')),
              ],
              selected: {_viewMode},
              onSelectionChanged: (v) => setState(() => _viewMode = v.first),
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
              ),
            ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.summarize),
            tooltip: '生成摘要',
            onPressed: _summarize,
          ),
          IconButton(
            icon: const Icon(Icons.font_download),
            tooltip: '字体大小',
            onPressed: _showFontSizePicker,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _viewMode == _ViewMode.sideBySide
                ? Row(
                    children: [
                      Expanded(child: _buildContent(theme, _markdown ?? '')),
                      const VerticalDivider(width: 1),
                      Expanded(child: _buildContent(theme, _translation ?? _markdown ?? '')),
                    ],
                  )
                : _buildContent(theme, displayText),
          ),
          _buildQAPanel(theme),
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

  Widget _buildContent(ThemeData theme, String text) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _buildArticle(text, theme),
    );
  }

  Widget _buildArticle(String text, ThemeData theme) {
    final segments = _splitByLatex(text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: segments.map((seg) {
        if (seg is _LatexSegment) {
          return GestureDetector(
            onTap: () => _explainFormula(seg.latex, _findContext(text, seg.latex)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Math.tex(
                seg.latex,
                textStyle: TextStyle(
                  fontSize: theme.textTheme.bodyMedium?.fontSize ?? 14,
                ),
              ),
            ),
          );
        }
        final textSeg = seg as _TextSegment;
        return SelectableText(
          textSeg.text,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.7, fontSize: _fontSize),
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
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_qaMessages.isNotEmpty)
            SizedBox(
              height: 120,
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _qaMessages.length,
                itemBuilder: (context, index) {
                  final msg = _qaMessages[index];
                  final isUser = msg['role'] == 'user';
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isUser
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        msg['content'] ?? '',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qaController,
                    decoration: InputDecoration(
                      hintText: '对论文提问...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                    ),
                    onSubmitted: _askQuestion,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _qaLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
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
      _qaLoading = true;
    });
    _qaController.clear();

    try {
      final deps = Dependencies.of(context);
      final answer = await deps.paperService.askQuestion(widget.paper.id, question);
      setState(() {
        _qaMessages.add({'role': 'assistant', 'content': answer});
        _qaLoading = false;
      });
    } catch (e) {
      _log.warning('askQuestion failed: $e');
      setState(() {
        _qaMessages.add({'role': 'assistant', 'content': '抱歉，回答时出现错误。'});
        _qaLoading = false;
      });
    }
  }

  Future<void> _summarize() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在生成摘要...')),
    );
    try {
      final deps = Dependencies.of(context);
      final summary = await deps.paperService.summarize(widget.paper.id);
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
              Text('预览：学术论文阅读示例', style: TextStyle(fontSize: _fontSize)),
              const SizedBox(height: 16),
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
