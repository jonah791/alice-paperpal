import 'package:paperpal/core/api/llm_provider.dart' show LLMProvider, LLMConfig, LLMProviderType;
import '../cli_helpers.dart' show println, cyan, printError;
import '../cli_state.dart' show loadConfig, readPaperMarkdown;
import '../cli_context.dart' show buildPersonaPrompt;

const _help = 'summarize <paper-id>';

Future<void> summarizeCommand(List<String> args) async {
  if (args.isEmpty) {
    printError(_help);
    return;
  }

  final paperId = args[0];
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

  final persona = buildPersonaPrompt();

  final truncated = md.length > 12000 ? md.substring(0, 12000) : md;

  println('${cyan("Generating summary")}...\n');

  try {
    // Use a simple prompt that works with the endpoint (avoids markdown-style headers)
    final systemPrompt = persona.isNotEmpty
        ? '$persona\n\n你是一个论文分析助手。分析以下论文，用简洁的语言输出：一句话总结、研究目标、方法、主要结果、结论。'
        : '你是一个论文分析助手。分析以下论文，用简洁的语言输出：一句话总结、研究目标、方法、主要结果、结论。';

    final answer = await provider.chat([
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': '论文内容：\n\n$truncated'},
    ]);
    println(answer);
  } catch (e) {
    printError('Summarize failed: $e');
  }
}
