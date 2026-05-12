import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:logging/logging.dart';
import '../../core/di/dependencies.dart';

final _log = Logger('ExplainDialog');

class ExplainDialog {
  static Future<void> showFormula(
    BuildContext context, {
    required String paperId,
    required String latex,
    required String sectionContext,
  }) async {
    showDialog(
      context: context,
      builder: (ctx) => _ExplainDialogContent(
        latex: latex,
        contextText: sectionContext,
        paperId: paperId,
      ),
    );
  }

  static Future<void> showTable(
    BuildContext context, {
    required String paperId,
    required String tableHtml,
    required String caption,
  }) async {
    showDialog(
      context: context,
      builder: (ctx) => _ExplainDialogContent(
        latex: '',
        contextText: 'Table: $caption',
        isTable: true,
        tableContent: tableHtml,
        paperId: paperId,
      ),
    );
  }
}

class _ExplainDialogContent extends StatefulWidget {
  final String latex;
  final String contextText;
  final bool isTable;
  final String tableContent;
  final String paperId;

  const _ExplainDialogContent({
    required this.latex,
    required this.contextText,
    this.isTable = false,
    this.tableContent = '',
    this.paperId = '',
  });

  @override
  State<_ExplainDialogContent> createState() => _ExplainDialogContentState();
}

class _ExplainDialogContentState extends State<_ExplainDialogContent> {
  String? _explanation;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchExplanation();
  }

  Future<void> _fetchExplanation() async {
    setState(() => _loading = true);
    try {
      final deps = Dependencies.of(context);
      final prompt = widget.isTable
          ? '请解读以下学术论文中的表格并总结关键数据趋势和发现：\n\n${widget.tableContent}\n\n上下文：${widget.contextText}'
          : '请用通俗的语言解释以下学术论文中的数学公式的含义：\n\n```\n${widget.latex}\n```\n\n上下文：${widget.contextText}';
      final answer = await deps.paperService.askQuestion(
        widget.paperId,
        prompt,
      );
      setState(() {
        _explanation = answer;
        _loading = false;
      });
    } catch (e) {
      _log.warning('explain failed: $e');
      setState(() {
        _explanation = '解释生成失败，请稍后重试。';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.isTable ? '表格解读' : '公式解释'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!widget.isTable && widget.latex.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Math.tex(
                      widget.latex,
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(widget.contextText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
              const SizedBox(height: 16),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else
                SelectableText(
                  _explanation ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
