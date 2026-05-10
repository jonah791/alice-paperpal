class Note {
  final String id;
  final String paperId;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;
  final NoteType type;
  final String? selectedText;
  final int? offset;

  const Note({
    required this.id,
    required this.paperId,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
    this.type = NoteType.note,
    this.selectedText,
    this.offset,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'paperId': paperId,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'type': type.name,
    'selectedText': selectedText,
    'offset': offset,
  };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    id: json['id'] as String? ?? '',
    paperId: json['paperId'] as String? ?? '',
    text: json['text'] as String? ?? '',
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    type: NoteType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => NoteType.note,
    ),
    selectedText: json['selectedText'] as String?,
    offset: json['offset'] as int?,
  );

  Note copyWith({String? text, String? selectedText, int? offset, NoteType? type}) => Note(
    id: id,
    paperId: paperId,
    text: text ?? this.text,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
    type: type ?? this.type,
    selectedText: selectedText ?? this.selectedText,
    offset: offset ?? this.offset,
  );
}

enum NoteType { note, highlight, question }
