/// Note Template Picker — Kori-inspired template selection dialog.
///
/// Shows available note templates and allows inserting a rendered template
/// into a note. Supports built-in and custom templates.
library;

import 'package:flutter/material.dart';
import '../../core/interfaces/services.dart';
import '../../core/services/template_service.dart';
import '../../core/tokens/design_tokens.dart';

/// A dialog/modal for picking a note template.
class TemplatePicker extends StatefulWidget {
  /// Called when a template is selected with its rendered content.
  final void Function(String renderedContent) onSelect;

  /// Optional paper title for template rendering.
  final String? paperTitle;

  const TemplatePicker({
    super.key,
    required this.onSelect,
    this.paperTitle,
  });

  /// Show the template picker as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required void Function(String) onSelect,
    String? paperTitle,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: TemplatePicker(
          onSelect: (content) {
            Navigator.pop(ctx);
            onSelect(content);
          },
          paperTitle: paperTitle,
        ),
      ),
    );
  }

  @override
  State<TemplatePicker> createState() => _TemplatePickerState();
}

class _TemplatePickerState extends State<TemplatePicker> {
  final _templateService = TemplateService();
  List<NoteTemplate> _filtered = [];
  String _searchQuery = '';
  bool _loading = true;
  bool _showBuiltin = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _templateService.init();
    setState(() {
      _filtered = _templateService.all;
      _loading = false;
    });
  }

  void _filter(String query) {
    setState(() {
      _searchQuery = query;
      _filtered = _templateService.all.where((t) {
        if (!_showBuiltin && t.isBuiltin) return false;
        if (query.isEmpty) return true;
        final q = query.toLowerCase();
        return t.name.toLowerCase().contains(q) ||
            t.description.toLowerCase().contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.description_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('选择笔记模板',
                      style: theme.textTheme.titleMedium),
                  const Spacer(),
                  // Toggle builtin
                  TextButton(
                    onPressed: () {
                      _showBuiltin = !_showBuiltin;
                      _filter(_searchQuery);
                    },
                    child: Text(_showBuiltin ? '仅自定义' : '显示全部'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Search
              TextField(
                decoration: InputDecoration(
                  hintText: '搜索模板...',
                  prefixIcon: const Icon(Icons.search, size: DesignTokens.iconMd),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: _filter,
              ),
            ],
          ),
        ),
        // Template list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.description, size: 48,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
                          const SizedBox(height: 8),
                          Text('没有匹配的模板',
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final t = _filtered[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              t.isBuiltin
                                  ? Icons.auto_awesome
                                  : Icons.person_outline,
                              color: t.isBuiltin
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.secondary,
                            ),
                            title: Text(t.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(t.description,
                                style: const TextStyle(fontSize: DesignTokens.fsSm)),
                            trailing: const Icon(Icons.add_circle_outline,
                                size: DesignTokens.iconMd),
                            onTap: () {
                              final rendered = t.render(
                                paperTitle: widget.paperTitle,
                              );
                              widget.onSelect(rendered);
                            },
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
