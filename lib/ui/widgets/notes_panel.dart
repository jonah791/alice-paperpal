import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/note.dart';
import '../../core/di/dependencies.dart';
import '../../core/tokens/design_tokens.dart';

class NotesPanel extends StatefulWidget {
  final String paperId;
  const NotesPanel({super.key, required this.paperId});

  @override
  State<NotesPanel> createState() => NotesPanelState();
}

class NotesPanelState extends State<NotesPanel> {
  final _noteController = TextEditingController();
  List<Note> _notes = [];

  @override
  void initState() {
    super.initState();
    _notes = context.noteService.getNotesForPaper(widget.paperId);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _refreshNotes() {
    _notes = context.noteService.getNotesForPaper(widget.paperId);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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

  Widget _buildNoteCard(Note note, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: theme.colorScheme.secondary, width: 3),
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
          Text(note.text, style: TextStyle(fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: DesignTokens.fsSm)),
          const SizedBox(height: DesignTokens.sp1),
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
                      style: TextStyle(fontSize: DesignTokens.fsXxs,
                          color: note.type == NoteType.highlight ? Colors.amber.shade800 : theme.colorScheme.onTertiaryContainer)),
                ),
              Text(_formatDate(note.createdAt),
                  style: TextStyle(fontSize: DesignTokens.fsXxs, color: theme.colorScheme.onSurface.withValues(alpha: 0.25))),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _addNote({String? text, String? selectedText}) async {
    final content = text ?? _noteController.text.trim();
    if (content.isEmpty) return;

    await context.noteService.addNote(
      paperId: widget.paperId,
      text: content,
      selectedText: selectedText,
    );
    _noteController.clear();
    _refreshNotes();
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
              const SizedBox(height: Spacing.sm),
              Container(
                width: double.infinity,
                padding: padAll(Spacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(sheetContext).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(RadiusTokens.md),
                ),
                child: Text(selected.isNotEmpty ? (selected.length > 150 ? '${selected.substring(0, 150)}...' : selected) : '(未选中文本)',
                  style: const TextStyle(fontSize: DesignTokens.fsSm), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(height: Spacing.md),
              TextField(
                controller: textCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '添加笔记...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusLg)),
                  filled: true,
                  fillColor: Theme.of(sheetContext).colorScheme.surfaceContainerHighest,
                ),
                onSubmitted: (t) {
                  if (t.trim().isEmpty) return;
                  Navigator.of(sheetContext).pop();
                  _addNote(text: t.trim(), selectedText: selected.isNotEmpty ? selected : null);
                },
              ),
              const SizedBox(height: Spacing.md),
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

  Future<void> _deleteNote(Note note) async {
    await context.noteService.deleteNote(note.id);
    _refreshNotes();
  }

  String _formatDate(DateTime d) =>
      '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _noteTypeLabel(NoteType t) => switch (t) {
    NoteType.note => '笔记',
    NoteType.highlight => '高亮',
    NoteType.question => '问题',
  };
}
