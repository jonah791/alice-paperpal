/// Kori 风格笔记模板管理页
library;

import 'package:flutter/material.dart';
import '../../core/di/dependencies.dart';
import '../../core/interfaces/services.dart';
import '../../core/services/template_service.dart';
import '../../core/tokens/design_tokens.dart';
import '../widgets/template_picker.dart';

class TemplatePage extends StatefulWidget {
  const TemplatePage({super.key});

  @override
  State<TemplatePage> createState() => _TemplatePageState();
}

class _TemplatePageState extends State<TemplatePage> {
  final _service = TemplateService();
  List<NoteTemplate> _templates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _service.init();
    if (mounted) setState(() {
      _templates = _service.all;
      _loading = false;
    });
  }

  Future<void> _deleteCustom(String id) async {
    await _service.deleteTemplate(id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (_loading) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Text('笔记模板', style: theme.textTheme.titleLarge),
            const Spacer(),
            Text('${_templates.length}', style: theme.textTheme.titleLarge?.copyWith(color: colors.primary)),
          ],
        ),
        const SizedBox(height: 20),
        ...List.generate(_templates.length, (i) {
          final t = _templates[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              elevation: 0,
              color: colors.surfaceContainerLow,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Icon(
                  t.isBuiltin ? Icons.auto_awesome : Icons.person_outline,
                  color: t.isBuiltin ? colors.primary : colors.secondary,
                ),
                title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(t.description, style: const TextStyle(fontSize: 12)),
                trailing: t.isBuiltin
                    ? const Chip(label: Text('预设', style: TextStyle(fontSize: 11)))
                    : IconButton(
                        icon: Icon(Icons.delete_outline, size: 18, color: colors.error),
                        onPressed: () => _deleteCustom(t.id),
                      ),
                onTap: () => _preview(t),
              ),
            ),
          );
        }),
      ],
    );
  }

  void _preview(NoteTemplate t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.name),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: SelectableText(
              t.render(),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.5),
            ),
          ),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭'))],
      ),
    );
  }
}
