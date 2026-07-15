import 'package:paperpal/core/api/llm_provider.dart' show LLMProvider, LLMConfig, LLMProviderType;
import 'package:paperpal/core/services/translation_service.dart' show TranslationService;
import '../cli_helpers.dart' show println, cyan, printError, printSuccess;
import '../cli_state.dart' show loadConfig, readPaperMarkdown, savePaperTranslation;

const _help = 'translate <paper-id> [--target lang]';

Future<void> translateCommand(List<String> args) async {
  if (args.isEmpty) {
    printError(_help);
    return;
  }

  final paperId = args[0];
  final targetIdx = args.indexOf('--target');
  final target = (targetIdx >= 0 && targetIdx + 1 < args.length)
      ? args[targetIdx + 1]
      : '中文';

  final md = readPaperMarkdown(paperId);
  if (md == null) {
    printError('Paper not found or not parsed: $paperId');
    return;
  }

  final cfg = loadConfig();
  final apiKey = cfg['llm-api-key'] as String?;
  if (apiKey == null || apiKey.isEmpty) {
    printError('LLM API key not set. Run: config set llm-api-key <key>');
    return;
  }

  final provider = LLMProvider(config: LLMConfig(
    type: LLMProviderType.deepseek,
    apiKey: apiKey,
    apiBase: cfg['llm-api-base'] as String? ?? 'https://api.deepseek.com',
    model: cfg['llm-model'] as String? ?? 'deepseek-v4-flash',
  ));

  final translationService = TranslationService(provider);

  // Check language first
  final detected = translationService.detectLanguage(md);

  if (detected == 'zh' && target == '中文') {
    println('${cyan("Source")}: Chinese — no translation needed.');
    println('');
    println(md.substring(0, md.length.clamp(0, 2000)));
    return;
  }

  println('${cyan("Source")}: $detected → ${cyan("Target")}: $target');
  println('${cyan("Translating")} (${md.length} chars)...\n');

  try {
    // Use TranslationService.translate which includes validateLatex
    final result = await translationService.translate(md, target: target);

    if (result.length > 2000) {
      println(result.substring(0, 2000));
      println('\n... [${result.length} chars total, truncated]');
    } else {
      println(result);
    }

    // Cache
    savePaperTranslation(paperId, result);
    printSuccess('Translation cached.');
  } catch (e) {
    printError('Translate failed: $e');
  }
}
