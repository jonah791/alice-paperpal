/// Kori 风格笔记面板
import 'package:flutter/material.dart';
import '../../core/di/dependencies.dart';
import '../../core/interfaces/services.dart';
import '../../core/models/note.dart';

class NotesPanel extends StatefulWidget {
  final String paperId;
  const NotesPanel({super.key, required this.paperId});

  @override
  State<NotesPanel> createState() => NotesPanelState();
}

class NotesPanelState extends State<NotesPanel> {
  final _inputCtrl = TextEditingController();
  bool _loading = true;
  List<Note> _notes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _notes = context.noteService.getNotesForPaper(widget.paperId);
      _loading = false;
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    await context.noteService.addNote(paperId: widget.paperId, text: text);
    _load();
  }

  Future<void> _delete(String id) async {
    await context.noteService.deleteNote(id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(left: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text('笔记', style: theme.textTheme.titleSmall),
                const Spacer(),
                Text('${_notes.length}', style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _notes.isEmpty
                    ? Center(
                        child: Text('暂无笔记', style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _notes.length,
                        itemBuilder: (ctx, i) {
                          final note = _notes[i];
                          return Card(
                            elevation: 0,
                            color: colors.surfaceContainerLow,
                            margin: const EdgeInsets.only(bottom: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (note.selectedText != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: colors.tertiary.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text('引用', style: TextStyle(fontSize: 10, color: colors.tertiary)),
                                        ),
                                      const Spacer(),
                                      InkWell(
                                        onTap: () => _delete(note.id),
                                        child: Icon(Icons.close, size: 14, color: colors.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(note.text, style: const TextStyle(fontSize: 12, height: 1.5)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    maxLines: 2,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: '添加笔记...',
                      filled: true,
                      fillColor: colors.surfaceContainerHighest,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  onPressed: _add,
                  icon: const Icon(Icons.add, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
