import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';
import '../models/config.dart';

final _log = Logger('ConfigService');

class ConfigService {
  static const _keyLlmApiKey = 'llm_api_key';
  static const _keyMineruApiKey = 'mineru_api_key';
  static const _keyLlmApiBase = 'llm_api_base';
  static const _keyLlmModel = 'llm_model';
  static const _keyMineruEndpoint = 'mineru_api_endpoint';

  AppConfig _config = const AppConfig();
  SharedPreferences? _prefs;

  AppConfig get config => _config;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _config = AppConfig(
      llmApiBase: _prefs!.getString(_keyLlmApiBase) ?? 'https://api.deepseek.com',
      llmModel: _prefs!.getString(_keyLlmModel) ?? 'deepseek-v4-flash',
      mineruApiEndpoint: _prefs!.getString(_keyMineruEndpoint) ?? '',
    );
    _log.info('Config loaded');
  }

  Future<void> saveLlmApiKey(String key) async {
    await _prefs?.setString(_keyLlmApiKey, key);
    _log.info('LLM API key saved');
  }

  Future<String?> readLlmApiKey() async {
    return _prefs?.getString(_keyLlmApiKey);
  }

  bool get hasLlmApiKey {
    final key = _prefs?.getString(_keyLlmApiKey);
    return key != null && key.isNotEmpty;
  }

  Future<void> saveMineruApiKey(String key) async {
    await _prefs?.setString(_keyMineruApiKey, key);
    _log.info('MinerU API key saved');
  }

  Future<String?> readMineruApiKey() async {
    return _prefs?.getString(_keyMineruApiKey);
  }

  Future<void> updateConfig(AppConfig config) async {
    _config = config;
    await _prefs?.setString(_keyLlmApiBase, config.llmApiBase);
    await _prefs?.setString(_keyLlmModel, config.llmModel);
    await _prefs?.setString(_keyMineruEndpoint, config.mineruApiEndpoint);
    _log.info('Config updated: provider=${config.defaultProvider}, '
        'model=${config.llmModel}');
  }
}
