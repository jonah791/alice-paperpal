import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import '../interfaces/services.dart';

final _log = Logger('AvatarService');

class AvatarService implements IAvatarService {
  late final String _avatarsDir;
  String? _currentPath;

  static const _builtinColors = <int>[
    0xFF1565C0,
    0xFF2E7D32,
    0xFFE65100,
    0xFF6A1B9A,
    0xFFC62828,
  ];

  int colorForName(String name) {
    final hash = name.hashCode.abs();
    return _builtinColors[hash % _builtinColors.length];
  }

  Future<void> init() async {
    final dir = await getApplicationSupportDirectory();
    _avatarsDir = '${dir.path}/avatars';
    final d = Directory(_avatarsDir);
    if (!await d.exists()) await d.create(recursive: true);

    final currentFile = File('$_avatarsDir/current.png');
    if (await currentFile.exists()) {
      _currentPath = currentFile.path;
    }
  }

  String? get currentPath => _currentPath;

  bool get hasCustomAvatar => _currentPath != null;
  String get storageDir => _avatarsDir;

  Future<void> setAvatarFromPath(String sourcePath) async {
    final dest = File('$_avatarsDir/current.png');
    await File(sourcePath).copy(dest.path);
    _currentPath = dest.path;
  }

  Future<void> deleteBuiltin() async {
    final current = File('$_avatarsDir/current.png');
    if (await current.exists()) await current.delete();
    _currentPath = null;
    _log.info('setBuiltin: restored default');
  }
}
