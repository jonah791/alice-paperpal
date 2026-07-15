import 'package:flutter_test/flutter_test.dart';
import 'package:paperpal/core/services/export_service.dart';
import 'package:paperpal/core/models/paper.dart';

void main() {
  group('ExportService.generateBibtex extended', () {
    test('multi-word author with comma is handled', () {
      const p = Paper(id: '1', title: 'T', authors: ['Smith, John A.'], year: 2024);
      final b = ExportService.generateBibtex(p);
      // "Smith, John A." split by whitespace = ['Smith,', 'John', 'A.']
      // parts.length >= 2, last = 'A.', rest = ['Smith,', 'John'] joined = 'Smith, John'
      expect(b, contains('author={A., Smith, John}'));
    });

    test('doi with only dots produces key', () {
      const p = Paper(id: '1', title: 'T', authors: ['A'], year: 2024, doi: '10.1145.12345');
      final b = ExportService.generateBibtex(p);
      expect(b, contains('@article{10_1145_12345'));
    });

    test('doi with only slashes produces key', () {
      const p = Paper(id: '1', title: 'T', authors: ['A'], year: 2024, doi: '10/1145/12345');
      final b = ExportService.generateBibtex(p);
      expect(b, contains('@article{10_1145_12345'));
    });

    test('doi with mixed separators produces key', () {
      const p = Paper(id: '1', title: 'T', authors: ['A'], year: 2024, doi: '10.1234/dl.2023.42');
      final b = ExportService.generateBibtex(p);
      expect(b, contains('@article{10_1234_dl_2023_42'));
    });

    test('title key uses first 3 words', () {
      const p = Paper(id: '1', title: 'A Novel Approach to Deep Learning', authors: ['A'], year: 2024);
      final b = ExportService.generateBibtex(p);
      expect(b, contains('@article{A_Novel_Approach'));
    });

    test('title key with short title uses all words', () {
      const p = Paper(id: '1', title: 'Hello', authors: ['A'], year: 2024);
      final b = ExportService.generateBibtex(p);
      expect(b, contains('@article{Hello'));
    });

    test('multi-author BibTeX format all last-name-first', () {
      const p = Paper(id: '1', title: 'T', authors: ['Alice Bob', 'Charlie Doe'], year: 2024);
      final b = ExportService.generateBibtex(p);
      expect(b, contains('author={Bob, Alice and Doe, Charlie}'));
    });

    test('single author multi-word last name', () {
      const p = Paper(id: '1', title: 'T', authors: ['Geoffrey Everest Hinton'], year: 2024);
      final b = ExportService.generateBibtex(p);
      expect(b, contains('author={Hinton, Geoffrey Everest}'));
    });

    test('single-word authors retain original spacing', () {
      const p = Paper(id: '1', title: 'T', authors: ['  Alice  ', '  Bob  '], year: 2024);
      final b = ExportService.generateBibtex(p);
      // Single-word names return 'a' directly (not trimmed)
      expect(b, contains('author={  Alice   and   Bob  }'));
    });

    test('year 0 produces year={0}', () {
      const p = Paper(id: '1', title: 'T', authors: ['A'], year: 0);
      final b = ExportService.generateBibtex(p);
      expect(b, contains('year={0}'));
    });

    test('title with LaTeX braces passes through', () {
      const p = Paper(id: '1', title: r'Analysis of {BERT} Models', authors: ['A'], year: 2024);
      final b = ExportService.generateBibtex(p);
      expect(b, contains(r'title={Analysis of {BERT} Models}'));
    });

    test('full BibTeX structure verification', () {
      const p = Paper(id: '1', title: 'Hello World', authors: ['Jane Smith'], year: 2023, doi: '10.0/test.1');
      final b = ExportService.generateBibtex(p);
      expect(b, startsWith('@article{'));
      expect(b, endsWith('\n}'));
      expect(b.contains('title='), true);
      expect(b.contains('author='), true);
      expect(b.contains('year='), true);
    });
  });
}
