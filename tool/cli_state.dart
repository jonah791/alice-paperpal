import 'dart:convert';
import 'dart:io';

import '../lib/core/models/search_result.dart';
import '../lib/core/models/soul_presets.dart' show soulPresetDefinitions;
export '../lib/core/models/soul_presets.dart' show soulPresetDefinitions;

String get _dataDir {
  final home = Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      '${Platform.environment['HOMEDRIVE']}${Platform.environment['HOMEPATH']}';
  return '$home/.paperwise';
}

String get _papersDir => '$_dataDir/papers';
String get _indexPath => '$_papersDir/index.json';
String get _configPath => '$_dataDir/config.json';
String get _memoriesPath => '$_dataDir/memory.json';
String get _portraitPath => '$_dataDir/portrait.json';
String get _notesPath => '$_dataDir/notes.json';
String get _soulsDir => '$_dataDir/souls';
String get _soulsPresetDir => '$_soulsDir/preset';
String get _soulsCustomDir => '$_soulsDir/custom';
String get _activeSoulPath => '$_dataDir/soul.json';

// ── Search Results ──

List<SearchResult>? _lastSearchResults;

void saveSearchResults(List<SearchResult> results) {
  _lastSearchResults = List.from(results);
}

List<SearchResult> getSearchResults() => _lastSearchResults ?? [];

// ── Config ──

Map<String, dynamic> loadConfig() {
  final f = File(_configPath);
  if (!f.existsSync()) return {};
  return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
}

void saveConfig(Map<String, dynamic> cfg) {
  ensureDirs();
  File(_configPath).writeAsStringSync(jsonEncode(cfg));
}

// ── Papers Index ──

List<Map<String, dynamic>> loadPapersIndex() {
  final f = File(_indexPath);
  if (!f.existsSync()) return [];
  try {
    return (jsonDecode(f.readAsStringSync()) as List).cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
}

void savePapersIndex(List<Map<String, dynamic>> papers) {
  ensureDirs();
  File(_indexPath).writeAsStringSync(jsonEncode(papers));
}

// ── Memories ──

List<Map<String, dynamic>> loadMemories() {
  final f = File(_memoriesPath);
  if (!f.existsSync()) return [];
  try {
    return (jsonDecode(f.readAsStringSync()) as List).cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
}

void saveMemories(List<Map<String, dynamic>> memories) {
  File(_memoriesPath).writeAsStringSync(jsonEncode(memories));
}

// ── Portrait ──

Map<String, dynamic> loadPortrait() {
  final f = File(_portraitPath);
  if (!f.existsSync()) return {};
  try {
    return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  } catch (_) {
    return {};
  }
}

void savePortrait(Map<String, dynamic> portrait) {
  File(_portraitPath).writeAsStringSync(jsonEncode(portrait));
}

// ── Notes ──

List<Map<String, dynamic>> loadNotes() {
  final f = File(_notesPath);
  if (!f.existsSync()) return [];
  try {
    return (jsonDecode(f.readAsStringSync()) as List).cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
}

void saveNotes(List<Map<String, dynamic>> notes) {
  File(_notesPath).writeAsStringSync(jsonEncode(notes));
}

// ── Souls ──

String? loadActiveSoulId() {
  final f = File(_activeSoulPath);
  if (!f.existsSync()) return null;
  return f.readAsStringSync().trim();
}

void saveActiveSoulId(String id) {
  ensureDirs();
  File(_activeSoulPath).writeAsStringSync(id);
}

void saveSoulFile(String id, Map<String, dynamic> data) {
  final dir = Directory('$_soulsDir/custom');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  File('$_soulsDir/custom/$id.json').writeAsStringSync(jsonEncode(data));
}

void deleteSoulFile(String id) {
  final f = File('$_soulsDir/custom/$id.json');
  if (f.existsSync()) f.deleteSync();
}

// ── Paper Cache ──

String? readPaperMarkdown(String paperId) {
  final f = File('$_papersDir/$paperId/parsed.md');
  if (!f.existsSync()) return null;
  return f.readAsStringSync();
}

String? readPaperTranslation(String paperId) {
  final f = File('$_papersDir/$paperId/translated.md');
  if (!f.existsSync()) return null;
  return f.readAsStringSync();
}

void savePaperMarkdown(String paperId, String content) {
  final dir = Directory('$_papersDir/$paperId');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  File('$_papersDir/$paperId/parsed.md').writeAsStringSync(content);
}

void savePaperTranslation(String paperId, String content) {
  final dir = Directory('$_papersDir/$paperId');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  File('$_papersDir/$paperId/translated.md').writeAsStringSync(content);
}

bool deletePaperCache(String paperId) {
  final dir = Directory('$_papersDir/$paperId');
  if (!dir.existsSync()) return false;
  dir.deleteSync(recursive: true);
  return true;
}

// ── Dirs ──

void ensureDirs() {
  for (final d in [_dataDir, _papersDir, _soulsPresetDir, _soulsCustomDir]) {
    final dir = Directory(d);
    if (!dir.existsSync()) dir.createSync(recursive: true);
  }
  for (final entry in soulPresetDefinitions.entries) {
    final file = File('$_soulsPresetDir/${entry.key}.json');
    if (!file.existsSync()) {
      file.writeAsStringSync(jsonEncode(entry.value));
    }
  }
}
