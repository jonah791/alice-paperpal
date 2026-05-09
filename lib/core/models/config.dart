import 'package:flutter/material.dart' as m;

enum AppThemeMode { system, light, dark }

extension AppThemeModeX on AppThemeMode {
  m.ThemeMode toFlutterThemeMode() {
    return switch (this) {
      AppThemeMode.system => m.ThemeMode.system,
      AppThemeMode.light => m.ThemeMode.light,
      AppThemeMode.dark => m.ThemeMode.dark,
    };
  }
}

class AppConfig {
  final String defaultProvider;
  final String llmModel;
  final String llmApiBase;
  final String mineruApiEndpoint;
  final bool autoTranslate;
  final bool forceDarkMode;
  final AppThemeMode themeMode;
  final double fontSize;
  final int batchSize;
  final int logRetentionDays;

  const AppConfig({
    this.defaultProvider = 'deepseek',
    this.llmModel = 'deepseek-v4-flash',
    this.llmApiBase = 'https://api.deepseek.com',
    this.mineruApiEndpoint = '',
    this.autoTranslate = true,
    this.forceDarkMode = false,
    this.themeMode = AppThemeMode.system,
    this.fontSize = 16.0,
    this.batchSize = 50,
    this.logRetentionDays = 7,
  });

  AppConfig copyWith({
    String? defaultProvider,
    String? llmModel,
    String? llmApiBase,
    String? mineruApiEndpoint,
    bool? autoTranslate,
    bool? forceDarkMode,
    AppThemeMode? themeMode,
    double? fontSize,
    int? batchSize,
    int? logRetentionDays,
  }) {
    return AppConfig(
      defaultProvider: defaultProvider ?? this.defaultProvider,
      llmModel: llmModel ?? this.llmModel,
      llmApiBase: llmApiBase ?? this.llmApiBase,
      mineruApiEndpoint: mineruApiEndpoint ?? this.mineruApiEndpoint,
      autoTranslate: autoTranslate ?? this.autoTranslate,
      forceDarkMode: forceDarkMode ?? this.forceDarkMode,
      themeMode: themeMode ?? this.themeMode,
      fontSize: fontSize ?? this.fontSize,
      batchSize: batchSize ?? this.batchSize,
      logRetentionDays: logRetentionDays ?? this.logRetentionDays,
    );
  }
}
