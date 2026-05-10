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
  final _mineruEndpointController = TextEditingController();
  final _mineruKeyController = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final deps = Dependencies.of(context);
    final cfg = deps.configService.config;
    final llmKey = await deps.configService.readLlmApiKey();
    final mineruKey = await deps.configService.readMineruApiKey();

    _llmKeyController.text = llmKey ?? '';
    _llmBaseController.text = cfg.llmApiBase;
    _mineruEndpointController.text = cfg.mineruApiEndpoint;
    _mineruKeyController.text = mineruKey ?? '';

    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _llmKeyController.dispose();
    _llmBaseController.dispose();
    _mineruEndpointController.dispose();
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

        // LLM Provider
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LLM 配置', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
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

        // Soul
        const SoulSelector(),
        const SizedBox(height: 16),

        // Avatar
        const AvatarPicker(),
        const SizedBox(height: 16),

        // MinerU
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MinerU 解析引擎', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('⚠️ 论文 PDF 将上传至 MinerU 云端进行解析。如需私有化，可填写自部署地址。',
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: 16),
                TextField(
                  controller: _mineruEndpointController,
                  decoration: const InputDecoration(
                    labelText: 'API Endpoint',
                    hintText: 'https://mineru.net/api/v2',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _mineruKeyController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'API Key（选填）',
                    border: OutlineInputBorder(),
                  ),
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
      mineruApiEndpoint: _mineruEndpointController.text.isNotEmpty
          ? _mineruEndpointController.text
          : deps.configService.config.mineruApiEndpoint,
    );
    await deps.configService.updateConfig(updatedConfig);

    if (mounted) {
      _log.info('settings saved');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设置已保存')),
      );
    }
  }
}
