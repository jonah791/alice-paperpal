/// Kori 风格公式/术语解释弹窗
import 'package:flutter/material.dart';
import '../../core/di/dependencies.dart';
import '../../core/tokens/design_tokens.dart';

Future<void> showExplainDialog(BuildContext context, String formula, String contextText) {
  return showDialog(
    context: context,
    builder: (ctx) => _ExplainDialog(formula: formula, contextText: contextText),
  );
}

class _ExplainDialog extends StatefulWidget {
  final String formula;
  final String contextText;
  const _ExplainDialog({required this.formula, required this.contextText});

  @override
  State<_ExplainDialog> createState() => _ExplainDialogState();
}

class _ExplainDialogState extends State<_ExplainDialog> {
  String? _explanation;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final text = '解释以下内容：${widget.formula}\n上下文：${widget.contextText}';
      final answer = await context.llmProvider.chat([
        {'role': 'system', 'content': '你是一位耐心的导师。用中文解释这个公式或术语。'},
        {'role': 'user', 'content': text},
      ], maxTokens: 300);
      if (mounted) setState(() => _explanation = answer);
    } catch (_) {
      if (mounted) setState(() => _explanation = '解释失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('解释'),
      content: SizedBox(
        width: 400,
        child: _loading
            ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
                child: SelectableText(
                  _explanation ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
      ],
    );
  }
}
