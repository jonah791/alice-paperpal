import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../interfaces/services.dart';

final _log = Logger('MemoryService');
const _uuid = Uuid();

class MemoryItem {
  final String id;
  final String summary;
  final String? paperId;
  final DateTime timestamp;

  const MemoryItem({
    required this.id,
    required this.summary,
    this.paperId,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'summary': summary,
    'paperId': paperId,
    'timestamp': timestamp.toIso8601String(),
  };

  factory MemoryItem.fromJson(Map<String, dynamic> json) => MemoryItem(
    id: json['id'] as String? ?? '',
    summary: json['summary'] as String? ?? '',
    paperId: json['paperId'] as String?,
    timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
  );
}

class MemoryService implements IMemoryService {
  late final String _filePath;
  List<MemoryItem> _memories = [];
  static const int _maxMemories = 100;

  @override
  Future<void> init() async {
    final dir = await getApplicationSupportDirectory();
    _filePath = '${dir.path}/memory.json';
    await _load();
    _log.info('init: ${_memories.length} memories');
  }

  Future<void> _load() async {
    final file = File(_filePath);
    if (!await file.exists()) return;
    try {
      final json = await file.readAsString();
      final list = jsonDecode(json) as List;
      _memories = list.map((e) => MemoryItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      _log.warning('load failed: $e');
    }
  }

  Future<void> _save() async {
    final json = jsonEncode(_memories.map((m) => m.toJson()).toList());
    await File(_filePath).writeAsString(json);
  }

  @override
  List<MemoryItem> getRecent({int limit = 10}) {
    final sorted = List<MemoryItem>.from(_memories)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.take(limit).toList();
  }

  @override
  Future<void> addMemory(String summary, {String? paperId}) async {
    _memories.add(MemoryItem(
      id: _uuid.v4(),
      summary: summary,
      paperId: paperId,
      timestamp: DateTime.now(),
    ));
    if (_memories.length > _maxMemories) {
      _memories.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _memories = _memories.take(_maxMemories).toList();
    }
    await _save();
    _log.info('addMemory: $summary');
  }

  @override
  String summarizeRecent({int limit = 10}) {
    final recent = getRecent(limit: limit);
    if (recent.isEmpty) return '';
    return recent.map((m) => '- ${m.summary}').join('\n');
  }

  @override
  Future<void> prune() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    _memories.removeWhere((m) => m.timestamp.isBefore(cutoff));
    await _save();
    _log.info('prune: ${_memories.length} remaining');
  }
}
