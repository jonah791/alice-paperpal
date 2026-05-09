class SearchResult {
  final String title;
  final List<String> authors;
  final int year;
  final String abstract;
  final String pdfUrl;
  final String source;
  final String doi;
  final int citationCount;

  const SearchResult({
    required this.title,
    this.authors = const [],
    this.year = 0,
    this.abstract = '',
    this.pdfUrl = '',
    this.source = '',
    this.doi = '',
    this.citationCount = 0,
  });
}
