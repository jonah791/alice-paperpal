import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:paperpal/core/api/mineru_api.dart';

void main() {
  group('MineruApi parseState full coverage', () {
    final api = MineruApi(apiKey: 'test-key');

    test('waiting-file maps to pending', () {
      expect(api.parseState('waiting-file'), MineruTaskState.pending);
    });

    test('uploading maps to running', () {
      expect(api.parseState('uploading'), MineruTaskState.running);
    });

    test('empty string maps to pending', () {
      expect(api.parseState(''), MineruTaskState.pending);
    });

    test('null-like string maps to pending', () {
      expect(api.parseState('unknown'), MineruTaskState.pending);
    });
  });

  group('MineruApi _extractZip', () {
    test('extracts markdown from ZIP', () {
      final api = MineruApi(apiKey: 'k');
      final archive = Archive();
      archive.addFile(ArchiveFile('output.md', 10, Uint8List.fromList('Hello world'.codeUnits)));
      final zipBytes = ZipEncoder().encode(archive);
      final result = api.extractZip(zipBytes, '/tmp/test_mineru');
      expect(result.markdown, 'Hello world');
      expect(result.imagePaths, isEmpty);
      expect(result.contentListJson, '');
    });

    test('extracts markdown and content_list_v2.json', () {
      final api = MineruApi(apiKey: 'k');
      final archive = Archive();
      archive.addFile(ArchiveFile('output.md', 4, Uint8List.fromList('text'.codeUnits)));
      archive.addFile(ArchiveFile('content_list_v2.json', 2, Uint8List.fromList('[]'.codeUnits)));
      final zipBytes = ZipEncoder().encode(archive);
      final result = api.extractZip(zipBytes, '/tmp/test_mineru');
      expect(result.markdown, 'text');
      expect(result.contentListJson, '[]');
    });

    test('extracts _content_list.json (legacy)', () {
      final api = MineruApi(apiKey: 'k');
      final archive = Archive();
      archive.addFile(ArchiveFile('doc.md', 2, Uint8List.fromList('a'.codeUnits)));
      archive.addFile(ArchiveFile('doc_content_list.json', 2, Uint8List.fromList('{}'.codeUnits)));
      final zipBytes = ZipEncoder().encode(archive);
      final result = api.extractZip(zipBytes, '/tmp/test_mineru');
      expect(result.markdown, 'a');
      expect(result.contentListJson, '{}');
    });

    test('skips hidden files (starting with dot)', () {
      final api = MineruApi(apiKey: 'k');
      final archive = Archive();
      archive.addFile(ArchiveFile('.hidden.md', 3, Uint8List.fromList('bad'.codeUnits)));
      archive.addFile(ArchiveFile('visible.md', 4, Uint8List.fromList('good'.codeUnits)));
      final zipBytes = ZipEncoder().encode(archive);
      final result = api.extractZip(zipBytes, '/tmp/test_mineru');
      expect(result.markdown, 'good');
    });

    test('extracts images from images/ directory', () {
      final api = MineruApi(apiKey: 'k');
      final archive = Archive();
      archive.addFile(ArchiveFile('doc.md', 5, Uint8List.fromList('markd'.codeUnits)));
      final imgData = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
      archive.addFile(ArchiveFile('images/fig1.png', imgData.length, imgData));
      archive.addFile(ArchiveFile('images/charts/graph.jpg', 2, Uint8List(2)));
      final zipBytes = ZipEncoder().encode(archive);
      final result = api.extractZip(zipBytes, '/tmp/test_mineru');
      expect(result.markdown, 'markd');
      // Image paths include output directory prefix
      expect(result.imagePaths.where((p) => p.contains('fig1.png')), isNotEmpty);
    });

    test('handles empty ZIP archive', () {
      final api = MineruApi(apiKey: 'k');
      final archive = Archive();
      final zipBytes = ZipEncoder().encode(archive);
      final result = api.extractZip(zipBytes, '/tmp/test_mineru');
      expect(result.markdown, '');
      expect(result.imagePaths, isEmpty);
      expect(result.contentListJson, '');
    });

    test('last .md file wins (overwrites previous)', () {
      final api = MineruApi(apiKey: 'k');
      final archive = Archive();
      archive.addFile(ArchiveFile('first.md', 5, Uint8List.fromList('first'.codeUnits)));
      archive.addFile(ArchiveFile('second.md', 6, Uint8List.fromList('second'.codeUnits)));
      final zipBytes = ZipEncoder().encode(archive);
      final result = api.extractZip(zipBytes, '/tmp/test_mineru');
      expect(result.markdown, 'second');
    });
  });

  group('MineruResult', () {
    test('defaults for imagePaths and contentListJson', () {
      const r = MineruResult(markdown: '# T');
      expect(r.imagePaths, isEmpty);
      expect(r.contentListJson, '');
    });

    test('equality by value', () {
      const a = MineruResult(markdown: '# A');
      const b = MineruResult(markdown: '# A');
      expect(a.markdown, b.markdown);
    });
  });

  group('MineruTask defaults', () {
    test('extractedPages and totalPages default to 0', () {
      const t = MineruTask(id: '1', state: MineruTaskState.pending);
      expect(t.extractedPages, 0);
      expect(t.totalPages, 0);
    });

    test('errorMessage defaults to null', () {
      const t = MineruTask(id: '1', state: MineruTaskState.done);
      expect(t.errorMessage, isNull);
    });

    test('zipUrl defaults to null', () {
      const t = MineruTask(id: '1', state: MineruTaskState.pending);
      expect(t.zipUrl, isNull);
    });
  });
}
