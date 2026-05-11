import 'dart:io';

import '../../lib/core/api/arxiv_api.dart' show ArxivApi;
import '../../lib/core/api/mineru_api.dart' show MineruApi;
import '../../lib/core/models/paper.dart' show Paper, PaperStatus;
import '../../lib/core/services/parse_service.dart' show ParseService;
import '../../lib/core/services/search_service.dart' show SearchService;
import '../cli_helpers.dart' show println, bold, cyan, printError, printSuccess;
import '../cli_state.dart' show loadConfig, loadPapersIndex, savePapersIndex, savePaperMarkdown, getSearchResults;

const _help = 'import search <index> | import pdf <path> [--title T] | import url <url> [--title T]';

Future<void> importCommand(List<String> args) async {
  if (args.isEmpty) {
    printError(_help);
    return;
  }

  final cfg = loadConfig();
  final apiKey = (cfg['mineru-api-key'] as String?) ?? '';
  if (apiKey.isEmpty) {
    printError('MinerU API key not set. Run: config set mineru-api-key <key>');
    return;
  }

  final sub = args[0];

  if (sub == 'search') {
    if (args.length < 2) {
      printError('Usage: import search <index>');
      return;
    }
    final index = int.tryParse(args[1]);
    if (index == null) {
      printError('Invalid index: ${args[1]}');
      return;
    }
    await _importFromSearch(index, apiKey, cfg);
  } else if (sub == 'pdf') {
    if (args.length < 2) {
      printError('Usage: import pdf <path> [--title T]');
      return;
    }
    final pdfPath = args[1];
    final title = args.contains('--title') ? args[args.indexOf('--title') + 1] : null;
    await _importPdf(pdfPath, apiKey, title: title);
  } else if (sub == 'url') {
    if (args.length < 2) {
      printError('Usage: import url <url> [--title T]');
      return;
    }
    final url = args[1];
    final title = args.contains('--title') ? args[args.indexOf('--title') + 1] : null;
    await _importUrl(url, apiKey, title: title);
  } else {
    printError('Unknown: $sub\n$_help');
  }
}

Future<Map<String, dynamic>?> _fetchArxivMetadata(String url, String title) async {
  // Extract arXiv ID from URL
  final arxivMatch = RegExp(r'arxiv\.org/(?:abs|pdf)/(\d+\.\d+)').firstMatch(url);
  if (arxivMatch == null) return null;

  final arxivId = arxivMatch.group(1)!;
  final arxiv = ArxivApi();

  try {
    final results = await arxiv.search('$arxivId', maxResults: 1);
    if (results.isNotEmpty) {
      final r = results.first;
      return {
        'title': r.title.isNotEmpty ? r.title : title,
        'authors': r.authors,
        'year': r.year,
        'doi': r.doi,
        'source': 'arXiv',
      };
    }
  } catch (_) {}
  return null;
}

Future<void> _importFromSearch(int index, String apiKey, Map<String, dynamic> cfg) async {
  final results = getSearchResults();
  if (index < 1 || index > results.length) {
    printError('Invalid index $index. Run search first to get results (1-${results.length}).');
    return;
  }

  final result = results[index - 1];
  println('${bold("Importing from search")}: [${index}] ${result.title}');

  if (result.pdfUrl.isEmpty) {
    printError('No PDF URL available for this result.');
    return;
  }

  try {
    // Download PDF
    final searchService = SearchService();
    final tempDir = Directory.systemTemp.createTempSync('paperpal_import_');
    final pdf = await searchService.downloadPdf(result, tempDir.path);

    if (pdf == null) {
      printError('Failed to download PDF from ${result.pdfUrl}');
      return;
    }

    println('${cyan("Downloaded PDF")}: ${pdf.path} (${pdf.statSync().size} bytes)');

    // Parse via MinerU
    final mineru = MineruApi(apiKey: apiKey);
    final parseService = ParseService(api: mineru);
    final pageCount = (pdf.statSync().size ~/ 50000).clamp(1, 500);

    println('${cyan("Parsing via MinerU")}...');
    final parseResult = await parseService.parsePdf(pdf, pageCount);

    final paperId = DateTime.now().millisecondsSinceEpoch.toString();
    final paper = Paper(
      id: paperId,
      title: result.title,
      authors: result.authors,
      year: result.year,
      source: result.source,
      doi: result.doi,
      status: PaperStatus.parsed,
      pageCount: pageCount,
      importedAt: DateTime.now(),
    );

    final papers = loadPapersIndex();
    papers.add(paper.toJson());
    savePapersIndex(papers);
    savePaperMarkdown(paperId, parseResult.markdown);

    // Cleanup temp
    pdf.deleteSync();

    printSuccess('Import complete: id=$paperId');
    println('  ${cyan("Title")}: ${result.title}');
    println('  ${cyan("Authors")}: ${result.authors.join(', ')}');
    println('  ${cyan("Year")}: ${result.year}');
    println('  ${cyan("Markdown")}: ${parseResult.markdown.length} chars');
  } catch (e) {
    printError('Import from search failed: $e');
  }
}

