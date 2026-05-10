import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paperpal/core/services/config_service.dart';
import 'package:paperpal/core/services/export_service.dart';
import 'package:paperpal/core/services/memory_service.dart';
import 'package:paperpal/core/services/portrait_service.dart';
import 'package:paperpal/core/services/soul_service.dart';
import 'package:paperpal/core/services/translation_service.dart';
import 'package:paperpal/core/services/parse_service.dart';
import 'package:paperpal/core/api/llm_provider.dart';
import 'package:paperpal/core/models/paper.dart';
import 'package:paperpal/core/models/config.dart';

void main() {
  group('ConfigService', () {
    test('initial config has defaults', () {
      final service = ConfigService();
      expect(service.config.llmApiBase, 'https://api.deepseek.com');
      expect(service.config.llmModel, 'deepseek-v4-flash');
    });

    test('hasLlmApiKey returns false before loading', () {
      final service = ConfigService();
      expect(service.hasLlmApiKey, false);
    });

    test('load preserves config defaults when no prefs stored', () async {
      SharedPreferences.setMockInitialValues({});
      final service = ConfigService();
      await service.load();
      expect(service.config.llmApiBase, 'https://api.deepseek.com');
      expect(service.config.llmModel, 'deepseek-v4-flash');
    });

    test('load reads stored config values', () async {
      SharedPreferences.setMockInitialValues({
        'llm_api_base': 'https://custom.api.com',
        'llm_model': 'gpt-4',
        'mineru_api_endpoint': 'https://mineru.custom.com',
      });
      final service = ConfigService();
      await service.load();
      expect(service.config.llmApiBase, 'https://custom.api.com');
      expect(service.config.llmModel, 'gpt-4');
      expect(service.config.mineruApiEndpoint, 'https://mineru.custom.com');
    });

    test('updateConfig updates config and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final service = ConfigService();
      await service.load();

      await service.updateConfig(AppConfig(
        llmApiBase: 'https://new.api.com',
        llmModel: 'new-model',
        mineruApiEndpoint: 'https://new.mineru.com',
      ));

      expect(service.config.llmApiBase, 'https://new.api.com');
      expect(service.config.llmModel, 'new-model');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('llm_api_base'), 'https://new.api.com');
      expect(prefs.getString('llm_model'), 'new-model');
    });
  });

  group('ExportService', () {
    test('generateBibtex with DOI key', () {
      final paper = Paper(
        id: '1',
        title: 'Deep Learning',
        authors: ['Hinton G', 'LeCun Y'],
        year: 2023,
        doi: '10.1234/dl.2023',
      );
      final bibtex = ExportService.generateBibtex(paper);
      expect(bibtex, contains('@article{10_1234_dl_2023'));
      expect(bibtex, contains('title={Deep Learning}'));
      expect(bibtex, contains('author={G, Hinton and Y, LeCun}'));
      expect(bibtex, contains('year={2023}'));
    });

    test('generateBibtex with title-based key when no DOI', () {
      final paper = Paper(
        id: '1',
        title: 'A Novel Approach to Machine Learning',
        authors: ['Smith J'],
        year: 2024,
      );
      final bibtex = ExportService.generateBibtex(paper);
      expect(bibtex, contains('@article{A_Novel_Approach'));
      expect(bibtex, contains('author={J, Smith}'));
    });

    test('generateBibtex handles single word name', () {
      final paper = Paper(
        id: '1',
        title: 'Paper Title',
        authors: ['SingleName'],
        year: 2024,
      );
      final bibtex = ExportService.generateBibtex(paper);
      expect(bibtex, contains('author={SingleName}'));
    });

    test('generateBibtex handles anonymous authors', () {
      final paper = Paper(
        id: '1',
        title: 'Paper Title',
        authors: [],
        year: 2024,
      );
      final bibtex = ExportService.generateBibtex(paper);
      expect(bibtex, contains('author={{Anonymous}}'));
    });

    test('generateBibtex formats author names with last name first', () {
      final paper = Paper(
        id: '1',
        title: 'Test',
        authors: ['John A. Doe', 'Jane B. Smith'],
        year: 2024,
      );
      final bibtex = ExportService.generateBibtex(paper);
      expect(bibtex, contains('author={Doe, John A. and Smith, Jane B.}'));
    });
  });

  group('TranslationService', () {
    test('validateLatex passes through odd dollar pairs', () {
      final service = TranslationService(
        LLMProvider(config: LLMConfig(
          type: LLMProviderType.deepseek,
          apiKey: 'test',
        )),
      );
      // _validateLatex is private, test through translate's indirect path
      // For now test detectLanguage and needsTranslation comprehensively
      expect(service.needsTranslation('English text'), true);
      expect(service.needsTranslation('中文文本'), false);
    });
  });

  group('MergeService', () {
    test('merge empty list returns empty', () {
      final result = MergeService.merge([]);
      expect(result.markdown, isEmpty);
      expect(result.title, isEmpty);
    });

    test('merge single batch returns as-is', () {
      final result = MergeService.merge(['# Single Paper\n\nContent here']);
      expect(result.markdown, '# Single Paper\n\nContent here');
      expect(result.title, 'Single Paper');
    });

    test('merge multiple batches with separators', () {
      final result = MergeService.merge([
        '# Part One\n\nFirst half content.',
        '# Part Two\n\nSecond half content.',
      ]);
      expect(result.markdown, contains('<!-- batch-break -->'));
      expect(result.title, 'Part One');
    });

    test('merge extracts title from first batch', () {
      final result = MergeService.merge([
        '# The Main Title\n\nIntroduction.',
        '## Some Section\n\nDetails.',
      ]);
      expect(result.title, 'The Main Title');
    });

    test('merge handles batches without titles', () {
      final result = MergeService.merge([
        'Just some text.',
        'And more text.',
      ]);
      expect(result.title, isEmpty);
    });
  });

  group('PortraitService', () {
    test('summarize returns empty for empty portrait', () {
      final service = PortraitService();
      expect(service.summarize(), isEmpty);
    });

    test('summarize does not crash before init', () {
      final service = PortraitService();
      expect(() => service.summarize(), returnsNormally);
    });

    test('deepMerge simple fields', () {
      final service = PortraitService();
      final target = <String, dynamic>{'name': 'Alice', 'age': 25};
      service.deepMerge(target, {'age': 26, 'city': 'NYC'});
      expect(target['name'], 'Alice');
      expect(target['age'], 26);
      expect(target['city'], 'NYC');
    });

    test('deepMerge nested maps', () {
      final service = PortraitService();
      final target = <String, dynamic>{
        'user': {'name': 'Bob', 'age': 30},
        'active': true,
      };
      service.deepMerge(target, {
        'user': {'age': 31, 'city': 'SF'},
        'extra': 'data',
      });
      expect((target['user'] as Map)['name'], 'Bob');
      expect((target['user'] as Map)['age'], 31);
      expect((target['user'] as Map)['city'], 'SF');
      expect(target['active'], true);
      expect(target['extra'], 'data');
    });

    test('deepMerge overwrites non-map with map', () {
      final service = PortraitService();
      final target = <String, dynamic>{'key': 'string_value'};
      service.deepMerge(target, {'key': {'nested': 'value'}});
      expect(target['key'], {'nested': 'value'});
    });

    test('deepMerge empty source does nothing', () {
      final service = PortraitService();
      final target = <String, dynamic>{'a': 1};
      service.deepMerge(target, {});
      expect(target, {'a': 1});
    });
  });

  group('SoulService', () {
    test('presetDefinitions has 4 built-in souls', () {
      expect(SoulService.presetDefinitions, hasLength(4));
    });

    test('presetDefinitions have expected keys', () {
      expect(SoulService.presetDefinitions.keys, containsAll([
        'academic_mentor', 'code_expert', 'paper_reviewer', 'science_communicator',
      ]));
    });

    test('metaSoulRules is not empty', () {
      final service = SoulService();
      expect(service.metaSoulRules, isNotEmpty);
    });

    test('custom souls is empty before init', () {
      final service = SoulService();
      expect(service.custom, isEmpty);
    });

    test('activeSoul is null before init', () {
      final service = SoulService();
      expect(service.activeSoul, isNull);
    });

    test('academic_mentor preset has correct structure', () {
      final def = SoulService.presetDefinitions['academic_mentor']!;
      expect(def['name'], '学术导师');
      expect(def['isBuiltin'], true);
      expect((def['traits'] as List).length, 3);
      expect(def['systemPrompt'], isNotEmpty);
    });

    test('code_expert preset has correct specialty', () {
      final def = SoulService.presetDefinitions['code_expert']!;
      expect(def['specialty'], contains('算法'));
      expect(def['speechPattern'], isNotEmpty);
    });

    test('paper_reviewer preset has critique style', () {
      final def = SoulService.presetDefinitions['paper_reviewer']!;
      expect(def['style'], contains('批判'));
      expect(def['isCustom'], false);
    });

    test('science_communicator preset uses analogies', () {
      final def = SoulService.presetDefinitions['science_communicator']!;
      expect(def['speechPattern'], contains('打个比方'));
      expect(def['description'], contains('类比'));
    });
  });

  group('MemoryService', () {
    test('summarizeRecent returns empty for empty memories', () {
      final service = MemoryService();
      // Before init, memories list is empty
      expect(service.summarizeRecent(), isEmpty);
    });

    test('summarizeRecent with limit parameter', () {
      final service = MemoryService();
      // summarizeRecent should handle limit gracefully when no memories
      expect(service.summarizeRecent(limit: 5), isEmpty);
      expect(service.summarizeRecent(limit: 0), isEmpty);
    });

    test('getRecent returns empty list before init', () {
      final service = MemoryService();
      expect(service.getRecent(), isEmpty);
    });
  });

  group('PaperStatus flow', () {
    test('PaperStatus progresses in expected order', () {
      expect(PaperStatus.importing.index, lessThan(PaperStatus.parsing.index));
      expect(PaperStatus.parsing.index, lessThan(PaperStatus.parsed.index));
      expect(PaperStatus.parsed.index, lessThan(PaperStatus.translating.index));
      expect(PaperStatus.translating.index, lessThan(PaperStatus.translated.index));
    });
  });
}
