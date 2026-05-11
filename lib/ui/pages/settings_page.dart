import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../../main.dart';
import '../widgets/soul_selector.dart';
import '../widgets/avatar_picker.dart';

final _log = Logger('SettingsPage');

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _llmKeyController = TextEditingController();
  final _llmBaseController = TextEditingController();
  final _mineruKeyController = TextEditingController();
  bool _loading = true;
  bool _loaded = false;
  String _mineruModelVersion = 'vlm';
  bool _enableFormula = true;
  bool _enableTable = true;

  static const _modelVersions = ['vlm', 'pipeline', 'MinerU-HTML'];
  static const _modelVersionLabels = {
    'vlm': 'VLM（推荐）',
    'pipeline': 'Pipeline',
    'MinerU-HTML': 'MinerU-HTML',
  };

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _loadSettings();
    }
  }

  Future<void> _loadSettings() async {
    final deps = Dependencies.of(context);
    final cfg = deps.configService.config;
    final llmKey = await deps.configService.readLlmApiKey();
    final mineruKey = await deps.configService.readMineruApiKey();

    _llmKeyController.text = llmKey ?? '';
    _llmBaseController.text = cfg.llmApiBase;
    _mineruKeyController.text = mineruKey ?? '';
    _mineruModelVersion = cfg.mineruModelVersion;
    _enableFormula = cfg.enableFormula;
    _enableTable = cfg.enableTable;

    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _llmKeyController.dispose();
    _llmBaseController.dispose();
    _mineruKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('设置', style: theme.textTheme.titleLarge),
        const SizedBox(height: 24),

        _sectionLabel(context, 'LLM 配置'),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('默认使用 DeepSeek V4 Flash。支持 OpenAI 兼容 API。',
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: 16),
                TextField(
                  controller: _llmKeyController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'API Key',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _llmBaseController,
                  decoration: const InputDecoration(
                    labelText: 'API Base',
                    hintText: 'https://api.deepseek.com',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _sectionLabel(context, '灵魂'),
        const SizedBox(height: 8),
        const SoulSelector(),
        const SizedBox(height: 16),
        _sectionLabel(context, '头像'),
        const SizedBox(height: 8),
        const AvatarPicker(),
        const SizedBox(height: 16),

        _sectionLabel(context, '解析引擎'),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('论文 PDF 将上传至 MinerU 云端进行解析（v4 API）。',
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: 16),
                TextField(
                  controller: _mineruKeyController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'API Key',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _mineruModelVersion,
                  decoration: const InputDecoration(
                    labelText: '模型版本',
                    border: OutlineInputBorder(),
                  ),
                  items: _modelVersions.map((v) => DropdownMenuItem(
                    value: v,
                    child: Text(_modelVersionLabels[v] ?? v),
                  )).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _mineruModelVersion = v);
                  },
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('公式识别'),
                  subtitle: const Text('识别并提取数学公式'),
                  value: _enableFormula,
                  onChanged: (v) => setState(() => _enableFormula = v ?? true),
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: const Text('表格识别'),
                  subtitle: const Text('识别并提取表格结构'),
                  value: _enableTable,
                  onChanged: (v) => setState(() => _enableTable = v ?? true),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Save
        FilledButton.icon(
          onPressed: _saveSettings,
          icon: const Icon(Icons.save),
          label: const Text('保存'),
        ),
      ],
    );
  }

  Future<void> _saveSettings() async {
    final deps = Dependencies.of(context);
    if (_llmKeyController.text.isNotEmpty) {
      await deps.configService.saveLlmApiKey(_llmKeyController.text);
    }
    if (_mineruKeyController.text.isNotEmpty) {
      await deps.configService.saveMineruApiKey(_mineruKeyController.text);
    }

    final updatedConfig = deps.configService.config.copyWith(
      llmApiBase: _llmBaseController.text.isNotEmpty
          ? _llmBaseController.text
          : deps.configService.config.llmApiBase,
      mineruModelVersion: _mineruModelVersion,
      enableFormula: _enableFormula,
      enableTable: _enableTable,
    );
    await deps.configService.updateConfig(updatedConfig);

    if (mounted) {
      _log.info('settings saved: modelVersion=$_mineruModelVersion');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设置已保存（部分更改下次启动生效）')),
      );
    }
  }

  Widget _sectionLabel(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 9,
        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.4),
        letterSpacing: 2,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
