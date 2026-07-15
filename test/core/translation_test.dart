import 'package:flutter_test/flutter_test.dart';
import 'package:paperpal/core/services/translation_service.dart';
import 'package:paperpal/core/api/llm_provider.dart';

LLMProvider _dummyProvider() => LLMProvider(config: const LLMConfig(
  type: LLMProviderType.deepseek,
  apiKey: 'test',
));

void main() {
  group('detectLanguage', () {
    test('Chinese', () {
      final s = TranslationService(_dummyProvider());
      expect(s.detectLanguage('这是一篇中文论文'), 'zh');
      expect(s.detectLanguage('研究结果表明该方法有效'), 'zh');
    });

    test('English', () {
      final s = TranslationService(_dummyProvider());
      expect(s.detectLanguage('This is an English paper'), 'en');
    });

    test('Japanese (kana only)', () {
      final s = TranslationService(_dummyProvider());
      expect(s.detectLanguage('これはテストです'), 'ja');
    });

    test('Korean', () {
      final s = TranslationService(_dummyProvider());
      expect(s.detectLanguage('이것은 한국어 논문입니다'), 'ko');
    });

    test('Russian', () {
      final s = TranslationService(_dummyProvider());
      expect(s.detectLanguage('Это русская статья'), 'ru');
    });

    test('empty text returns en', () {
      final s = TranslationService(_dummyProvider());
      expect(s.detectLanguage(''), 'en');
    });

    test('only CJK mixed with numbers returns zh', () {
      final s = TranslationService(_dummyProvider());
      expect(s.detectLanguage('第1章 引言'), 'zh');
    });

    test('only symbols and numbers returns en', () {
      final s = TranslationService(_dummyProvider());
      expect(s.detectLanguage(r'12345!@#$%'), 'en');
    });

    test('mostly latin with few CJK returns en', () {
      final s = TranslationService(_dummyProvider());
      expect(s.detectLanguage('This paper uses 注意力 mechanism'), 'en');
    });
  });

  group('needsTranslation', () {
    late TranslationService s;
    setUp(() => s = TranslationService(_dummyProvider()));

    test('Chinese returns false', () {
      expect(s.needsTranslation('中文论文'), false);
    });

    test('English returns true', () {
      expect(s.needsTranslation('English paper'), true);
    });

    test('Japanese returns true', () {
      expect(s.needsTranslation('これはテストです'), true);
    });

    test('Korean returns true', () {
      expect(s.needsTranslation('한국어 논문'), true);
    });

    test('Russian returns true', () {
      expect(s.needsTranslation('Русская статья'), true);
    });

    test('empty returns true', () {
      expect(s.needsTranslation(''), true);
    });
  });
}
