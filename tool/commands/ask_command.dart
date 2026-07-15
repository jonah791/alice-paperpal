import 'dart:io' show stdout;

import 'package:paperpal/core/api/llm_provider.dart' show LLMProvider, LLMConfig, LLMProviderType;
import '../cli_helpers.dart' show println, bold, cyan, printError;
import '../cli_state.dart' show loadConfig, readPaperMarkdown;
import '../cli_context.dart' show buildPersonaPrompt, buildContextPrompt;

const _help = 'ask <paper-id> <question> [--stream]';

Future<void> askCommand(List<String> args) async {
  if (args.length < 2) {
    printError(_help);
    return;
  }

  final paperId = args[0];
  final isStream = args.contains('--stream');
  final question = args.where((a) => a != '--stream').skip(1).join(' ');

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

  final truncated = md.length > 12000
      ? '${md.substring(0, 12000)}\n\n[论文较长，已截断]'
      : md;

  final persona = buildPersonaPrompt();
  final context = buildContextPrompt();
  final systemPrompt = persona.isNotEmpty ? '$persona\n\n$context' : '你是一个论文阅读助手。根据论文内容回答用户问题。回答简洁、准确。';

  println('${cyan("Question")}: $question\n');
  println('${bold("Answer")}: ');

  if (isStream) {
    try {
      await for (final chunk in provider.chatStream([
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': '论文内容：\n\n$truncated\n\n---\n\n问题：$question'},
      ])) {
        stdout.write(chunk);
      }
      println('');
    } catch (e) {
      printError('Ask failed: $e');
    }
  } else {
    try {
      final answer = await provider.chat([
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': '论文内容：\n\n$truncated\n\n---\n\n问题：$question'},
      ]);
      println(answer);
    } catch (e) {
      printError('Ask failed: $e');
    }
  }
}
