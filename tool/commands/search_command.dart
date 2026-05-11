import '../../lib/core/api/arxiv_api.dart' show ArxivApi;
import '../../lib/core/api/s2_api.dart' show S2Api;
import '../../lib/core/models/search_result.dart';
import '../cli_helpers.dart' show println, bold, cyan, printError;
import '../cli_state.dart' show saveSearchResults;

const _help = 'search <query> [--limit N]';

Future<void> searchCommand(List<String> args) async {
  if (args.isEmpty) {
    printError(_help);
    return;
  }

  final limitIdx = args.indexOf('--limit');
  final limit = (limitIdx >= 0 && limitIdx + 1 < args.length)
      ? int.tryParse(args[limitIdx + 1]) ?? 10
      : 10;

  final query = args.where((a) => a != '--limit' && (limitIdx < 0 || a != args[limitIdx + 1])).join(' ');
  if (query.isEmpty) {
    printError(_help);
    return;
  }

  try {
    final arxiv = ArxivApi();
    final s2 = S2Api();

    println('${bold("Searching")}: $query');
    final results = await Future.wait([
      arxiv.search(query, maxResults: limit),
      s2.search(query, limit: limit),
    ]);

    final all = <String, SearchResult>{};
    for (final r in results.expand((x) => x)) {
      final key = r.doi.isNotEmpty ? r.doi : r.title.toLowerCase();
      if (!all.containsKey(key) || all[key]!.source == 'arXiv') {
        all[key] = r;
      }
    }

    final sorted = all.values.toList()..sort((a, b) => b.year.compareTo(a.year));

    if (sorted.isEmpty) {
      println('No results found.');
      return;
    }

    saveSearchResults(sorted);
    println('${bold("Results")} (${sorted.length}):\n');
    for (var i = 0; i < sorted.length; i++) {
      final r = sorted[i];
      println('  [${i + 1}] ${bold(r.title)}');
      println('       ${cyan("Authors")}: ${r.authors.join(', ')}');
      println('       ${cyan("Year")}: ${r.year} | ${cyan("Source")}: ${r.source} | ${cyan("Citations")}: ${r.citationCount}');
      if (r.doi.isNotEmpty) println('       ${cyan("DOI")}: ${r.doi}');
      if (r.pdfUrl.isNotEmpty) println('       ${cyan("PDF")}: ${r.pdfUrl}');
      if (r.abstract.isNotEmpty) {
        final abs = r.abstract.length > 150 ? '${r.abstract.substring(0, 150)}...' : r.abstract;
        println('       ${cyan("Abstract")}: $abs');
      }
      println('');
    }
  } catch (e) {
    printError('Search failed: $e');
  }
}
