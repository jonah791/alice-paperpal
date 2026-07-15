import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../../core/models/paper.dart';
import '../../core/di/dependencies.dart';

final _log = Logger('ComparisonPage');

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
    _generateAnalysis();
  }

  Future<void> _generateAnalysis() async {
    setState(() => _loading = true);
    try {

      final ps = context.paperService;
      final contents = <Map<String, String>>[];
      for (final paper in widget.papers) {
        final md = await ps.getMarkdown(paper.id);
        if (md != null) {
          contents.add({'title': paper.title, 'content': md.substring(0, md.length.clamp(0, 4000))});
        }
      }

      if (contents.isEmpty) {
        setState(() {
          _analysis = '无法读取论文内容';
          _loading = false;
        });
        return;
      }

      final prompt = StringBuffer('请对比分析以下学术论文。\n\n');
      for (final c in contents) {
        prompt.writeln('--- ${c['title']} ---');
        prompt.writeln(c['content']);
        prompt.writeln();
      }
      prompt.writeln('请从以下维度对比：');
      prompt.writeln('1. 研究目标对比');
      prompt.writeln('2. 方法对比');
      prompt.writeln('3. 主要发现/结果对比');
      prompt.writeln('4. 优势与不足');
      prompt.writeln('5. 总结');

      final answer = await ps.askQuestion(widget.papers.first.id, prompt.toString());
      setState(() {
        _analysis = answer;
        _loading = false;
      });
    } catch (e) {
      _log.warning('comparison failed: $e');
      setState(() {
        _analysis = '对比分析生成失败，请稍后重试。';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('对比分析 (${widget.papers.length} 篇)',
            style: const TextStyle(fontSize: 14)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(8),
                    itemCount: widget.papers.length,
                    itemBuilder: (ctx, i) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(label: Text(widget.papers[i].title,
                          style: const TextStyle(fontSize: 11))),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: SelectableText(
                      _analysis ?? '正在生成...',
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
