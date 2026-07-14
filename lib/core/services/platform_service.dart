import 'dart:io' show Platform, Process;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/windows_encryption.dart' as dpapi;

abstract class PlatformService {
  Future<String> encrypt(String plainText);
  Future<String?> decrypt(String cipherText);
  Future<void> openFile(String path);
  Future<String> get dataPath;
  bool get isDesktop;
  bool get isAndroid;
}

class DesktopPlatformService implements PlatformService {
  @override
  Future<String> encrypt(String plainText) async => dpapi.encrypt(plainText) ?? plainText;

  @override
  Future<String?> decrypt(String cipherText) async => dpapi.decrypt(cipherText);

  @override
  Future<void> openFile(String path) async {
    await Process.run('cmd', ['/c', 'start', '', path], runInShell: true);
  }

  @override
  Future<String> get dataPath async {
    final dir = await getApplicationSupportDirectory();
    return dir.path;
  }

  @override
  bool get isDesktop => true;

  @override
  bool get isAndroid => false;
}

class AndroidPlatformService implements PlatformService {
  final _storage = const FlutterSecureStorage();

  @override
  Future<String> encrypt(String plainText) async {
    await _storage.write(key: 'api_key', value: plainText);
    return plainText;
  }

  @override
  Future<String?> decrypt(String cipherText) async {
    return await _storage.read(key: 'api_key') ?? cipherText;
  }

  @override
  Future<void> openFile(String path) async {
    await OpenFilex.open(path);
  }

  @override
  Future<String> get dataPath async {
    final dir = await getApplicationSupportDirectory();
    return dir.path;
  }

  @override
  bool get isDesktop => false;

  @override
  bool get isAndroid => true;
}

PlatformService createPlatformService() {
  if (Platform.isAndroid) {
    return AndroidPlatformService();
  }
  return DesktopPlatformService();
}
