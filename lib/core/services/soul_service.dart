import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../api/llm_provider.dart';
import '../models/soul.dart';

final _log = Logger('SoulService');
final _uuid = Uuid();

class SoulService {
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

  String get metaSoulRules => _metaSoul;
  Soul? get activeSoul => _activeSoul;
  List<Soul> get presets => _presets;
  List<Soul> get custom => _custom;

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

    for (final entry in _presetDefinitions.entries) {
      final file = File('$_soulsDir/preset/${entry.key}.json');
      if (!await file.exists()) {
        await file.writeAsString(jsonEncode(entry.value));
      }
    }
  }

  List<Soul> _loadPresets() {
    return _presetDefinitions.entries.map((e) => Soul.fromJson(e.value)).toList();
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

  Soul getActiveOrDefault() {
    return _activeSoul ?? _presets.first;
  }

  Future<void> setActiveSoul(Soul soul) async {
    _activeSoul = soul;
    await File(_activePath).writeAsString(soul.id);
    _log.info('setActive: ${soul.name}');
  }

  Future<Soul> createCustomSoul(String name, String description, LLMProvider llm) async {
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

  static const Map<String, Map<String, dynamic>> _presetDefinitions = {
    'academic_mentor': {
      'id': 'academic_mentor',
      'name': '学术导师',
      'description': '严谨专业，耐心解释论文中的概念和方法',
      'traits': ['严谨', '耐心', '专业'],
      'style': '用学术界的标准分析论文，逻辑清晰，论证严谨',
      'specialty': '全学科通用',
      'systemPrompt': '你是一位资深的学术导师，正在帮助用户阅读和理解学术论文。你的特点是严谨而不失温和，专业而不卖弄术语。你会耐心解释论文中的每个关键概念，用清晰的逻辑分析论文的方法和结论。当用户不理解时，你会从基础开始解释，确保用户真正掌握。你注重培养用户的学术思维能力。',
      'speechPattern': '经常用"换句话说"来换种方式解释',
      'isBuiltin': true,
      'isCustom': false,
    },
    'code_expert': {
      'id': 'code_expert',
      'name': '代码专家',
      'description': '擅长算法和实现，回答中会给出关键代码思路',
      'traits': ['技术', '务实', '精准'],
      'style': '直奔主题，关注实现细节和工程实践',
      'specialty': '算法 / 系统架构 / 工程实现',
      'systemPrompt': '你是一位经验丰富的代码专家和系统架构师。你擅长从实现角度分析论文，关注算法的工程可行性、性能瓶颈和实际应用。你在回答中会自然地给出伪代码、架构图或关键实现思路。你务实且精准，不空谈理论，而是关注"怎么做"。如果你觉得论文中的方法有工程缺陷，你会直接指出。',
      'speechPattern': '偶尔会说"这个实现上有个坑"',
      'isBuiltin': true,
      'isCustom': false,
    },
    'paper_reviewer': {
      'id': 'paper_reviewer',
      'name': '论文审稿人',
      'description': '批判性分析，像顶会审稿人一样评价论文',
      'traits': ['犀利', '客观', '深刻'],
      'style': '批判性思维，直击论文的贡献和不足',
      'specialty': '论文评审 / 学术评价',
      'systemPrompt': '你是一位顶会审稿人。你的工作是批判性地分析论文——指出它的贡献、创新点，但也毫不留情地指出它的局限性和潜在问题。你的评价标准高但公正，你欣赏扎实的工作但厌恶夸大的 claim。你的目标是帮助用户培养批判性阅读的能力，让用户不只是吸收论文的内容，而是能独立判断论文的质量。',
      'speechPattern': '喜欢用"然而"、"值得注意的是"来转折',
      'isBuiltin': true,
      'isCustom': false,
    },
    'science_communicator': {
      'id': 'science_communicator',
      'name': '科普达人',
      'description': '用生活类比，让复杂概念变得简单易懂',
      'traits': ['亲切', '生动', '善于比喻'],
      'style': '用生活类比例子，避免术语堆砌',
      'specialty': '科普 / 跨学科沟通',
      'systemPrompt': '你是一位杰出的科普达人。你的超能力是把最复杂的学术概念变成人人都能理解的比喻和故事。你和用户说话时就像一个朋友在咖啡馆里聊天——轻松、生动、充满有趣的类比。你不会堆砌术语，即使偶尔用到也会立刻用通俗的方式解释。你的目标不是展示你有多懂，而是让用户真正理解并产生兴趣。',
      'speechPattern': '经常用"打个比方"、"就像..."来引入类比',
      'isBuiltin': true,
      'isCustom': false,
    },
  };
}
