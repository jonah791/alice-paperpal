import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import '../api/llm_provider.dart';

final _log = Logger('PortraitService');

class PortraitService {
  late final String _filePath;
  Map<String, dynamic> _portrait = {};

  Future<void> init() async {
    final dir = await getApplicationSupportDirectory();
    _filePath = '${dir.path}/portrait.json';
    await _load();
    _log.info('init');
  }

  Future<void> _load() async {
    final file = File(_filePath);
    if (!await file.exists()) return;
    try {
      final json = await file.readAsString();
      _portrait = jsonDecode(json) as Map<String, dynamic>;
    } catch (e) {
      _log.warning('load failed: $e');
    }
  }

  Future<void> _save() async {
    await File(_filePath).writeAsString(jsonEncode(_portrait));
  }

  String summarize() {
    if (_portrait.isEmpty) return '';
    final sb = StringBuffer();

    if (_portrait.containsKey('summary')) {
      sb.writeln(_portrait['summary']);
    }
    if (_portrait.containsKey('interests')) {
      final interests = _portrait['interests'] as Map?;
      if (interests != null && interests.isNotEmpty) {
        sb.writeln('用户关注领域：${interests.values.join('、')}');
      }
    }
    return sb.toString().trim();
  }

  Future<void> updateFromConversation(
    String userMessage,
    String assistantResponse,
    LLMProvider llm,
  ) async {
    try {
      final currentPortraitJson = _portrait.isEmpty ? '{}' : jsonEncode(_portrait);
      final prompt = '''
根据以下对话，判断是否需要更新用户画像。

用户说：$userMessage
AI 说：$assistantResponse

当前用户画像：$currentPortraitJson

如果不需要更新，只输出 null。
如果需要更新，输出 JSON 对象（只包含要增加或修改的字段）。
字段可以根据对话自由扩展。

只输出 null 或 JSON，不要其他内容。
''';

      final response = await llm.chat([
        {'role': 'system', 'content': '你是一个用户画像分析师。根据对话判断是否需要更新用户画像。只输出 null 或 JSON。'},
        {'role': 'user', 'content': prompt},
      ]);

      final trimmed = response.trim();
      if (trimmed == 'null' || trimmed.isEmpty) return;

      final update = jsonDecode(trimmed) as Map<String, dynamic>;
      if (update.isEmpty) return;

      deepMerge(_portrait, update);
      _portrait['last_updated'] = DateTime.now().toIso8601String();
      await _save();
      _log.info('updateFromConversation: portrait updated');
    } catch (e) {
      _log.warning('updateFromConversation failed: $e');
    }
  }

  void deepMerge(Map<String, dynamic> target, Map<String, dynamic> source) {
    for (final key in source.keys) {
      if (source[key] is Map<String, dynamic> && target[key] is Map<String, dynamic>) {
        deepMerge(target[key] as Map<String, dynamic>, source[key] as Map<String, dynamic>);
      } else {
        target[key] = source[key];
      }
    }
  }
}
