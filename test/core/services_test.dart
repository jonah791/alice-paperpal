import 'package:flutter_test/flutter_test.dart';
import 'package:paperpal/core/services/export_service.dart';
import 'package:paperpal/core/services/parse_service.dart';
import 'package:paperpal/core/services/portrait_service.dart';
import 'package:paperpal/core/services/soul_service.dart';
import 'package:paperpal/core/models/paper.dart';

void main() {
  group('ExportService.generateBibtex', () {
    test('DOI key replaces dots and slashes', () {
      final p = Paper(id: '1', title: 'Deep Learning', authors: ['Hinton G'], year: 2023, doi: '10.1234/dl.2023');
      final b = ExportService.generateBibtex(p);
      expect(b, contains('@article{10_1234_dl_2023'));
      expect(b, contains('title={Deep Learning}'));
      expect(b, contains('year={2023}'));
    });

    test('title-based key when no DOI', () {
      final p = Paper(id: '1', title: 'A Novel Approach to ML', authors: ['Smith J'], year: 2024);
      final b = ExportService.generateBibtex(p);
      expect(b, contains('@article{A_Novel_Approach'));
      expect(b, contains('author={J, Smith}'));
    });

    test('single word author name', () {
      final p = Paper(id: '1', title: 'T', authors: ['Einstein'], year: 2024);
      expect(ExportService.generateBibtex(p), contains('author={Einstein}'));
    });

    test('empty authors becomes Anonymous', () {
      final p = Paper(id: '1', title: 'T', authors: [], year: 2024);
      final b = ExportService.generateBibtex(p);
      expect(b, contains('author={{Anonymous}}'));
    });

    test('multi-word author name last-name-first', () {
      final p = Paper(id: '1', title: 'T', authors: ['John A. Doe', 'Jane B. Smith'], year: 2024);
      expect(ExportService.generateBibtex(p), contains('author={Doe, John A. and Smith, Jane B.}'));
    });

    test('full BibTeX format', () {
      final p = Paper(id: '1', title: 'Test', authors: ['Author A'], year: 2024);
      final b = ExportService.generateBibtex(p);
      expect(b, startsWith('@article{'));
      expect(b, endsWith('}'));
      expect(b, contains('\n  title={Test},\n'));
      expect(b, contains('\n  author={A, Author},\n'));
    });
  });

  group('MergeService', () {
    test('empty list returns empty', () {
      final r = MergeService.merge([]);
      expect(r.markdown, '');
      expect(r.title, '');
    });

    test('single batch passes through', () {
      final r = MergeService.merge(['# X\n\nbody']);
      expect(r.markdown, '# X\n\nbody');
      expect(r.title, 'X');
    });

    test('multiple batches with separator', () {
      final r = MergeService.merge(['# A\n\na', '# B\n\nb']);
      expect(r.markdown, contains('<!-- batch-break -->'));
      expect(r.title, 'A');
    });

    test('title from first batch', () {
      final r = MergeService.merge(['# Main\n\nintro.', '## Sec\n\nbody.']);
      expect(r.title, 'Main');
    });

    test('no title returns empty', () {
      final r = MergeService.merge(['just text', 'more text']);
      expect(r.title, '');
    });

    test('three batches', () {
      final r = MergeService.merge(['# T1\na', '# T2\nb', '# T3\nc']);
      expect(r.markdown.split('<!-- batch-break -->'), hasLength(3));
      expect(r.title, 'T1');
    });
  });

  group('PortraitService', () {
    test('summarize empty portrait', () {
      expect(PortraitService().summarize(), '');
    });

    test('summarize merges summary into target map and returns merged content', () {
      final m = <String, dynamic>{};
      PortraitService().deepMerge(m, {'summary': 'Alice likes ML'});
      expect(m['summary'], 'Alice likes ML');
    });

    test('deepMerge simple top-level', () {
      final m = <String, dynamic>{'name': 'Alice', 'age': 25};
      PortraitService().deepMerge(m, {'age': 26, 'city': 'NYC'});
      expect(m['name'], 'Alice');
      expect(m['age'], 26);
      expect(m['city'], 'NYC');
    });

    test('deepMerge nested maps', () {
      final m = <String, dynamic>{
        'user': {'name': 'Bob', 'age': 30},
        'active': true,
      };
      PortraitService().deepMerge(m, {
        'user': {'age': 31, 'city': 'SF'},
      });
      expect((m['user'] as Map)['name'], 'Bob');
      expect((m['user'] as Map)['age'], 31);
      expect((m['user'] as Map)['city'], 'SF');
      expect(m['active'], true);
    });

    test('deepMerge scalar replaces with map', () {
      final m = <String, dynamic>{'key': 'old'};
      PortraitService().deepMerge(m, {'key': {'nested': 'v'}});
      expect(m['key'], {'nested': 'v'});
    });

    test('deepMerge empty source no-op', () {
      final m = <String, dynamic>{'a': 1};
      PortraitService().deepMerge(m, {});
      expect(m, {'a': 1});
    });

    test('deepMerge empty target gets source', () {
      final m = <String, dynamic>{};
      PortraitService().deepMerge(m, {'a': 1, 'b': {'c': 2}});
      expect(m['a'], 1);
      expect((m['b'] as Map)['c'], 2);
    });

    test('deepMerge three levels', () {
      final m = <String, dynamic>{
        'l1': {'l2': {'l3': 'old', 'keep': 'x'}},
      };
      PortraitService().deepMerge(m, {
        'l1': {'l2': {'l3': 'new', 'add': 'y'}},
      });
      final l2 = m['l1']['l2'] as Map;
      expect(l2['l3'], 'new');
      expect(l2['keep'], 'x');
      expect(l2['add'], 'y');
    });
  });

  group('SoulService', () {
    test('presets are structurally valid', () {
      final presets = SoulService.presetDefinitions;
      expect(presets.length, greaterThanOrEqualTo(1));
      for (final entry in presets.entries) {
        final d = entry.value;
        expect(d['id'], allOf(isA<String>(), isNotEmpty));
        expect(d['name'], allOf(isA<String>(), isNotEmpty));
        expect(d['description'], isA<String>());
        expect(d['traits'], isA<List>());
        expect(d['style'], isA<String>());
        expect(d['specialty'], isA<String>());
        expect(d['systemPrompt'], allOf(isA<String>(), isNotEmpty));
        expect(d['isBuiltin'], true);
        expect(d['isCustom'], false);
      }
    });

    test('each preset has non-empty speechPattern', () {
      for (final d in SoulService.presetDefinitions.values) {
        final sp = d['speechPattern'] as String?;
        expect(sp, isNotNull);
        expect(sp, isNotEmpty);
      }
    });

    test('metaSoulRules has minimum expected content', () {
      final rules = SoulService().metaSoulRules;
      expect(rules.length, greaterThan(50));
      expect(rules, contains('过往对话'));
      expect(rules, contains('不确定'));
    });
  });
}