Future<void> _importPdf(String pdfPath, String apiKey, {String? title}) async {
  final file = File(pdfPath);
  if (!file.existsSync()) {
    printError('File not found: $pdfPath');
    return;
  }

  final resolvedTitle = title ?? pdfPath.split(Platform.pathSeparator).last.replaceAll('.pdf', '');
  println('${bold("Importing PDF")}: $pdfPath');
  println('${cyan("Title")}: $resolvedTitle');

  final mineru = MineruApi(apiKey: apiKey);
  final parseService = ParseService(api: mineru);

  try {
    final pageCount = (file.statSync().size ~/ 50000).clamp(1, 500);
    println('${cyan("Estimated pages")}: $pageCount');

    final result = await parseService.parsePdf(file, pageCount);
    final paperId = DateTime.now().millisecondsSinceEpoch.toString();

    // Try to extract title from markdown
    var finalTitle = resolvedTitle;
    final firstLine = result.markdown.split('\n').firstWhere(
      (l) => l.startsWith('# ') && l.length > 2,
      orElse: () => '',
    );
    if (firstLine.isNotEmpty) {
      finalTitle = firstLine.substring(2).trim();
    }

    final paper = Paper(
      id: paperId,
      title: finalTitle,
      status: PaperStatus.parsed,
      pageCount: pageCount,
      importedAt: DateTime.now(),
    );

    final papers = loadPapersIndex();
    papers.add(paper.toJson());
    savePapersIndex(papers);
    savePaperMarkdown(paperId, result.markdown);

    printSuccess('Import complete: id=$paperId');
    println('  ${cyan("Title")}: $finalTitle');
    println('  ${cyan("Markdown")}: ${result.markdown.length} chars');
    println('  ${cyan("Images")}: ${result.imagePaths.length}');
    println('');
    println('  Ask questions: dart run tool/paperpal.dart ask $paperId "your question"');
    println('  Summarize:    dart run tool/paperpal.dart summarize $paperId');
    println('  Translate:    dart run tool/paperpal.dart translate $paperId');
    println('  Export:       dart run tool/paperpal.dart export bibtex $paperId');
  } catch (e) {
    printError('Import failed: $e');
  }
}

Future<void> _importUrl(String url, String apiKey, {String? title}) async {
  println('${bold("Importing URL")}: $url');
  final mineru = MineruApi(apiKey: apiKey);

  try {
    final result = await mineru.parseUrl(url);

    final resolvedTitle = title ?? url.split('/').last.replaceAll('.pdf', '').replaceAll(RegExp(r'%20|_'), ' ');
    final paperId = DateTime.now().millisecondsSinceEpoch.toString();

    // Try to fetch arXiv metadata
    var authors = <String>[];
    var year = 0;
    var doi = '';
    var finalTitle = resolvedTitle;
    var source = 'arXiv';

    final meta = await _fetchArxivMetadata(url, resolvedTitle);
    if (meta != null) {
      finalTitle = meta['title'] as String;
      authors = meta['authors'] as List<String>;
      year = meta['year'] as int;
      doi = meta['doi'] as String;
      println('${cyan("arXiv metadata")}: ${authors.join(', ')} ($year)');
    }

    final paper = Paper(
      id: paperId,
      title: finalTitle,
      authors: authors,
      year: year,
      source: source,
      doi: doi,
      status: PaperStatus.parsed,
      importedAt: DateTime.now(),
    );

    final papers = loadPapersIndex();
    papers.add(paper.toJson());
    savePapersIndex(papers);
    savePaperMarkdown(paperId, result.markdown);

    printSuccess('Import complete: id=$paperId');
    println('  ${cyan("Title")}: $finalTitle');
    if (authors.isNotEmpty) println('  ${cyan("Authors")}: ${authors.join(', ')}');
    println('  ${cyan("Markdown")}: ${result.markdown.length} chars');
  } catch (e) {
    printError('URL import failed: $e');
  }
}
