import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import '../../core/di/dependencies.dart';
import '../../core/tokens/design_tokens.dart';

final _log = Logger('QAPanel');

class QAPanel extends StatefulWidget {
  final String paperId;
  const QAPanel({super.key, required this.paperId});

  @override
  State<QAPanel> createState() => QAPanelState();
}

class QAPanelState extends State<QAPanel> {
  final _qaController = TextEditingController();
  final _qaMessages = <Map<String, String>>[];
  var _qaLoading = false;
  var _qaExpanded = false;
  static const _panelMin = 80.0;
  static const _panelMax = 0.4;

  @override
  void dispose() {
    _qaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qaHeight = _qaMessages.isEmpty
        ? _panelMin
        : _qaExpanded
            ? MediaQuery.of(context).size.height * _panelMax
            : (_qaMessages.length * 48 + _panelMin).clamp(_panelMin, 200.0);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
                        askQuestion(_qaController.text);
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
                const SizedBox(width: Spacing.sm),
                IconButton(
                  icon: _qaLoading
                      ? SizedBox(
                          width: DesignTokens.sp4,
                          height: DesignTokens.sp4,
                          child: CircularProgressIndicator(strokeWidth: DesignTokens.borderXl, color: theme.colorScheme.secondary),
                        )
                      : const Icon(Icons.send),
                  onPressed: _qaLoading ? null : () => askQuestion(_qaController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> askQuestion(String question) async {
    if (question.trim().isEmpty) return;

    setState(() {
      _qaMessages.add({'role': 'user', 'content': question});
      _qaMessages.add({'role': 'assistant', 'content': ''});
      _qaLoading = true;
    });
    _qaController.clear();

    try {
      final buffer = StringBuffer();
      await for (final chunk in context.paperService.askQuestionStream(widget.paperId, question)) {
        if (!mounted) break;
        buffer.write(chunk);
        setState(() {
          _qaMessages.last['content'] = buffer.toString();
        });
      }
      if (mounted) setState(() => _qaLoading = false);
    } catch (e) {
      _log.warning('askQuestion failed: $e');
      if (mounted) {
        setState(() {
          _qaMessages.last['content'] = _describeQAError(e);
          _qaLoading = false;
        });
      }
    }
  }

  String _describeQAError(Object e) {
    if (e is TimeoutException) return '回答超时，请重试或简化问题';
    return '抱歉，回答时出现错误。';
  }
}
