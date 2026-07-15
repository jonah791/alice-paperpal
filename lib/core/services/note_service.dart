import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../interfaces/services.dart';

final _log = Logger('NoteService');
const _uuid = Uuid();

class NoteService implements INoteService {
  late final String _filePath;
  List<Note> _notes = [];

  @override
  Future<void> init() async {
    final dir = await getApplicationSupportDirectory();
    _filePath = '${dir.path}/notes.json';
    await _load();
    _log.info('init: ${_notes.length} notes loaded');
  }

  Future<void> _load() async {
    final file = File(_filePath);
    if (!await file.exists()) return;
    try {
      final json = await file.readAsString();
      final list = jsonDecode(json) as List;
      _notes = list.map((e) => Note.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      _log.warning('load notes failed: $e');
    }
  }

  Future<void> _save() async {
    final json = jsonEncode(_notes.map((n) => n.toJson()).toList());
    await File(_filePath).writeAsString(json);
  }

  @override
  List<Note> getNotesForPaper(String paperId) =>
      _notes.where((n) => n.paperId == paperId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<Note> addNote({
    required String paperId,
    required String text,
    NoteType type = NoteType.note,
    String? selectedText,
    int? offset,
  }) async {
    final note = Note(
      id: _uuid.v4(),
      paperId: paperId,
      text: text,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      type: type,
      selectedText: selectedText,
      offset: offset,
    );
    _notes.add(note);
    await _save();
    _log.info('addNote: ${note.id}');
    return note;
  }

  @override
  Future<void> updateNote(String noteId, String text) async {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index < 0) return;
    _notes[index] = _notes[index].copyWith(text: text);
    await _save();
    _log.info('updateNote: $noteId');
  }

  @override
  Future<void> deleteNote(String noteId) async {
    _notes.removeWhere((n) => n.id == noteId);
    await _save();
    _log.info('deleteNote: $noteId');
  }

  @override
  Future<void> deleteNotesForPaper(String paperId) async {
    _notes.removeWhere((n) => n.paperId == paperId);
    _log.info('deleteNotesForPaper: $paperId -> notes cleaned');
    await _save();
  }
}
