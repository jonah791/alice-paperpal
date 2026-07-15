import 'package:flutter_test/flutter_test.dart';
import 'package:paperpal/core/services/portrait_service.dart';
import 'package:paperpal/core/services/soul_service.dart';
import 'package:paperpal/core/models/paper.dart';
import 'package:paperpal/core/services/export_service.dart';

void main() {
  group('PortraitService.deepMerge extended', () {
    late PortraitService s;
    setUp(() => s = PortraitService());

    test('deepMerge with nested map overwrites leaf values', () {
      final m = <String, dynamic>{
        'user': {'name': 'Bob', 'prefs': {'theme': 'light'}},
      };
      s.deepMerge(m, {
        'user': {'prefs': {'theme': 'dark'}},
      });
      expect((m['user']['prefs'] as Map)['theme'], 'dark');
    });

    test('deepMerge adds new nested keys while preserving existing siblings', () {
      final m = <String, dynamic>{
        'user': {'name': 'Bob', 'age': 30},
      };
      s.deepMerge(m, {
        'user': {'city': 'NYC'},
      });
      expect(m['user']['name'], 'Bob');
      expect(m['user']['age'], 30);
      expect(m['user']['city'], 'NYC');
    });

    test('deepMerge replaces scalar with list', () {
      final m = <String, dynamic>{'tags': 'ML'};
      s.deepMerge(m, {'tags': ['ML', 'AI']});
      expect(m['tags'], ['ML', 'AI']);
    });

    test('deepMerge replaces list with scalar', () {
      final m = <String, dynamic>{'tags': ['ML', 'AI']};
      s.deepMerge(m, {'tags': 'DL'});
      expect(m['tags'], 'DL');
    });

    test('deepMerge handles mixed types in one merge', () {
      final m = <String, dynamic>{
        'name': 'Alice',
        'count': 5,
        'nested': {'a': 1, 'b': 2},
      };
      s.deepMerge(m, {
        'count': 10,
        'nested': {'b': 20, 'c': 30},
        'newKey': true,
      });
      expect(m['name'], 'Alice');
      expect(m['count'], 10);
      expect(m['newKey'], true);
      expect(m['nested']['a'], 1);
      expect(m['nested']['b'], 20);
      expect(m['nested']['c'], 30);
    });

    test('deepMerge deeply nested map with new branches', () {
      final m = <String, dynamic>{
        'level1': {
          'level2': {
            'level3': {'key': 'old'},
          },
        },
      };
      s.deepMerge(m, {
        'level1': {
          'level2': {
            'level3': {'new_key': 'value'},
          },
        },
      });
      final l3 = m['level1']['level2']['level3'] as Map;
      expect(l3['key'], 'old');
      expect(l3['new_key'], 'value');
    });
  });

  group('SoulService presetDefinitions extended', () {
    test('all presets have required fields', () {
      final required = ['id', 'name', 'description', 'traits', 'style', 'specialty', 'systemPrompt'];
      for (final entry in SoulService.presetDefinitions.entries) {
        final soul = entry.value;
        for (final key in required) {
          expect(soul.containsKey(key), true, reason: '${entry.key} missing $key');
        }
        expect(soul['isBuiltin'], true, reason: '${entry.key} not builtin');
        expect(soul['isCustom'], false, reason: '${entry.key} should not be custom');
      }
    });

    test('all presets have non-empty systemPrompt', () {
      for (final entry in SoulService.presetDefinitions.entries) {
        expect(
          entry.value['systemPrompt'] as String,
          isNotEmpty,
          reason: '${entry.key} has empty systemPrompt',
        );
      }
    });

    test('all presets have non-empty name', () {
      for (final entry in SoulService.presetDefinitions.entries) {
        expect(entry.value['name'], isNotEmpty, reason: '${entry.key} has empty name');
      }
    });

    test('academic_mentor has 3 traits', () {
      final traits = SoulService.presetDefinitions['academic_mentor']!['traits'] as List;
      expect(traits, hasLength(3));
    });

    test('code_expert has specific specialty', () {
      final d = SoulService.presetDefinitions['code_expert']!;
      expect(d['specialty'] as String, contains('实现'));
    });
  });

  group('ExportService.generateBibtex title-based key', () {
    test('title with single character produces valid key', () {
      const p = Paper(id: '1', title: 'X', authors: ['A'], year: 2024);
      final b = ExportService.generateBibtex(p);
      expect(b, contains('@article{X'));
    });

    test('title with two words produces two-word key', () {
      const p = Paper(id: '1', title: 'Hello World', authors: ['A'], year: 2024);
      final b = ExportService.generateBibtex(p);
      expect(b, contains('@article{Hello_World'));
    });

    test('title with 5 words limits to 3 words', () {
      const p = Paper(id: '1', title: 'One Two Three Four Five', authors: ['A'], year: 2024);
      final b = ExportService.generateBibtex(p);
      expect(b, contains('@article{One_Two_Three'));
    });
  });

  group('PortraitService.summarize', () {
    test('summarize returns empty when portrait is empty', () {
      final s = PortraitService();
      expect(s.summarize(), '');
    });
  });
}
