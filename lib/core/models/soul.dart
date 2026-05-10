class Soul {
  final String id;
  final String name;
  final String description;
  final List<String> traits;
  final String style;
  final String specialty;
  final String systemPrompt;
  final String? speechPattern;
  final bool isBuiltin;
  final bool isCustom;

  const Soul({
    required this.id,
    required this.name,
    required this.description,
    this.traits = const [],
    this.style = '',
    this.specialty = '',
    required this.systemPrompt,
    this.speechPattern,
    this.isBuiltin = false,
    this.isCustom = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'traits': traits,
    'style': style,
    'specialty': specialty,
    'systemPrompt': systemPrompt,
    'speechPattern': speechPattern,
    'isBuiltin': isBuiltin,
    'isCustom': isCustom,
  };

  factory Soul.fromJson(Map<String, dynamic> json) => Soul(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
    traits: (json['traits'] as List?)?.cast<String>() ?? [],
    style: json['style'] as String? ?? '',
    specialty: json['specialty'] as String? ?? '',
    systemPrompt: json['systemPrompt'] as String? ?? '',
    speechPattern: json['speechPattern'] as String?,
    isBuiltin: json['isBuiltin'] as bool? ?? false,
    isCustom: json['isCustom'] as bool? ?? false,
  );
}
