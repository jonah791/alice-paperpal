/// Note Template Service — Kori-inspired template system.
library;

import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../interfaces/services.dart';

final _log = Logger('TemplateService');

/// Built-in preset templates matching [NoteTemplate] from interfaces.
final List<NoteTemplate> builtinTemplates = [
  const NoteTemplate(
    id: 'paper_summary', name: '论文总结',
    description: '结构化总结一篇论文的核心内容', isBuiltin: true,
    markdown: '''# {{title}}\n\n**阅读日期**: {{date}}\n\n## 核心贡献\n- \n\n## 方法\n- \n\n## 主要发现\n- \n\n## 局限性\n- \n\n## 想法与延伸\n- ''',
  ),
  const NoteTemplate(
    id: 'reading_notes', name: '阅读笔记',
    description: '自由格式的阅读笔记', isBuiltin: true,
    markdown: '''# {{title}} — 阅读笔记\n\n**日期**: {{date}}\n\n## 关键点\n- \n\n## 疑问\n- \n\n## 想法\n- \n\n## 行动项\n- [ ] ''',
  ),
  const NoteTemplate(
    id: 'review', name: '审稿意见',
    description: '像审稿人一样分析论文', isBuiltin: true,
    markdown: '''# Review: {{title}}\n\n**Date**: {{date}}\n\n## Strengths\n- \n\n## Weaknesses\n- \n\n## Questions\n- \n\n## Overall Assessment\n- \n\n## Recommendation\n- [ ] Accept\n- [ ] Minor Revision\n- [ ] Major Revision\n- [ ] Reject''',
  ),
  const NoteTemplate(
    id: 'meeting_notes', name: '会议记录',
    description: '会议讨论记录模板', isBuiltin: true,
    markdown: '''# 会议记录 — {{title}}\n\n**日期**: {{date}}\n\n## 参会人\n- \n\n## 讨论要点\n- \n\n## 决议\n- \n\n## 行动项\n| 负责人 | 事项 | 截止日期 |\n|-------|------|---------|\n|       |      |         |''',
  ),
  const NoteTemplate(
    id: 'idea', name: '灵感笔记',
    description: '快速记录一个想法', isBuiltin: true,
    markdown: '''# 💡 {{title}}\n\n**日期**: {{date}}\n\n## 想法描述\n- \n\n## 为什么重要\n- \n\n## 下一步\n- [ ] ''',
  ),
];

/// Service for managing note templates.
class TemplateService implements ITemplateService {
  static const String _storageKey = 'custom_templates';

  List<NoteTemplate> _custom = [];

  @override
  List<NoteTemplate> get all => [...builtinTemplates, ..._custom];

  @override
  List<NoteTemplate> get custom => List.unmodifiable(_custom);

  @override
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_storageKey) ?? [];
      _custom = raw
          .map((s) {
            try {
              return NoteTemplate.fromJson(Map<String, dynamic>.from(Uri.splitQueryString(s)));
            } catch (_) { return null; }
          })
          .nonNulls
          .toList();
      _log.info('template init: ${_custom.length} custom templates');
    } catch (e) {
      _log.warning('template init failed: $e');
      _custom = [];
    }
  }

  @override
  Future<void> addTemplate(NoteTemplate template) async {
    _custom.add(template);
    await _save();
  }

  @override
  Future<void> deleteTemplate(String id) async {
    _custom.removeWhere((t) => t.id == id);
    await _save();
  }

  @override
  NoteTemplate? getTemplate(String id) {
    try {
      return all.firstWhere((t) => t.id == id);
    } catch (_) { return null; }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = _custom.map((t) => t.toJson().toString()).toList();
      await prefs.setStringList(_storageKey, raw);
    } catch (e) {
      _log.warning('template save failed: $e');
    }
  }
}
