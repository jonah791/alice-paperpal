import 'package:flutter_test/flutter_test.dart';
import 'package:paperpal/core/services/translation_service.dart';
import 'package:paperpal/core/api/llm_provider.dart';

LLMProvider _dummyProvider() => LLMProvider(config: const LLMConfig(
  type: LLMProviderType.deepseek,
  apiKey: 'test',
));

void main() {
  group('TranslationService detectLanguage edge cases', () {
    test('mixed CJK + Japanese kana returns zh when Chinese dominates', () {
      final s = TranslationService(_dummyProvider());
      expect(s.detectLanguage('这是日本の論文です'), 'zh');
    });

    test('Japanese with some Latin characters returns ja', () {
      final s = TranslationService(_dummyProvider());
      expect(s.detectLanguage('これはtestですこれはtestですこれはtestです'), 'ja');
    });

    test('Korean with English abstract returns ko', () {
      final s = TranslationService(_dummyProvider());
      expect(s.detectLanguage('이 논문은 deep learning을 사용합니다'), 'ko');
    });

    test('text over 2000 chars is truncated at first 2000', () {
      final s = TranslationService(_dummyProvider());
      final long = '中' * 2500;
      expect(s.detectLanguage(long), 'zh');
    });

    test('mixed Cyrillic and Latin, Cyrillic above threshold', () {
      final s = TranslationService(_dummyProvider());
      expect(s.detectLanguage('Это русская статья с some English terms'), 'ru');
    });

    test('pure Chinese returns zh', () {
      final s = TranslationService(_dummyProvider());
      expect(s.detectLanguage('深度学习在自然语言处理中的应用研究'), 'zh');
    });

    test('punctuation-only with CJK character returns zh', () {
      final s = TranslationService(_dummyProvider());
      expect(s.detectLanguage('【】——！？，。中！？'), 'zh');
    });

    test('HTML with mostly English returns en', () {
      final s = TranslationService(_dummyProvider());
      expect(s.detectLanguage('<div class="header">Introduction</div>'), 'en');
    });
  });

  group('TranslationService needsTranslation edge cases', () {
    late TranslationService s;
    setUp(() => s = TranslationService(_dummyProvider()));

    test('mixed en with few zh chars returns true (not enough CJK ratio)', () {
      // 'Chinese 研究 English' → 2 CJK chars, 14 Latin chars → CJK ratio 2/16=12.5% < 30%
      // So it's detected as English → needsTranslation = true
      expect(s.needsTranslation('Chinese 研究 English'), true);
    });

    test('pure symbols returns true (en default)', () {
      const symbols = r'12345 !@#$%';
      expect(s.needsTranslation(symbols), true);
    });
  });

  group('TranslationService validateLatex', () {
    test('text without LaTeX passes through unchanged', () {
      final s = TranslationService(_dummyProvider());
      final result = s.validateLatex('Plain text without dollars');
      expect(result, 'Plain text without dollars');
    });

    test('text with even dollar-dollar pairs passes through', () {
      final s = TranslationService(_dummyProvider());
      const input = r'Equation $$E=mc^2$$ here';
      final result = s.validateLatex(input);
      expect(result, input);
    });

    test('text with multiple even dollar-dollar pairs passes through', () {
      final s = TranslationService(_dummyProvider());
      const input = r'$$a$$ and $$b$$ and $$c$$';
      final result = s.validateLatex(input);
      expect(result, input);
    });

    test('text with odd dollar-dollar count is returned unchanged', () {
      final s = TranslationService(_dummyProvider());
      const input = r'Broken $$E=mc^2 has one dollar';
      final result = s.validateLatex(input);
      expect(result, contains(r'$$'));
    });

    test('no dollar-dollar signs passes through', () {
      final s = TranslationService(_dummyProvider());
      final result = s.validateLatex('No math here');
      expect(result, 'No math here');
    });

    test('text with nested LaTeX delimiters', () {
      final s = TranslationService(_dummyProvider());
      const input = r'Formula $$\alpha + \beta$$ and more $$\gamma$$';
      final result = s.validateLatex(input);
      expect(result, input);
    });
  });

  group('TranslationService detectLanguage CJK boundary', () {
    test('Chinese character boundary 0x4E00-0x9FFF', () {
      final s = TranslationService(_dummyProvider());
      expect(s.detectLanguage('一一一一一一一'), 'zh');
    });

    test('Hiragana boundary 0x3040-0x309F', () {
      final s = TranslationService(_dummyProvider());
      expect(s.detectLanguage('あいうえおあいうえおあいう'), 'ja');
    });

    test('Katakana boundary 0x30A0-0x30FF', () {
      final s = TranslationService(_dummyProvider());
      expect(s.detectLanguage('アイウエオアイウエオ'), 'ja');
    });

    test('Korean syllabic boundary 0xAC00-0xD7AF', () {
      final s = TranslationService(_dummyProvider());
      expect(s.detectLanguage('가나다라마바사가나다'), 'ko');
    });
  });
}
