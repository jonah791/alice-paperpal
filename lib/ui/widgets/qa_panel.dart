/// Kori 风格问答面板
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/di/dependencies.dart';
import '../../core/interfaces/services.dart';
import 'avatar_helpers.dart';

class QAPanel extends StatefulWidget {
  final String paperId;
  const QAPanel({super.key, required this.paperId});

  @override
  State<QAPanel> createState() => QAPanelState();
}

class QAPanelState extends State<QAPanel> {
  final _inputCtrl = TextEditingController();
  final _messages = <_Message>[];
  final _scrollCtrl = ScrollController();
  bool _loading = false;
  StreamSubscription? _streamSub;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _streamSub?.cancel();
    super.dispose();
  }

  void askWithText(String text) {
    _inputCtrl.text = text;
    _send();
  }

  Future<void> _send() async {
    final question = _inputCtrl.text.trim();
    if (question.isEmpty) return;
    _inputCtrl.clear();

    setState(() {
      _messages.add(_Message(role: 'user', text: question));
      _loading = true;
    });
    _scrollToBottom();

    try {
      final buffer = StringBuffer();
      final msg = _Message(role: 'ai', text: '');
      setState(() => _messages.add(msg));

      await for (final chunk in context.paperService.askQuestionStream(widget.paperId, question)) {
        buffer.write(chunk);
        setState(() => _messages.last = _Message(role: 'ai', text: buffer.toString()));
        _scrollToBottom();
      }
    } catch (e) {
      setState(() {
        if (_messages.last.role == 'ai') {
          _messages.last = _Message(role: 'ai', text: '回答失败，请稍后重试');
        } else {
          _messages.add(_Message(role: 'ai', text: '回答失败，请稍后重试'));
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text('AI 问答', style: theme.textTheme.titleSmall),
                const Spacer(),
                if (_messages.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => setState(() => _messages.clear()),
                    icon: const Icon(Icons.delete_sweep, size: 16),
                    label: const Text('清除', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Messages
          if (_messages.isNotEmpty)
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (ctx, i) {
                    final msg = _messages[i];
                    final isUser = msg.role == 'user';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isUser) ...[
                            buildDefaultAvatar('AI', 24, colors.primary.value),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isUser ? colors.primaryContainer : colors.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                msg.text,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: isUser ? colors.onPrimaryContainer : colors.onSurface,
                                ),
                              ),
                            ),
                          ),
                          if (isUser) const SizedBox(width: 8),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          // Input
          Container(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    maxLines: 3,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: '问关于这篇论文的问题...',
                      filled: true,
                      fillColor: colors.surfaceContainerHighest,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _loading ? null : _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _loading ? null : _send,
                  icon: _loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Message {
  final String role;
  final String text;
  const _Message({required this.role, required this.text});
}
