import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';

final _log = Logger('AvatarService');

class AvatarService {
  late final String _avatarsDir;
  String? _currentPath;

  static const _builtinColors = [
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFFE65100),
    Color(0xFF6A1B9A),
    Color(0xFFC62828),
  ];

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

  Future<void> pickFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 256, maxHeight: 256);
    if (image == null) return;

    final dest = File('$_avatarsDir/current.png');
    await File(image.path).copy(dest.path);
    _currentPath = dest.path;
    _log.info('pickFromGallery: avatar updated');
  }

  Future<void> setBuiltin(int index) async {
    // Remove custom avatar if exists
    final current = File('$_avatarsDir/current.png');
    if (await current.exists()) await current.delete();
    _currentPath = null;
    _log.info('setBuiltin: index=$index');
  }

  bool get hasCustomAvatar => _currentPath != null;

  Widget buildDefaultAvatar(String name, double size) {
    final char = name.isNotEmpty ? name.characters.first : '?';
    final hash = name.hashCode.abs();
    final color = _builtinColors[hash % _builtinColors.length];

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: color,
      child: Text(
        char,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.45,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
