import 'package:flutter_test/flutter_test.dart';

import 'package:paperpal/core/models/note.dart';

void main() {
  group('Note model', () {
    test('creates with required fields', () {
      final now = DateTime.now();
      final note = Note(
        id: 'n1',
        paperId: 'p1',
        text: 'Interesting result',
        createdAt: now,
        updatedAt: now,
      );
      expect(note.id, 'n1');
      expect(note.text, 'Interesting result');
      expect(note.type, NoteType.note);
    });

    test('toJson and fromJson round-trip', () {
      final now = DateTime(2024, 6, 15, 10, 30);
      final note = Note(
        id: 'n1',
        paperId: 'p1',
        text: 'Key finding',
        createdAt: now,
        updatedAt: now,
        type: NoteType.highlight,
        selectedText: 'accuracy improved by 5%',
        offset: 42,
      );
      final json = note.toJson();
      final restored = Note.fromJson(json);
      expect(restored.id, note.id);
      expect(restored.paperId, note.paperId);
      expect(restored.text, note.text);
      expect(restored.type, note.type);
      expect(restored.selectedText, note.selectedText);
      expect(restored.offset, note.offset);
    });

    test('copyWith updates text and updatedAt', () {
      final now = DateTime.now();
      final note = Note(id: 'n1', paperId: 'p1', text: 'original', createdAt: now, updatedAt: now);
      final updated = note.copyWith(text: 'revised');
      expect(updated.text, 'revised');
      expect(updated.id, 'n1');
    });
  });
}
