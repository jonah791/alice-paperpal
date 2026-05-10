import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';

final _logDirLock = Lock();
late final Directory _logDir;

Future<void> initLogger() async {
  final appDir = await getApplicationSupportDirectory();
  _logDir = Directory('${appDir.path}/logs');
  if (!await _logDir.exists()) {
    await _logDir.create(recursive: true);
  }

  _cleanOldLogs();

  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen(_writeLogEntry);
}

void _cleanOldLogs() {
  final files = _logDir.listSync().whereType<File>();
  final cutoff = DateTime.now().subtract(const Duration(days: 7));
  for (final file in files) {
    if (file.path.endsWith('.log')) {
      final stat = file.statSync();
      if (stat.changed.isBefore(cutoff)) {
        file.deleteSync();
      }
    }
  }
}

String _sanitize(String message) {
  return message
      .replaceAllMapped(
        RegExp(r'(api[_-]?key|apikey|token|authorization)[=:]\s*\S+',
            caseSensitive: false),
        (m) => '${m.group(1)}=***',
      )
      .replaceAllMapped(
        RegExp(r'(sk-|ds-)[a-zA-Z0-9]{16,}'),
        (m) => '${m.group(0)!.substring(0, 3)}***',
      );
}

Future<void> _writeLogEntry(LogRecord record) async {
  await _logDirLock.synchronized(() async {
    final date = DateTime.now();
    final fileName = 'paperwise_${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}.log';
    final file = File('${_logDir.path}/$fileName');
    final line = '${date.toIso8601String()} [${record.level.name}] ${record.loggerName}: ${_sanitize(record.message)}\n';
    await file.writeAsString(line, mode: FileMode.append);
  });
}

final log = Logger('paperpal');
