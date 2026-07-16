/// Mermaid diagram renderer service.
library;


/// A detected Mermaid diagram block.
class MermaidBlock {
  final String code;
  final int start;
  final int end;
  const MermaidBlock({required this.code, required this.start, required this.end});
}

/// Mermaid rendering service.
class MermaidRenderer {
  static const _mermaidCdn = 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js';
  final String? localMermaidPath;

  MermaidRenderer({this.localMermaidPath});

  List<MermaidBlock> extractBlocks(String markdown) {
    final blocks = <MermaidBlock>[];
    final pattern = RegExp(r'```mermaid\s*\n([\s\S]*?)```', caseSensitive: false);
    for (final match in pattern.allMatches(markdown)) {
      blocks.add(MermaidBlock(code: match.group(1)?.trim() ?? '', start: match.start, end: match.end));
    }
    return blocks;
  }

  String buildHtml(String diagramCode, {bool dark = false}) {
    final theme = dark ? 'dark' : 'default';
    return '''<!DOCTYPE html>
<html><head><meta charset="utf-8">
<style>body{margin:0;padding:16px;background:${dark?'#1a1a2e':'#fff'}}.mermaid{max-width:100%}svg{max-width:100%;height:auto}</style>
</head><body><pre class="mermaid">$diagramCode</pre>
<script src="$_mermaidCdn"></script>
<script>mermaid.initialize({startOnLoad:true,theme:'$theme',securityLevel:'loose'})</script>
</body></html>''';
  }

  /// Static check for Mermaid code validity.
  static bool isValid(String code) {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return false;
    return [
      'graph ', 'flowchart ', 'sequenceDiagram', 'classDiagram',
      'stateDiagram', 'erDiagram', 'gantt', 'pie ', 'journey',
      'gitgraph', 'mindmap', 'timeline', 'zenuml', 'sankey',
      'xyChart', 'block', 'packet', 'kanban', 'architecture-beta',
    ].any((t) => trimmed.startsWith(t));
  }
}
