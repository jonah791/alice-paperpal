import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';
import '../models/config.dart';
import '../utils/windows_encryption.dart' as dpapi;
import '../interfaces/services.dart';
import 'platform_service.dart';

final _log = Logger('ConfigService');

class ConfigService implements IConfigService {
  static const _keyLlmApiKey = 'llm_api_key';
  static const _keyMineruApiKey = 'mineru_api_key';
  static const _keyLlmApiBase = 'llm_api_base';
  static const _keyLlmModel = 'llm_model';
  static const _keyMineruModelVersion = 'mineru_model_version';
  static const _keyMineruEndpoint = 'mineru_api_endpoint';
  static const _keyEnableFormula = 'enable_formula';
  static const _keyEnableTable = 'enable_table';

  final PlatformService _platform;
  AppConfig _config = const AppConfig();
  SharedPreferences? _prefs;

  ConfigService(this._platform);

  AppConfig get config => _config;
  PlatformService get platform => _platform;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _config = AppConfig(
      llmApiBase: _prefs!.getString(_keyLlmApiBase) ?? 'https://api.deepseek.com',
      llmModel: _prefs!.getString(_keyLlmModel) ?? 'deepseek-v4-flash',
      mineruModelVersion: _prefs!.getString(_keyMineruModelVersion) ?? 'vlm',
      mineruApiEndpoint: _prefs!.getString(_keyMineruEndpoint) ?? '',
      enableFormula: _prefs!.getBool(_keyEnableFormula) ?? true,
      enableTable: _prefs!.getBool(_keyEnableTable) ?? true,
    );
    _log.info('Config loaded');
  }

  Future<void> saveLlmApiKey(String key) async {
    final encrypted = await _platform.encrypt(key);
    await _prefs?.setString(_keyLlmApiKey, encrypted);
    _log.info('LLM API key saved');
  }

  Future<String?> readLlmApiKey() async {
    final stored = _prefs?.getString(_keyLlmApiKey);
    if (stored == null || stored.isEmpty) return null;

    final decrypted = await _platform.decrypt(stored);
    if (decrypted != null && decrypted.isNotEmpty && decrypted != stored) return decrypted;

    return stored;
  }

  bool get hasLlmApiKey {
    final key = _prefs?.getString(_keyLlmApiKey);
    return key != null && key.isNotEmpty;
  }

  Future<void> saveMineruApiKey(String key) async {
    final encrypted = await _platform.encrypt(key);
    await _prefs?.setString(_keyMineruApiKey, encrypted);
    _log.info('MinerU API key saved');
  }

  Future<String?> readMineruApiKey() async {
    final stored = _prefs?.getString(_keyMineruApiKey);
    if (stored == null || stored.isEmpty) return null;

    final decrypted = await _platform.decrypt(stored);
    if (decrypted != null && decrypted.isNotEmpty && decrypted != stored) return decrypted;

    return stored;
  }

  Future<void> updateConfig(AppConfig config) async {
    _config = config;
    await _prefs?.setString(_keyLlmApiBase, config.llmApiBase);
    await _prefs?.setString(_keyLlmModel, config.llmModel);
    await _prefs?.setString(_keyMineruModelVersion, config.mineruModelVersion);
    await _prefs?.setString(_keyMineruEndpoint, config.mineruApiEndpoint);
    await _prefs?.setBool(_keyEnableFormula, config.enableFormula);
    await _prefs?.setBool(_keyEnableTable, config.enableTable);
    _log.info('Config updated: provider=${config.defaultProvider}, model=${config.llmModel}');
  }
}
