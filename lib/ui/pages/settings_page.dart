/// Kori 风格设置页 — 卡片分组 + 主题选择器
library;

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../../core/di/dependencies.dart';
import '../../core/tokens/design_tokens.dart';
import '../../core/interfaces/services.dart';
import '../../core/models/config.dart';
import '../widgets/soul_selector.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/theme_selector.dart';
import '../theme/themes/theme_variant.dart';

import '../../main.dart' show configChangedNotifier;

final _log = Logger('SettingsPage');

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _llmKeyCtrl = TextEditingController();
  final _llmBaseCtrl = TextEditingController();
  final _llmModelCtrl = TextEditingController();
  final _mineruKeyCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _loaded = false;
  String _mineruModelVersion = 'vlm';
  bool _enableFormula = true;
  bool _enableTable = true;
  bool _autoTranslate = true;
  ThemeVariant _themeVariant = ThemeVariant.alice;
  bool _amoled = false;
  bool _llmKeyVisible = false;
  bool _mineruKeyVisible = false;

  static const _modelVersions = ['vlm', 'pipeline', 'MinerU-HTML'];
  static const _modelVersionLabels = {
    'vlm': 'VLM（推荐）',
    'pipeline': 'Pipeline',
    'MinerU-HTML': 'MinerU-HTML',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _loadSettings();
    }
  }

  Future<void> _loadSettings() async {
    try {
      final cs = context.configService;
      final cfg = cs.config;
      _llmKeyCtrl.text = (await cs.readLlmApiKey()) ?? '';
      _llmBaseCtrl.text = cfg.llmApiBase;
      _llmModelCtrl.text = cfg.llmModel;
      _mineruKeyCtrl.text = (await cs.readMineruApiKey()) ?? '';
      _mineruModelVersion = cfg.mineruModelVersion;
      _enableFormula = cfg.enableFormula;
      _enableTable = cfg.enableTable;
      _autoTranslate = cfg.autoTranslate;
      _themeVariant = ThemeVariant.values.firstWhere(
        (t) => t.name == cfg.themeVariant,
        orElse: () => ThemeVariant.alice,
      );
      _amoled = cfg.amoledMode;
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      _log.warning('loadSettings failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _llmKeyCtrl.dispose();
    _llmBaseCtrl.dispose();
    _llmModelCtrl.dispose();
    _mineruKeyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // ── 外观 ──────────────────────────────────────────────
        _sectionLabel(context, '外观'),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: colors.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ThemeSelector(
                  current: _themeVariant,
                  onChanged: (v) => setState(() => _themeVariant = v),
                ),
                const Divider(height: 24),
                SwitchListTile(
                  title: const Text('AMOLED 深黑模式', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('深色模式下使用纯黑背景', style: TextStyle(fontSize: 12)),
                  value: _amoled,
                  onChanged: (v) => setState(() => _amoled = v),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── LLM 配置 ──────────────────────────────────────────
        _sectionLabel(context, 'LLM 配置'),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: colors.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('支持 OpenAI 兼容 API，默认 DeepSeek V4',
                    style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                const SizedBox(height: 16),
                TextField(
                  controller: _llmKeyCtrl,
                  obscureText: !_llmKeyVisible,
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true, fillColor: colors.surface,
                    suffixIcon: IconButton(
                      icon: Icon(_llmKeyVisible ? Icons.visibility_off : Icons.visibility, size: 18),
                      onPressed: () => setState(() => _llmKeyVisible = !_llmKeyVisible),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _llmBaseCtrl,
                  decoration: InputDecoration(
                    labelText: 'API Base',
                    hintText: 'https://api.deepseek.com',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true, fillColor: colors.surface,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _llmModelCtrl,
                  decoration: InputDecoration(
                    labelText: '模型',
                    hintText: 'deepseek-v4-flash',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true, fillColor: colors.surface,
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('自动翻译', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('非中文论文导入后自动翻译', style: TextStyle(fontSize: 12)),
                  value: _autoTranslate,
                  onChanged: (v) => setState(() => _autoTranslate = v),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── AI 灵魂 ───────────────────────────────────────────
        _sectionLabel(context, 'AI 灵魂'),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: colors.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: const Padding(
            padding: EdgeInsets.all(20),
            child: SoulSelector(),
          ),
        ),
        const SizedBox(height: 24),

        // ── 头像 ──────────────────────────────────────────────
        _sectionLabel(context, '头像'),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: colors.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: const Padding(
            padding: EdgeInsets.all(20),
            child: AvatarPicker(),
          ),
        ),
        const SizedBox(height: 24),

        // ── 解析引擎 ─────────────────────────────────────────
        _sectionLabel(context, '解析引擎'),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: colors.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PDF 上传至 MinerU 云端解析（v4 API）',
                    style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                const SizedBox(height: 16),
                TextField(
                  controller: _mineruKeyCtrl,
                  obscureText: !_mineruKeyVisible,
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true, fillColor: colors.surface,
                    suffixIcon: IconButton(
                      icon: Icon(_mineruKeyVisible ? Icons.visibility_off : Icons.visibility, size: 18),
                      onPressed: () => setState(() => _mineruKeyVisible = !_mineruKeyVisible),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _mineruModelVersion,
                  decoration: InputDecoration(
                    labelText: '模型版本',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true, fillColor: colors.surface,
                  ),
                  items: _modelVersions.map((v) => DropdownMenuItem(
                    value: v,
                    child: Text(_modelVersionLabels[v] ?? v),
                  )).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _mineruModelVersion = v);
                  },
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('公式识别', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('识别并提取数学公式', style: TextStyle(fontSize: 12)),
                  value: _enableFormula,
                  onChanged: (v) => setState(() => _enableFormula = v ?? true),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                CheckboxListTile(
                  title: const Text('表格识别', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('识别并提取表格结构', style: TextStyle(fontSize: 12)),
                  value: _enableTable,
                  onChanged: (v) => setState(() => _enableTable = v ?? true),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),

        // ── 保存按钮 ─────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _saving ? null : _saveSettings,
            icon: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save),
            label: Text(_saving ? '保存中...' : '保存设置'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Future<void> _saveSettings() async {
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      final cs = context.configService;
      final ps = context.paperService;
      final messenger = ScaffoldMessenger.of(context);

      if (_llmKeyCtrl.text.isNotEmpty) {
        await cs.saveLlmApiKey(_llmKeyCtrl.text);
      }
      if (_mineruKeyCtrl.text.isNotEmpty) {
        await cs.saveMineruApiKey(_mineruKeyCtrl.text);
      }

      final cfg = cs.config;
      await cs.updateConfig(cfg.copyWith(
        llmModel: _llmModelCtrl.text.isNotEmpty ? _llmModelCtrl.text : cfg.llmModel,
        llmApiBase: _llmBaseCtrl.text.isNotEmpty ? _llmBaseCtrl.text : cfg.llmApiBase,
        mineruModelVersion: _mineruModelVersion,
        enableFormula: _enableFormula,
        enableTable: _enableTable,
        autoTranslate: _autoTranslate,
        themeVariant: _themeVariant.name,
        amoledMode: _amoled,
      ));

      await ps.reconfigureMineru();
      await ps.reconfigureLlm();

      if (mounted) {
        configChangedNotifier.notifyListeners();
        messenger.showSnackBar(const SnackBar(
          content: Text('设置已保存'), duration: Duration(seconds: 2),
        ));
      }
    } catch (e) {
      _log.warning('saveSettings failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存失败，请重试')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _sectionLabel(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: DesignTokens.fsXs,
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 1.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
