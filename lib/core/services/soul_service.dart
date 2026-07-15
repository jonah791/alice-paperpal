import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/soul.dart';
import '../models/soul_presets.dart';
import '../interfaces/services.dart';

final _log = Logger('SoulService');
const _uuid = Uuid();

class SoulService implements ISoulService {
  late final String _soulsDir;
  late final String _activePath;
  Soul? _activeSoul;
  List<Soul> _presets = [];
  List<Soul> _custom = [];

  static const _metaSoul = '''
当你在回答中引用过往对话时，自然地融入，不要说"根据我们的对话历史"这种机械的话。
不确定时可以说"不太确定，我的理解是…"。
可以表达适度情绪。
如果发现之前说错了，自然地纠正。
''';

  @override
  String get metaSoulRules => _metaSoul;
  @override
  Soul? get activeSoul => _activeSoul;
  @override
  List<Soul> get presets => _presets;
  @override
  List<Soul> get custom => _custom;

  @override
  Future<void> init() async {
    final dir = await getApplicationSupportDirectory();
    _soulsDir = '${dir.path}/souls';
    _activePath = '${dir.path}/soul.json';

    await _ensureDirs();
    _presets = _loadPresets();
    _custom = await _loadCustom();
    _activeSoul = await _loadActive();
    _log.info('init: ${_presets.length} presets, ${_custom.length} custom');
  }

  Future<void> _ensureDirs() async {
    var d = Directory('$_soulsDir/preset');
    if (!await d.exists()) await d.create(recursive: true);
    d = Directory('$_soulsDir/custom');
    if (!await d.exists()) await d.create(recursive: true);

    for (final entry in presetDefinitions.entries) {
      final file = File('$_soulsDir/preset/${entry.key}.json');
      if (!await file.exists()) {
        await file.writeAsString(jsonEncode(entry.value));
      }
    }
  }

  List<Soul> _loadPresets() {
    return presetDefinitions.entries.map((e) => Soul.fromJson(e.value)).toList();
  }

  Future<List<Soul>> _loadCustom() async {
    final d = Directory('$_soulsDir/custom');
    if (!await d.exists()) return [];
    final entities = await d.list().toList();
    final files = entities.whereType<File>().toList();
    return files.map((f) {
      try {
        final json = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
        return Soul.fromJson(json);
      } catch (_) {
        return null;
      }
    }).whereType<Soul>().toList();
  }

  Future<Soul?> _loadActive() async {
    final file = File(_activePath);
    if (!await file.exists()) return null;
    try {
      final id = await file.readAsString();
      return _findById(id.trim());
    } catch (_) {
      return null;
    }
  }

  Soul? _findById(String id) {
    for (final s in _presets) {
      if (s.id == id) return s;
    }
    for (final s in _custom) {
      if (s.id == id) return s;
    }
    if (_presets.isNotEmpty) return _presets.first;
    return null;
  }

  @override
  Soul getActiveOrDefault() {
    return _activeSoul ?? _presets.first;
  }

  @override
  Future<void> setActiveSoul(Soul soul) async {
    _activeSoul = soul;
    await File(_activePath).writeAsString(soul.id);
    _log.info('setActive: ${soul.name}');
  }

  @override
  Future<Soul> createCustomSoul(String name, String description, ILLMProvider llm) async {
    final prompt = '''
根据以下用户描述，生成一个 AI 角色的灵魂定义。
只输出 JSON，不要其他内容。

用户描述：$description

要求 JSON 字段：
- name: 角色名称（使用用户提供的名称：$name）
- description: 一句话描述
- traits: 性格标签数组
- style: 沟通风格描述
- specialty: 专长领域
- speechPattern: 说话习惯（可选）
- systemPrompt: 用第二人称写的完整角色设定，包含角色身份、沟通风格、行为准则

确保 JSON 是合法的、完整的。
''';

    final response = await llm.chat([
      {'role': 'system', 'content': '你是一个灵魂设计师。根据用户描述生成角色定义。只输出 JSON。'},
      {'role': 'user', 'content': prompt},
    ]);

    final json = jsonDecode(response) as Map<String, dynamic>;
    json['id'] = _uuid.v4();
    json['isBuiltin'] = false;
    json['isCustom'] = true;

    final soul = Soul.fromJson(json);
    _custom.add(soul);

    final file = File('$_soulsDir/custom/${soul.id}.json');
    await file.writeAsString(jsonEncode(soul.toJson()));
    _log.info('createCustom: ${soul.name}');
    return soul;
  }

  @override
  Future<void> deleteCustomSoul(String id) async {
    _custom.removeWhere((s) => s.id == id);
    final file = File('$_soulsDir/custom/$id.json');
    if (await file.exists()) await file.delete();
    if (_activeSoul?.id == id) {
      _activeSoul = _presets.first;
      await setActiveSoul(_activeSoul!);
    }
    _log.info('deleteCustom: $id');
  }

  static const Map<String, Map<String, dynamic>> presetDefinitions = soulPresetDefinitions;
}
