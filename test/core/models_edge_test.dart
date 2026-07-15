import 'package:flutter_test/flutter_test.dart';
import 'package:paperpal/core/models/paper.dart';
import 'package:paperpal/core/models/config.dart';
import 'package:paperpal/core/models/app_error.dart';
import 'package:paperpal/core/models/note.dart';
import 'package:paperpal/core/models/parse_result.dart';
import 'package:paperpal/core/models/search_result.dart';
import 'package:paperpal/core/models/soul.dart';
import 'package:paperpal/core/services/memory_service.dart';

void main() {
  group('Paper edge cases', () {
    test('copyWith clears errorMessage when null explicitly', () {
      const p = Paper(id: '1', title: 'T', errorMessage: 'old error');
      final u = p.copyWith(errorMessage: null);
      expect(u.errorMessage, isNull);
    });

    test('copyWith nulls errorMessage when not provided (explicit null param)', () {
      const p = Paper(id: '1', title: 'T', errorMessage: 'err');
      final u = p.copyWith(title: 'New');
      // copyWith signature: errorMessage is optional with default null
      // Since it's passed as `errorMessage: errorMessage` (no ?? this.errorMessage),
      // omitting it passes null, clearing the field
      expect(u.errorMessage, isNull);
    });

    test('copyWith overrides multiple fields', () {
      const p = Paper(id: '1', title: 'O', authors: ['A'], year: 2023, source: 'arXiv');
      final u = p.copyWith(title: 'N', authors: ['B'], year: 2024, doi: '10.0');
      expect(u.title, 'N');
      expect(u.authors, ['B']);
      expect(u.year, 2024);
      expect(u.doi, '10.0');
      expect(u.source, 'arXiv'); // preserved
    });

    test('copyWith replaces tags', () {
      const p = Paper(id: '1', title: 'T', tags: ['ML']);
      final u = p.copyWith(tags: ['AI', 'DL']);
      expect(u.tags, ['AI', 'DL']);
    });

    test('toJson excludes errorMessage when null', () {
      const p = Paper(id: '1', title: 'T');
      final json = p.toJson();
      expect(json.containsKey('errorMessage'), false);
    });

    test('toJson includes errorMessage when set', () {
      const p = Paper(id: '1', title: 'T', errorMessage: 'fail');
      final json = p.toJson();
      expect(json['errorMessage'], 'fail');
    });

    test('fromJson reads errorMessage', () {
      final r = Paper.fromJson({'id': '1', 'title': 'T', 'errorMessage': 'parse failed'});
      expect(r.errorMessage, 'parse failed');
    });

    test('PaperStatus values by index', () {
      expect(PaperStatus.importing.index, 0);
      expect(PaperStatus.downloading.index, 1);
      expect(PaperStatus.parsing.index, 2);
      expect(PaperStatus.parsed.index, 3);
      expect(PaperStatus.translating.index, 4);
      expect(PaperStatus.translated.index, 5);
      expect(PaperStatus.error.index, 6);
    });
  });

  group('AppConfig edge cases', () {
    test('copyWith can set forceDarkMode', () {
      const c = AppConfig();
      final u = c.copyWith(forceDarkMode: true);
      expect(u.forceDarkMode, true);
    });

    test('copyWith can set autoTranslate', () {
      const c = AppConfig(autoTranslate: true);
      final u = c.copyWith(autoTranslate: false);
      expect(u.autoTranslate, false);
    });

    test('copyWith can set fontSize', () {
      const c = AppConfig(fontSize: 14.0);
      final u = c.copyWith(fontSize: 20.0);
      expect(u.fontSize, 20.0);
    });

    test('copyWith can set logRetentionDays', () {
      const c = AppConfig(logRetentionDays: 7);
      final u = c.copyWith(logRetentionDays: 30);
      expect(u.logRetentionDays, 30);
    });

    test('copyWith can set themeMode', () {
      const c = AppConfig();
      final u = c.copyWith(themeMode: AppThemeMode.dark);
      expect(u.themeMode, AppThemeMode.dark);
    });

    test('copyWith can set mineruApiEndpoint', () {
      const c = AppConfig();
      final u = c.copyWith(mineruApiEndpoint: 'https://selfhost.example.com');
      expect(u.mineruApiEndpoint, 'https://selfhost.example.com');
    });

    test('copyWith can set defaultProvider', () {
      const c = AppConfig();
      final u = c.copyWith(defaultProvider: 'openai');
      expect(u.defaultProvider, 'openai');
    });
  });

  group('Note edge cases', () {
    test('NoteType has 3 values', () {
      expect(NoteType.values, [NoteType.note, NoteType.highlight, NoteType.question]);
    });

    test('copyWith updates type', () {
      final t = DateTime(2024, 1, 1);
      final n = Note(id: 'n1', paperId: 'p1', text: 't', createdAt: t, updatedAt: t);
      final u = n.copyWith(type: NoteType.question);
      expect(u.type, NoteType.question);
    });

    test('copyWith updates selectedText', () {
      final t = DateTime(2024, 1, 1);
      final n = Note(id: 'n1', paperId: 'p1', text: 't', createdAt: t, updatedAt: t);
      final u = n.copyWith(selectedText: 'new selection');
      expect(u.selectedText, 'new selection');
    });

    test('copyWith updates offset', () {
      final t = DateTime(2024, 1, 1);
      final n = Note(id: 'n1', paperId: 'p1', text: 't', createdAt: t, updatedAt: t, offset: 5);
      final u = n.copyWith(offset: 100);
      expect(u.offset, 100);
    });

    test('fromJson handles NoteType from string', () {
      final r = Note.fromJson({
        'id': 'n1', 'paperId': 'p1', 'text': 't',
        'createdAt': '2024-01-01T00:00:00.000',
        'updatedAt': '2024-01-01T00:00:00.000',
        'type': 'highlight',
      });
      expect(r.type, NoteType.highlight);
    });

    test('fromJson unknown NoteType defaults to note', () {
      final r = Note.fromJson({
        'id': 'n1', 'paperId': 'p1', 'text': 't',
        'createdAt': '2024-01-01T00:00:00.000',
        'updatedAt': '2024-01-01T00:00:00.000',
        'type': 'invalid',
      });
      expect(r.type, NoteType.note);
    });

    test('fromJson with offset as int', () {
      final r = Note.fromJson({
        'id': 'n1', 'paperId': 'p1', 'text': 't',
        'createdAt': '2024-01-01T00:00:00.000',
        'updatedAt': '2024-01-01T00:00:00.000',
        'offset': 42,
      });
      expect(r.offset, 42);
    });
  });

  group('SearchResult edge cases', () {
    test('source defaults to empty', () {
      const r = SearchResult(title: 'T', authors: ['A']);
      expect(r.source, '');
    });

    test('doi defaults to empty', () {
      const r = SearchResult(title: 'T', authors: ['A']);
      expect(r.doi, '');
    });

    test('constructor with all defaults', () {
      const r = SearchResult(title: 'T', authors: []);
      expect(r.authors, isEmpty);
      expect(r.year, 0);
      expect(r.abstract, '');
      expect(r.pdfUrl, '');
      expect(r.source, '');
      expect(r.doi, '');
      expect(r.citationCount, 0);
    });
  });

  group('MemoryItem edge cases', () {
    test('fromJson with paperId as null in JSON', () {
      final r = MemoryItem.fromJson({
        'id': 'm1', 'summary': 's',
        'paperId': null,
        'timestamp': '2024-01-01T00:00:00.000',
      });
      expect(r.paperId, isNull);
    });

    test('fromJson with missing timestamp defaults to now', () {
      final before = DateTime.now();
      final r = MemoryItem.fromJson({'id': 'm1', 'summary': 's'});
      expect(r.timestamp.isAfter(before.subtract(const Duration(seconds: 1))), true);
    });

    test('toJson null paperId serialized as null', () {
      final m = MemoryItem(id: 'm1', summary: 's', timestamp: DateTime(2024, 1, 1));
      final json = m.toJson();
      expect(json['paperId'], isNull);
    });
  });

  group('Soul edge cases', () {
    test('fromJson sets description from JSON', () {
      final r = Soul.fromJson({
        'id': '1', 'name': 'N', 'description': 'A cool soul',
        'systemPrompt': 'You are cool',
      });
      expect(r.description, 'A cool soul');
    });

    test('fromJson sets style and specialty', () {
      final r = Soul.fromJson({
        'id': '1', 'name': 'N', 'systemPrompt': 'P',
        'style': 'formal', 'specialty': 'math',
      });
      expect(r.style, 'formal');
      expect(r.specialty, 'math');
    });

    test('isCustom defaults to false', () {
      final r = Soul.fromJson({'id': '1', 'name': 'N', 'systemPrompt': 'P'});
      expect(r.isCustom, false);
    });

    test('toJson of custom soul', () {
      const s = Soul(
        id: 'custom_1', name: 'Custom', description: 'D',
        systemPrompt: 'P', isBuiltin: false, isCustom: true,
      );
      final json = s.toJson();
      expect(json['isCustom'], true);
      expect(json['isBuiltin'], false);
    });
  });

  group('ParseResult edge cases', () {
    test('startPage and endPage defaults', () {
      const r = ParseResult(markdown: '# M');
      expect(r.startPage, 0);
      expect(r.endPage, 0);
    });

    test('contentListJson defaults to empty', () {
      const r = ParseResult(markdown: '# M');
      expect(r.contentListJson, '');
    });
  });

  group('AppError edge cases', () {
    test('network factory defaults retryable to true', () {
      final e = AppError.network('timeout');
      expect(e.retryable, true);
    });

    test('network factory with statusCode', () {
      final e = AppError.network('not found', statusCode: 404);
      expect(e.statusCode, 404);
    });

    test('failedBatches and totalBatches default to 0', () {
      final e = AppError.unknown('boom');
      expect(e.failedBatches, 0);
      expect(e.totalBatches, 0);
    });
  });
}
