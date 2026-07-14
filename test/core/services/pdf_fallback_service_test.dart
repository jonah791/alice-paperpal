import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperpal/core/services/pdf_fallback_service.dart';

void main() {
  late PdfFallbackService service;

  setUp(() {
    service = PdfFallbackService();
  });

  group('extractTitle', () {
    test('extracts first non-header line', () {
      final result = service.extractTitle('## Header\n\nTitle Text\n\nBody');
      expect(result, 'Title Text');
    });

    test('skips hash-prefixed lines', () {
      final result = service.extractTitle('# Title\n## Sub\n\nReal Title Here');
      expect(result, 'Real Title Here');
    });

    test('returns Untitled for empty text', () {
      expect(service.extractTitle(''), 'Untitled');
    });

    test('truncates long titles at 120 chars', () {
      final long = 'A' * 200;
      expect(service.extractTitle(long).length, 120);
    });

    test('prefers real title over all-hash lines', () {
      final result = service.extractTitle('# Document\n## Abstract\n\nThis is my paper title');
      expect(result, 'This is my paper title');
    });
  });

  group('splitSections', () {
    test('splits on blank lines', () {
      final text = 'Line 1\nLine 2\n\nLine 3\n\nLine 4';
      final sections = service.splitSections(text);
      expect(sections.length, 3);
      expect(sections[0], 'Line 1\nLine 2');
    });

    test('marks common section headers with ##', () {
      final text = 'Abstract\nThis is the abstract.\n\nIntroduction\nContent.';
      final sections = service.splitSections(text);
      expect(sections.any((s) => s.startsWith('## Abstract')), true);
      expect(sections.any((s) => s.startsWith('## Introduction')), true);
    });

    test('handles single section', () {
      expect(service.splitSections('Just one block'), ['Just one block']);
    });

    test('returns empty list for empty string', () {
      expect(service.splitSections(''), []);
    });

    test('removes trailing empty sections', () {
      final text = 'Section 1\n\nSection 2\n\n';
      final sections = service.splitSections(text);
      expect(sections.length, 2);
      expect(sections[0], 'Section 1');
      expect(sections[1], 'Section 2');
    });
  });

  group('isSectionHeader', () {
    test('recognizes Introduction', () {
      expect(service.isSectionHeader('Introduction'), true);
    });

    test('recognizes Related Work', () {
      expect(service.isSectionHeader('Related Work'), true);
    });

    test('recognizes Chinese headers', () {
      expect(service.isSectionHeader('方法'), true);
      expect(service.isSectionHeader('实验'), true);
      expect(service.isSectionHeader('结论'), true);
    });

    test('rejects long lines', () {
      expect(service.isSectionHeader('A' * 61), false);
    });

    test('rejects empty', () {
      expect(service.isSectionHeader(''), false);
    });

    test('is case insensitive', () {
      expect(service.isSectionHeader('abstract'), true);
      expect(service.isSectionHeader('ABSTRACT'), true);
    });

    test('recognizes compound headers', () {
      expect(service.isSectionHeader('Related work'), true);
      expect(service.isSectionHeader('Background'), true);
    });
  });

  group('parseAsText integration', () {
    test('returns result for valid PDF even without poppler', () async {
      final fixture = File('test/fixtures/sample.pdf');
      if (!await fixture.exists()) {
        fixture.parent.createSync(recursive: true);
        fixture.writeAsStringSync('%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Contents 4 0 R>>endobj\n4 0 obj<</Length 10>>stream\n(Hello)BT\n/F1 12 Tf\nET\nendstream\nendobj\nxref\n0 5\n0000000000 65535 f \n0000000009 00000 n \n0000000058 00000 n \n0000000115 00000 n \n0000000203 00000 n \ntrailer\n<</Size 5/Root 1 0 R>>\nstartxref\n296\n%%EOF');
      }
      final result = await service.parseAsText(fixture, 1);
      expect(result.markdown, isNotEmpty);
      expect(result.title, isNot('Untitled'));
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('returns markdown with raw-text header in Level 3 for impossible PDF', () async {
      final bad = File('test/fixtures/bad.pdf');
      bad.parent.createSync(recursive: true);
      bad.writeAsBytesSync([0xFF, 0xFE, 0x00, 0x01]);
      final result = await service.parseAsText(bad, 1);
      expect(result.sourceType, 'fallback_raw');
      expect(result.markdown, isNotEmpty);
      bad.deleteSync();
    });
  });
}
