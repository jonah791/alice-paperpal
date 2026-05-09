class Paper {
  final String id;
  final String title;
  final List<String> authors;
  final int year;
  final String source;
  final String abstract;
  final String pdfPath;
  final String markdownPath;
  final String translatedPath;
  final String doi;
  final PaperStatus status;
  final int pageCount;
  final DateTime? importedAt;
  final DateTime? lastReadAt;
  final List<String> tags;

  const Paper({
    required this.id,
    required this.title,
    this.authors = const [],
    this.year = 0,
    this.source = 'local',
    this.abstract = '',
    this.pdfPath = '',
    this.markdownPath = '',
    this.translatedPath = '',
    this.doi = '',
    this.status = PaperStatus.importing,
    this.pageCount = 0,
    this.importedAt,
    this.lastReadAt,
    this.tags = const [],
  });

  Paper copyWith({
    String? id,
    String? title,
    List<String>? authors,
    int? year,
    String? source,
    String? abstract,
    String? pdfPath,
    String? markdownPath,
    String? translatedPath,
    String? doi,
    PaperStatus? status,
    int? pageCount,
    DateTime? importedAt,
    DateTime? lastReadAt,
    List<String>? tags,
  }) {
    return Paper(
      id: id ?? this.id,
      title: title ?? this.title,
      authors: authors ?? this.authors,
      year: year ?? this.year,
      source: source ?? this.source,
      abstract: abstract ?? this.abstract,
      pdfPath: pdfPath ?? this.pdfPath,
      markdownPath: markdownPath ?? this.markdownPath,
      translatedPath: translatedPath ?? this.translatedPath,
      doi: doi ?? this.doi,
      status: status ?? this.status,
      pageCount: pageCount ?? this.pageCount,
      importedAt: importedAt ?? this.importedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      tags: tags ?? this.tags,
    );
  }
}

enum PaperStatus {
  importing,
  downloading,
  parsing,
  parsed,
  translating,
  translated,
  error,
}
