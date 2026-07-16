/// Kori 风格论文对比页
import 'package:flutter/material.dart';
import '../../core/di/dependencies.dart';
import '../../core/models/paper.dart';

class ComparisonPage extends StatefulWidget {
  final List<Paper> papers;
  const ComparisonPage({super.key, required this.papers});

  @override
  State<ComparisonPage> createState() => _ComparisonPageState();
}

class _ComparisonPageState extends State<ComparisonPage> {
  String? _analysis;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() => _loading = true);
    try {
      final titles = widget.papers.map((p) => '- ${p.title}').join('\n');
      final answer = await context.llmProvider.chat([
        {'role': 'system', 'content': '你是一位论文审稿人。对比以下论文，分析异同和各自的贡献。'},
        {'role': 'user', 'content': '请对比以下论文：\n\n$titles'},
      ], maxTokens: 800);
      if (mounted) setState(() => _analysis = answer);
    } catch (_) {
      if (mounted) setState(() => _analysis = '分析失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('论文对比'),
        actions: [
          if (_analysis != null)
            IconButton(icon: const Icon(Icons.refresh), onPressed: _generate),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                ...widget.papers.map((p) => Card(
                  elevation: 0,
                  color: colors.surfaceContainerLow,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                        if (p.authors.isNotEmpty)
                          Text(p.authors.join(', '), style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                )),
                if (_analysis != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    color: colors.primaryContainer.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        _analysis!,
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
