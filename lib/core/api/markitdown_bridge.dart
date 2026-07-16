/// Dart ↔ Python MarkItDown bridge.
///
/// Calls [markitdown_bridge.py] as a subprocess to convert various file formats
/// to Markdown. Falls back gracefully if Python or MarkItDown is unavailable.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

final _log = Logger('MarkitdownBridge');

/// Result from the MarkItDown conversion bridge.
class MarkitdownResult {
  final bool success;
  final String markdown;
  final String? error;

  const MarkitdownResult({
    required this.success,
    required this.markdown,
    this.error,
  });
}

/// Bridge to Microsoft MarkItDown Python library.
class MarkitdownBridge {
  final String _scriptPath;

  MarkitdownBridge(this._scriptPath);

  /// Check if Python + MarkItDown are available.
  Future<bool> get isAvailable async {
    try {
      final result = await Process.run(
        Platform.isWindows ? 'where' : 'which',
        ['python3'],
        runInShell: true,
      );
      return result.exitCode == 0;
    } catch (_) {
      try {
        final result = await Process.run(
          Platform.isWindows ? 'where' : 'which',
          ['python'],
          runInShell: true,
        );
        return result.exitCode == 0;
      } catch (_) {
        return false;
      }
    }
  }

  /// Convert a file to Markdown.
  Future<MarkitdownResult> convert(String filePath, {String? type}) async {
    final python = await _findPython();
    if (python == null) {
      return const MarkitdownResult(
        success: false, markdown: '', error: 'Python not found on system',
      );
    }

    final args = [
      _scriptPath, '--input', filePath, '--json',
    ];
    if (type != null) args.addAll(['--type', type]);

    try {
      final result = await Process.run(python, args, runInShell: true);

      if (result.exitCode != 0) {
        final error = (result.stderr as String?)?.trim() ?? 'Unknown error';
        _log.warning('markitdown failed (exit ${result.exitCode}): $error');
        return MarkitdownResult(success: false, markdown: '', error: error);
      }

      final output = (result.stdout as String?)?.trim() ?? '';
      if (output.isEmpty) {
        return const MarkitdownResult(
          success: false, markdown: '', error: 'Empty output',
        );
      }

      try {
        final json = jsonDecode(output) as Map<String, dynamic>;
        if (json['success'] == true) {
          return MarkitdownResult(
            success: true, markdown: json['markdown'] as String? ?? '',
          );
        } else {
          return MarkitdownResult(
            success: false, markdown: '',
            error: json['error'] as String? ?? 'Unknown error',
          );
        }
      } catch (_) {
        return MarkitdownResult(success: true, markdown: output);
      }
    } on ProcessException catch (e) {
      _log.warning('markitdown process error: $e');
      return MarkitdownResult(success: false, markdown: '', error: e.message);
    }
  }

  Future<String?> _findPython() async {
    for (final candidate in ['python3', 'python']) {
      try {
        final r = await Process.run(
          Platform.isWindows ? 'where' : 'which', [candidate],
          runInShell: true,
        );
        if (r.exitCode == 0) return candidate;
      } catch (_) {}
    }
    if (Platform.isWindows) {
      final user = Platform.environment['USERNAME'] ?? '';
      for (final dir in [
        'C:\\Python312\\python.exe', 'C:\\Python311\\python.exe',
        'C:\\Python310\\python.exe',
        'C:\\Users\\$user\\AppData\\Local\\Programs\\Python\\Python312\\python.exe',
        'C:\\Users\\$user\\AppData\\Local\\Programs\\Python\\Python311\\python.exe',
      ]) {
        if (await File(dir).exists()) return dir;
      }
    }
    return null;
  }
}
