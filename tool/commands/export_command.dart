import 'dart:io';

import '../../lib/core/models/paper.dart' show Paper;
import '../cli_helpers.dart' show println, bold, cyan, printError, printSuccess;
import '../cli_state.dart' show loadPapersIndex, readPaperMarkdown;

const _help = 'export bibtex <id> [--output <path>] | export markdown <id> [--output <path>]';

void exportCommand(List<String> args) {
  if (args.length < 2) {
    printError(_help);
    return;
  }

  final format = args[0];
  final paperId = args[1];
  final outputIdx = args.indexOf('--output');
  final outputPath = (outputIdx >= 0 && outputIdx + 1 < args.length)
      ? args[outputIdx + 1]
      : null;

  final papers = loadPapersIndex();
  final json = papers.where((p) => p['id'] == paperId).firstOrNull;
  if (json == null) {
    printError('Paper not found: $paperId');
    return;
  }

  final paper = Paper.fromJson(json);

  if (format == 'bibtex') {
    final bibtex = _generateBibtex(paper);
    if (outputPath != null) {
      File(outputPath).writeAsStringSync(bibtex);
      printSuccess('BibTeX saved to $outputPath');
    } else {
      println(bibtex);
    }
  } else if (format == 'markdown') {
    final md = readPaperMarkdown(paperId);
    if (md == null) {
      printError('Paper markdown not found (not parsed yet?): $paperId');
      return;
    }
    final frontmatter = '''---
title: "${_escapeYaml(paper.title)}"
authors: [${paper.authors.map((a) => '"${_escapeYaml(a)}"').join(', ')}]
year: ${paper.year}
doi: "${_escapeYaml(paper.doi)}"
source: "${_escapeYaml(paper.source)}"
---
''';
    final content = frontmatter + md;
    if (outputPath != null) {
      File(outputPath).writeAsStringSync(content);
      printSuccess('Markdown saved to $outputPath');
    } else {
      println(content);
    }
  } else {
    printError('Unsupported format: $format\n$_help');
  }
}

String _escapeYaml(String s) => s.replaceAll('"', r'\"');

String _generateBibtex(Paper paper) {
  final key = paper.doi.isNotEmpty
      ? paper.doi.replaceAll(RegExp(r'[/.-]'), '_')
      : paper.title.split(RegExp(r'\s+')).take(3).join('_');

  final authorLine = paper.authors.isNotEmpty
      ? paper.authors.map((a) {
          final parts = a.trim().split(RegExp(r'\s+'));
          if (parts.length >= 2) {
            return '${parts.last}, ${parts.sublist(0, parts.length - 1).join(' ')}';
          }
          return a;
        }).join(' and ')
      : '{Anonymous}';

  return '''@article{$key,
  title={${paper.title}},
  author={$authorLine},
  year={${paper.year}},
}''';
}
