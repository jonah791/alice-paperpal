import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paperpal/core/services/config_service.dart';
import 'package:paperpal/core/models/config.dart';

void main() {
  group('ConfigService', () {
    test('default config before load', () {
      final s = ConfigService();
      expect(s.config.llmApiBase, 'https://api.deepseek.com');
      expect(s.config.mineruModelVersion, 'vlm');
    });

    test('hasLlmApiKey false before load', () {
      expect(ConfigService().hasLlmApiKey, false);
    });

    test('load empty prefs uses defaults', () async {
      SharedPreferences.setMockInitialValues({});
      final s = ConfigService();
      await s.load();
      expect(s.config.llmApiBase, 'https://api.deepseek.com');
      expect(s.config.llmModel, 'deepseek-v4-flash');
      expect(s.config.mineruModelVersion, 'vlm');
      expect(s.config.enableFormula, true);
      expect(s.config.enableTable, true);
    });

    test('load reads stored values', () async {
      SharedPreferences.setMockInitialValues({
        'llm_api_base': 'https://custom.api.com',
        'llm_model': 'gpt-4',
        'mineru_model_version': 'pipeline',
        'enable_formula': false,
        'enable_table': true,
      });
      final s = ConfigService();
      await s.load();
      expect(s.config.llmApiBase, 'https://custom.api.com');
      expect(s.config.llmModel, 'gpt-4');
      expect(s.config.mineruModelVersion, 'pipeline');
      expect(s.config.enableFormula, false);
      expect(s.config.enableTable, true);
    });

    test('updateConfig persists to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final s = ConfigService();
      await s.load();
      await s.updateConfig(AppConfig(
        llmApiBase: 'https://new.api.com',
        mineruModelVersion: 'MinerU-HTML',
        enableFormula: false,
      ));
      expect(s.config.llmApiBase, 'https://new.api.com');
      expect(s.config.mineruModelVersion, 'MinerU-HTML');
      final p = await SharedPreferences.getInstance();
      expect(p.getString('llm_api_base'), 'https://new.api.com');
      expect(p.getString('mineru_model_version'), 'MinerU-HTML');
      expect(p.getBool('enable_formula'), false);
    });

    test('saveLlmApiKey and readLlmApiKey round-trip', () async {
      SharedPreferences.setMockInitialValues({});
      final s = ConfigService();
      await s.load();
      await s.saveLlmApiKey('sk-test-key-12345');
      final read = await s.readLlmApiKey();
      expect(read, 'sk-test-key-12345');
    });

    test('saveMineruApiKey and readMineruApiKey round-trip', () async {
      SharedPreferences.setMockInitialValues({});
      final s = ConfigService();
      await s.load();
      await s.saveMineruApiKey('mn-test-key');
      final read = await s.readMineruApiKey();
      expect(read, 'mn-test-key');
    });

    test('hasLlmApiKey true after save', () async {
      SharedPreferences.setMockInitialValues({});
      final s = ConfigService();
      await s.load();
      await s.saveLlmApiKey('k');
      expect(s.hasLlmApiKey, true);
    });

    test('readLlmApiKey returns null when empty', () async {
      SharedPreferences.setMockInitialValues({});
      final s = ConfigService();
      await s.load();
      expect(await s.readLlmApiKey(), isNull);
    });
  });
}
