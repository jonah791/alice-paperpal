enum AppThemeMode { system, light, dark }

/// Default theme variant name (alice = original PaperPal theme).
const String defaultThemeVariant = 'alice';

class AppConfig {
  final String defaultProvider;
  final String llmModel;
  final String llmApiBase;
  final String mineruModelVersion;
  final String mineruApiEndpoint;
  final bool autoTranslate;
  final bool enableFormula;
  final bool enableTable;
  final bool forceDarkMode;
  final AppThemeMode themeMode;
  final String themeVariant; // 'blue','cyan','green','orange','red','black','alice'
  final bool amoledMode;
  final double fontSize;
  final int batchSize;
  final int logRetentionDays;

  const AppConfig({
    this.defaultProvider = 'deepseek',
    this.llmModel = 'deepseek-v4-flash',
    this.llmApiBase = 'https://api.deepseek.com',
    this.mineruModelVersion = 'vlm',
    this.mineruApiEndpoint = '',
    this.autoTranslate = true,
    this.enableFormula = true,
    this.enableTable = true,
    this.forceDarkMode = false,
    this.themeMode = AppThemeMode.system,
    this.themeVariant = defaultThemeVariant,
    this.amoledMode = false,
    this.fontSize = 16.0,
    this.batchSize = 50,
    this.logRetentionDays = 7,
  });

  AppConfig copyWith({
    String? defaultProvider,
    String? llmModel,
    String? llmApiBase,
    String? mineruModelVersion,
    String? mineruApiEndpoint,
    bool? autoTranslate,
    bool? enableFormula,
    bool? enableTable,
    bool? forceDarkMode,
    AppThemeMode? themeMode,
    String? themeVariant,
    bool? amoledMode,
    double? fontSize,
    int? batchSize,
    int? logRetentionDays,
  }) {
    return AppConfig(
      defaultProvider: defaultProvider ?? this.defaultProvider,
      llmModel: llmModel ?? this.llmModel,
      llmApiBase: llmApiBase ?? this.llmApiBase,
      mineruModelVersion: mineruModelVersion ?? this.mineruModelVersion,
      mineruApiEndpoint: mineruApiEndpoint ?? this.mineruApiEndpoint,
      autoTranslate: autoTranslate ?? this.autoTranslate,
      enableFormula: enableFormula ?? this.enableFormula,
      enableTable: enableTable ?? this.enableTable,
      forceDarkMode: forceDarkMode ?? this.forceDarkMode,
      themeMode: themeMode ?? this.themeMode,
      themeVariant: themeVariant ?? this.themeVariant,
      amoledMode: amoledMode ?? this.amoledMode,
      fontSize: fontSize ?? this.fontSize,
      batchSize: batchSize ?? this.batchSize,
      logRetentionDays: logRetentionDays ?? this.logRetentionDays,
    );
  }
}
