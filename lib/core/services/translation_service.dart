import 'package:logging/logging.dart';
import '../api/llm_provider.dart';

final _log = Logger('TranslationService');

class TranslationService {
  final LLMProvider _llm;

  TranslationService(this._llm);

  String detectLanguage(String text) {
    if (text.isEmpty) return 'en';

    var chineseChars = 0;
    var japaneseChars = 0;
    var koreanChars = 0;
    var latinChars = 0;
    var cyrillicChars = 0;

    for (var i = 0; i < text.length && i < 2000; i++) {
      final code = text.codeUnitAt(i);
      if (code >= 0x4E00 && code <= 0x9FFF) chineseChars++;
      if (code >= 0x3040 && code <= 0x30FF) japaneseChars++;
      if (code >= 0xAC00 && code <= 0xD7AF) koreanChars++;
      if ((code >= 0x0041 && code <= 0x005A) ||
          (code >= 0x0061 && code <= 0x007A)) latinChars++;
      if ((code >= 0x0400 && code <= 0x04FF) ||
          (code >= 0x0500 && code <= 0x052F)) cyrillicChars++;
    }

    final total = chineseChars + japaneseChars + koreanChars + latinChars + cyrillicChars;
    if (total == 0) return 'en';

    final chineseRatio = chineseChars / total;
    final japaneseRatio = japaneseChars / total;
    final koreanRatio = koreanChars / total;
    final cyrillicRatio = cyrillicChars / total;

    if (chineseRatio > 0.3) return 'zh';
    if (japaneseRatio > 0.3) return 'ja';
    if (koreanRatio > 0.3) return 'ko';
    if (cyrillicRatio > 0.1) return 'ru';
    return 'en';
  }

  bool needsTranslation(String text) {
    final lang = detectLanguage(text);
    return lang != 'zh';
  }

  Future<String> translate(String markdown, {String target = '中文'}) async {
    _log.info('translate: starting, target=$target, ${markdown.length} chars');
    final result = await _llm.translate(markdown, target: target);

    final repaired = validateLatex(result);
    if (repaired != result) {
      _log.info('translate: LaTeX validation fixed issues');
    }

    _log.info('translate: completed, ${result.length} chars');
    return repaired;
  }

  String validateLatex(String text) {
    final result = text;

    final dollarPairs = RegExp(r'\$\$').allMatches(result).length;
    if (dollarPairs.isOdd) {
      _log.warning('validateLatex: odd number of double-dollar signs found');
    }

    return result;
  }
}
