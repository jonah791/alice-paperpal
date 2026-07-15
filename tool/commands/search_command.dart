import 'package:paperpal/core/services/search_service.dart';
import '../cli_helpers.dart' show println, bold, cyan, printError;

const _help = 'search <query> [--limit N]';

Future<void> searchCommand(List<String> args) async {
  if (args.isEmpty) {
    printError(_help);
    return;
  }

  final query = args.first;

  println('${bold("Searching")}: $query');
  
  final searchService = SearchService();
  final (results, error) = await searchService.search(query);

  if (error != null) {
    printError(error);
    return;
  }

  if (results.isEmpty) {
    println('No results found.');
    return;
  }

  println('${bold("Results")} (${results.length}):\n');
  for (var i = 0; i < results.length; i++) {
    final r = results[i];
    println('  [${i + 1}] ${bold(r.title)}');
    if (r.authors.isNotEmpty) {
      println('       ${cyan("Authors")}: ${r.authors.join(", ")}');
    }
    if (r.year > 0) {
      println('       ${cyan("Year")}: ${r.year} | ${cyan("Source")}: ${r.source}');
    }
    if (r.citationCount > 0) {
      println('       ${cyan("Citations")}: ${r.citationCount}');
    }
    if (r.pdfUrl.isNotEmpty) {
      println('       ${cyan("PDF")}: ${r.pdfUrl}');
    }
    if (r.abstract.isNotEmpty) {
      println('       ${cyan("Abstract")}: ${r.abstract.substring(0, r.abstract.length.clamp(0, 200))}...');
    }
    println('');
  }
}
