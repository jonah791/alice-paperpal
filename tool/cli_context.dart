import 'package:paperpal/core/models/soul.dart';
import 'cli_state.dart' show soulPresetDefinitions, loadMemories, loadPortrait, loadActiveSoulId;

const _metaSoulRules = '''
当你在回答中引用过往对话时，自然地融入，不要说"根据我们的对话历史"这种机械的话。
不确定时可以说"不太确定，我的理解是…"。
可以表达适度情绪。
如果发现之前说错了，自然地纠正。
''';

Soul? _findSoulById(String id) {
  for (final entry in soulPresetDefinitions.entries) {
    final s = Soul.fromJson(entry.value);
    if (s.id == id) return s;
  }
  return null;
}

String buildPersonaPrompt() {
  final activeId = loadActiveSoulId();
  final soul = activeId != null ? _findSoulById(activeId) : null;
  final defaultSoul = soul ?? Soul.fromJson(soulPresetDefinitions.values.first);

  final sb = StringBuffer();
  sb.writeln(defaultSoul.systemPrompt);
  if (defaultSoul.speechPattern != null) {
    sb.writeln('说话习惯：${defaultSoul.speechPattern}');
  }
  sb.writeln(_metaSoulRules);
  return sb.toString();
}

String buildContextPrompt() {
  final sb = StringBuffer();

  final portrait = loadPortrait();
  if (portrait.isNotEmpty) {
    sb.writeln('关于用户：');
    if (portrait.containsKey('summary')) {
      sb.writeln(portrait['summary']);
    }
    if (portrait.containsKey('interests')) {
      final interests = portrait['interests'] as Map?;
      if (interests != null && interests.isNotEmpty) {
        sb.writeln('用户关注领域：${interests.values.join('、')}');
      }
    }
    sb.writeln();
  }

  final memories = loadMemories();
  if (memories.isNotEmpty) {
    final recent = memories.reversed.take(10).toList();
    sb.writeln('我们的过往：');
    for (final m in recent) {
      sb.writeln('- ${m['summary']}');
    }
    sb.writeln();
  }

  return sb.toString();
}

String? getActiveSoulName() {
  final activeId = loadActiveSoulId();
  final soul = activeId != null ? _findSoulById(activeId) : null;
  return soul?.name;
}
