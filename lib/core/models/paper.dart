class Paper {
  final String id;
  final String title;
  final List<String> authors;
  final int year;
  final String source;
  final String doi;
  final PaperStatus status;
  final int pageCount;
  final DateTime? importedAt;
  final DateTime? lastReadAt;
  final List<String> tags;
  final String? errorMessage;
  final String sourceType;

  const Paper({
    required this.id,
    required this.title,
    this.authors = const [],
    this.year = 0,
    this.source = 'local',
    this.doi = '',
    this.status = PaperStatus.importing,
    this.pageCount = 0,
    this.importedAt,
    this.lastReadAt,
    this.tags = const [],
    this.errorMessage,
    this.sourceType = 'mineru',
  });

  Paper copyWith({
    String? id,
    String? title,
    List<String>? authors,
    int? year,
    String? source,
    String? doi,
    PaperStatus? status,
    int? pageCount,
    DateTime? importedAt,
    DateTime? lastReadAt,
    List<String>? tags,
    String? errorMessage,
    String? sourceType,
  }) {
    return Paper(
      id: id ?? this.id,
      title: title ?? this.title,
      authors: authors ?? this.authors,
      year: year ?? this.year,
      source: source ?? this.source,
      doi: doi ?? this.doi,
      status: status ?? this.status,
      pageCount: pageCount ?? this.pageCount,
      importedAt: importedAt ?? this.importedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      tags: tags ?? this.tags,
      errorMessage: errorMessage,
      sourceType: sourceType ?? this.sourceType,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'authors': authors,
    'year': year,
    'source': source,
    'doi': doi,
    'status': status.name,
    'pageCount': pageCount,
    'importedAt': importedAt?.toIso8601String(),
    'lastReadAt': lastReadAt?.toIso8601String(),
    'tags': tags,
    if (errorMessage != null) 'errorMessage': errorMessage,
    'sourceType': sourceType,
  };

  factory Paper.fromJson(Map<String, dynamic> json) => Paper(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    authors: (json['authors'] as List?)?.cast<String>() ?? [],
    year: json['year'] as int? ?? 0,
    source: json['source'] as String? ?? 'local',
    doi: json['doi'] as String? ?? '',
    status: PaperStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => PaperStatus.importing,
    ),
    pageCount: json['pageCount'] as int? ?? 0,
    importedAt: json['importedAt'] != null
        ? DateTime.tryParse(json['importedAt'] as String)
        : null,
    lastReadAt: json['lastReadAt'] != null
        ? DateTime.tryParse(json['lastReadAt'] as String)
        : null,
    tags: (json['tags'] as List?)?.cast<String>() ?? [],
    errorMessage: json['errorMessage'] as String?,
    sourceType: json['sourceType'] as String? ?? 'mineru',
  );
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
