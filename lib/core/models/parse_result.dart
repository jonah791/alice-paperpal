class ParseResult {
  final String markdown;
  final String title;
  final List<String> imagePaths;
  final String contentListJson;
  final int startPage;
  final int endPage;

  const ParseResult({
    required this.markdown,
    this.title = '',
    this.imagePaths = const [],
    this.contentListJson = '',
    this.startPage = 0,
    this.endPage = 0,
  });
}

class ParseProgress {
  final int currentBatch;
  final int totalBatches;
  final int currentPage;
  final int totalPages;

  const ParseProgress({
    required this.currentBatch,
    required this.totalBatches,
    this.currentPage = 0,
    this.totalPages = 0,
  });
}
