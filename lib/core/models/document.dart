/// Unified document model — represents any document in the system.
///
/// Paper (existing) = academic papers with structured metadata.
/// Document (new)   = any file converted to Markdown (notes, reports, slides, etc.)
/// Both share the same reading pipeline, but Document has lighter metadata.
library;

import 'paper.dart' show PaperStatus;

/// Source format of the original document.
enum DocumentFormat {
  pdf,
  docx,
  pptx,
  xlsx,
  epub,
  html,
  markdown,
  txt,
  image,
  audio,
  csv,
  json,
  xml,
  url,
  unknown;

  String get label {
    return switch (this) {
      DocumentFormat.pdf => 'PDF',
      DocumentFormat.docx => 'Word',
      DocumentFormat.pptx => 'PowerPoint',
      DocumentFormat.xlsx => 'Excel',
      DocumentFormat.epub => 'EPUB',
      DocumentFormat.html => 'HTML',
      DocumentFormat.markdown => 'Markdown',
      DocumentFormat.txt => 'Plain Text',
      DocumentFormat.image => 'Image',
      DocumentFormat.audio => 'Audio',
      DocumentFormat.csv => 'CSV',
      DocumentFormat.json => 'JSON',
      DocumentFormat.xml => 'XML',
      DocumentFormat.url => 'URL',
      DocumentFormat.unknown => 'Unknown',
    };
  }

  static DocumentFormat fromExtension(String ext) {
    return switch (ext.toLowerCase()) {
      'pdf' => DocumentFormat.pdf,
      'docx' => DocumentFormat.docx,
      'pptx' => DocumentFormat.pptx,
      'xlsx' || 'xls' => DocumentFormat.xlsx,
      'epub' => DocumentFormat.epub,
      'html' || 'htm' => DocumentFormat.html,
      'md' || 'markdown' => DocumentFormat.markdown,
      'txt' => DocumentFormat.txt,
      'png' || 'jpg' || 'jpeg' || 'gif' || 'webp' || 'bmp' => DocumentFormat.image,
      'mp3' || 'wav' || 'm4a' || 'ogg' => DocumentFormat.audio,
      'csv' => DocumentFormat.csv,
      'json' => DocumentFormat.json,
      'xml' => DocumentFormat.xml,
      _ => DocumentFormat.unknown,
    };
  }
}

/// A document that has been imported and converted to Markdown.
///
/// Lighter than [Paper] — no arXiv/S2 metadata, no translation state.
/// Can be "promoted" to a Paper if the user wants full academic features.
class Document {
  final String id;
  final String title;
  final String markdown;
  final DocumentFormat sourceFormat;
  final String sourcePath;
  final DateTime importedAt;
  final PaperStatus status;
  final String? errorMessage;
  final bool starred;
  final double scrollPosition;

  const Document({
    required this.id,
    required this.title,
    required this.markdown,
    required this.sourceFormat,
    required this.sourcePath,
    required this.importedAt,
    this.status = PaperStatus.parsed,
    this.errorMessage,
    this.starred = false,
    this.scrollPosition = 0,
  });

  Document copyWith({
    String? id,
    String? title,
    String? markdown,
    DocumentFormat? sourceFormat,
    String? sourcePath,
    DateTime? importedAt,
    PaperStatus? status,
    String? errorMessage,
    bool? starred,
    double? scrollPosition,
  }) {
    return Document(
      id: id ?? this.id,
      title: title ?? this.title,
      markdown: markdown ?? this.markdown,
      sourceFormat: sourceFormat ?? this.sourceFormat,
      sourcePath: sourcePath ?? this.sourcePath,
      importedAt: importedAt ?? this.importedAt,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      starred: starred ?? this.starred,
      scrollPosition: scrollPosition ?? this.scrollPosition,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'markdown': markdown,
    'sourceFormat': sourceFormat.name,
    'sourcePath': sourcePath,
    'importedAt': importedAt.toIso8601String(),
    'status': status.name,
    if (errorMessage != null) 'errorMessage': errorMessage,
    'starred': starred,
    'scrollPosition': scrollPosition,
  };

  factory Document.fromJson(Map<String, dynamic> json) => Document(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    markdown: json['markdown'] as String? ?? '',
    sourceFormat: DocumentFormat.values.firstWhere(
      (f) => f.name == json['sourceFormat'],
      orElse: () => DocumentFormat.unknown,
    ),
    sourcePath: json['sourcePath'] as String? ?? '',
    importedAt: DateTime.tryParse(json['importedAt'] as String? ?? '') ?? DateTime.now(),
    status: PaperStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => PaperStatus.parsed,
    ),
    errorMessage: json['errorMessage'] as String?,
    starred: json['starred'] as bool? ?? false,
    scrollPosition: (json['scrollPosition'] as num?)?.toDouble() ?? 0,
  );
}
