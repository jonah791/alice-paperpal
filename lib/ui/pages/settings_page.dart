/// PaperPal 设置页 — Kori 风格
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../../core/di/dependencies.dart';
import '../../core/interfaces/services.dart';
import '../../core/models/config.dart';
import '../../main.dart' show configChangedNotifier;

final _log = Logger('SettingsPage');

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _llmCtrl = TextEditingController();
  final _baseCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _mineruCtrl = TextEditingController();
  bool _loading = true, _saving = false;
  String _modelVer = 'vlm';
  bool _formula = true, _table = true, _autoTrans = true;
  bool _amoled = false;
  bool _llmVis = false, _mineruVis = false;
  int _themeIdx = 0;

  static const _models = ['vlm', 'pipeline', 'MinerU-HTML'];
  static const _themeNames = ['爱丽丝', '蓝色', '青色', '绿色', '橙色', '红色', '黑色'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  Future<void> _load() async {
    final cs = context.configService;
    final cfg = cs.config;
    _llmCtrl.text = (await cs.readLlmApiKey()) ?? '';
    _baseCtrl.text = cfg.llmApiBase;
    _modelCtrl.text = cfg.llmModel;
    _mineruCtrl.text = (await cs.readMineruApiKey()) ?? '';
    _modelVer = cfg.mineruModelVersion;
    _formula = cfg.enableFormula;
    _table = cfg.enableTable;
    _autoTrans = cfg.autoTranslate;
    _amoled = cfg.amoledMode;
    _themeIdx = ['alice', 'blue', 'cyan', 'green', 'orange', 'red', 'black'].indexOf(cfg.themeVariant).clamp(0, 6);
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _llmCtrl.dispose(); _baseCtrl.dispose(); _modelCtrl.dispose(); _mineruCtrl.dispose();
    super.dispose();
  }

  String get _selectedTheme => ['alice', 'blue', 'cyan', 'green', 'orange', 'red', 'black'][_themeIdx];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    if (_loading) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('设置', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),

        // 外观
        _section('外观', [
          // 主题色选择
          Text('主题色', style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 12, children: List.generate(7, (i) {
            final seeds = [0xFF5C2D91, 0xFF415F91, 0xFF00897B, 0xFF43A047, 0xFFE65100, 0xFFC62828, 0xFF424242];
            return GestureDetector(
              onTap: () => setState(() => _themeIdx = i),
              child: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: Color(seeds[i]),
                  borderRadius: BorderRadius.circular(12),
                  border: _themeIdx == i ? Border.all(color: colors.primary, width: 3) : null,
                ),
              ),
            );
          })),
          const SizedBox(height: 12),
          Text(_themeNames[_themeIdx], style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            title: const Text('AMOLED 深黑', style: TextStyle(fontSize: 14)),
            subtitle: const Text('深色模式下纯黑背景', style: TextStyle(fontSize: 12)),
            value: _amoled, onChanged: (v) => setState(() => _amoled = v),
            contentPadding: EdgeInsets.zero, dense: true,
          ),
        ]),
        const SizedBox(height: 24),

        // LLM 配置
        _section('LLM 配置', [
          Text('支持 OpenAI 兼容 API', style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
          const SizedBox(height: 12),
          _field(_llmCtrl, 'API Key', obscure: !_llmVis, suffix: IconButton(
            icon: Icon(_llmVis ? Icons.visibility_off : Icons.visibility, size: 18),
            onPressed: () => setState(() => _llmVis = !_llmVis),
          )),
          const SizedBox(height: 8),
          _field(_baseCtrl, 'API Base', hint: 'https://api.deepseek.com'),
          const SizedBox(height: 8),
          _field(_modelCtrl, '模型', hint: 'deepseek-v4-flash'),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            title: const Text('自动翻译', style: TextStyle(fontSize: 14)),
            value: _autoTrans, onChanged: (v) => setState(() => _autoTrans = v),
            contentPadding: EdgeInsets.zero, dense: true,
          ),
        ]),
        const SizedBox(height: 24),

        // 解析引擎
        _section('解析引擎', [
          Text('MinerU v4 API', style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
          const SizedBox(height: 12),
          _field(_mineruCtrl, 'API Key', obscure: !_mineruVis, suffix: IconButton(
            icon: Icon(_mineruVis ? Icons.visibility_off : Icons.visibility, size: 18),
            onPressed: () => setState(() => _mineruVis = !_mineruVis),
          )),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _modelVer,
            decoration: InputDecoration(labelText: '模型版本', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            items: _models.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) { if (v != null) setState(() => _modelVer = v); },
          ),
          const SizedBox(height: 8),
          CheckboxListTile(title: const Text('公式识别', style: TextStyle(fontSize: 14)), value: _formula, onChanged: (v) => setState(() => _formula = v ?? true), contentPadding: EdgeInsets.zero, dense: true),
          CheckboxListTile(title: const Text('表格识别', style: TextStyle(fontSize: 14)), value: _table, onChanged: (v) => setState(() => _table = v ?? true), contentPadding: EdgeInsets.zero, dense: true),
        ]),
        const SizedBox(height: 28),

        // 保存
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('保存设置'),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(
          fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        )),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(padding: const EdgeInsets.all(20), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: children)),
        ),
      ],
    );
  }

  Widget _field(TextEditingController c, String label, {String? hint, bool obscure = false, Widget? suffix}) {
    return TextField(
      controller: c, obscureText: obscure,
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true, fillColor: Theme.of(context).colorScheme.surface,
        suffixIcon: suffix,
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final cs = context.configService;
      if (_llmCtrl.text.isNotEmpty) await cs.saveLlmApiKey(_llmCtrl.text);
      if (_mineruCtrl.text.isNotEmpty) await cs.saveMineruApiKey(_mineruCtrl.text);
      await cs.updateConfig(cs.config.copyWith(
        llmModel: _modelCtrl.text.isNotEmpty ? _modelCtrl.text : cs.config.llmModel,
        llmApiBase: _baseCtrl.text.isNotEmpty ? _baseCtrl.text : cs.config.llmApiBase,
        mineruModelVersion: _modelVer, enableFormula: _formula, enableTable: _table,
        autoTranslate: _autoTrans, themeVariant: _selectedTheme, amoledMode: _amoled,
      ));
      await context.paperService.reconfigureMineru();
      await context.paperService.reconfigureLlm();
      configChangedNotifier.notifyListeners();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('设置已保存'), behavior: SnackBarBehavior.floating));
    } catch (e) {
      _log.warning('save failed: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存失败'), behavior: SnackBarBehavior.floating));
    } finally { if (mounted) setState(() => _saving = false); }
  }
}
