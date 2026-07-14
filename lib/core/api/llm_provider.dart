import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import '../interfaces/services.dart';
import '../utils/retry_interceptor.dart';

final _log = Logger('LLMProvider');

enum LLMProviderType {
  deepseek,
  openai,
  claude,
}

class LLMConfig {
  final LLMProviderType type;
  final String apiKey;
  final String apiBase;
  final String model;

  const LLMConfig({
    required this.type,
    required this.apiKey,
    this.apiBase = 'https://api.deepseek.com',
    this.model = 'deepseek-v4-flash',
  });
}

class LLMProvider implements ILLMProvider {
  final LLMConfig config;
  late final Dio _dio;

  LLMProvider({required this.config}) {
    _initDio();
  }

  void _initDio() {
    _dio = Dio(BaseOptions(
      baseUrl: config.apiBase,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
      headers: {
        'Authorization': 'Bearer ${config.apiKey}',
        'Content-Type': 'application/json',
      },
    ));
    _dio.interceptors.addAll([
      RetryInterceptor(),
      HttpsInterceptor(),
    ]);
  }

  void reconfigure({required String apiKey, required String apiBase, required String model}) {
    // Use a mutable-like pattern: update via Config's copyWith
    // Since LLMConfig is immutable, we use reflection on the stored config's type
    // but for simplicity, directly reinitialize Dio with new credentials
    _dio = Dio(BaseOptions(
      baseUrl: apiBase,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
    ));
    _dio.interceptors.addAll([
      RetryInterceptor(),
      HttpsInterceptor(),
    ]);
    _log.info('LLMProvider reconfigured: base=$apiBase, model=$model');
  }

  String get endpoint {
    return switch (config.type) {
      LLMProviderType.claude => '/v1/messages',
      _ => '/v1/chat/completions',
    };
  }

  Map<String, dynamic> buildBody(List<Map<String, String>> messages, {int? maxTokens}) {
    return switch (config.type) {
      LLMProviderType.claude => buildClaudeBody(messages, maxTokens: maxTokens),
      _ => {
        'model': config.model,
        'messages': messages,
        'max_tokens': maxTokens ?? 4096,
      },
    };
  }

  Map<String, dynamic> buildClaudeBody(List<Map<String, String>> messages, {int? maxTokens}) {
    String? system;
    final chatMessages = <Map<String, String>>[];

    for (final m in messages) {
      if (m['role'] == 'system') {
        system = m['content'];
      } else {
        chatMessages.add({
          'role': m['role'] == 'assistant' ? 'assistant' : 'user',
          'content': m['content'] ?? '',
        });
      }
    }

    return {
      'model': config.model,
      'max_tokens': maxTokens ?? 4096,
      if (system != null) 'system': system,
      'messages': chatMessages,
    };
  }

  String extractContent(dynamic data) {
    return switch (config.type) {
      LLMProviderType.claude => _safeExtract(data, ['content', 0, 'text']),
      _ => _safeExtract(data, ['choices', 0, 'message', 'content']),
    };
  }

  String _safeExtract(dynamic data, List<dynamic> path) {
    dynamic current = data;
    for (final key in path) {
      if (current is Map) {
        current = current[key];
      } else if (current is List) {
        final idx = key as int;
        if (idx < current.length) {
          current = current[idx];
        } else {
          return '';
        }
      } else {
        return '';
      }
    }
    return (current as String?) ?? '';
  }

  Future<String> chat(List<Map<String, String>> messages, {int? maxTokens}) async {
    try {
      final response = await _dio.post(endpoint, data: buildBody(messages, maxTokens: maxTokens));
      final content = extractContent(response.data);
      _log.info('chat: ${messages.length} msgs, ${content.length} chars');
      return content;
    } on DioException catch (e) {
      _log.warning('chat failed: ${e.response?.statusCode} ${e.message}');
      rethrow;
    }
  }

  Stream<String> chatStream(List<Map<String, String>> messages, {int? maxTokens}) async* {
    try {
      final response = await _dio.post(
        endpoint,
        data: buildBody(messages, maxTokens: maxTokens),
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Accept': 'text/event-stream'},
        ),
      );

      final stream = response.data.stream as Stream<List<int>>;
      final lines = stream.transform(const Utf8Decoder()).transform(const LineSplitter());
      await for (final line in lines) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6);
          if (data == '[DONE]') break;
          try {
            final json = jsonDecode(data);
            final delta = json['choices']?[0]?['delta']?['content'] as String?;
            if (delta != null && delta.isNotEmpty) {
              yield delta;
            }
          } catch (_) {}
        }
      }
    } on DioException catch (e) {
      _log.warning('chatStream failed: ${e.response?.statusCode} ${e.message}');
    }
  }

  Future<String> translate(String text, {String target = '中文'}) async {
    final systemPrompt = '''
你是一个学术论文翻译助手。请将以下学术文本翻译为$target。
规则：
- 保留所有 LaTeX 公式 (\\\$\\\$...\\\$\\\$, \\(...\\), \\[...\\]) 原样不动
- 保留所有引用标记 \\cite{...} 和 [n] 不翻译
- 保留 HTML 表格结构
- 保留代码块缩进
- 同一术语在全文中保持译法一致
- 不要添加额外注释
''';
    return chat([
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': text},
    ]);
  }

  Future<String> summarize(String paperText) async {
    const systemPrompt = '''
你是一个学术论文分析助手。请分析以下论文并输出结构化摘要：

## 一句话总结
(用一句话概括论文核心贡献)

## 研究目标
(论文要解决的问题)

## 方法
(提出的方法或框架)

## 主要结果
(关键实验数据或结论)

## 结论
(作者的核心结论)
''';
    return chat([
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': '论文全文:\n\n$paperText'},
    ]);
  }
}

class HttpsInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final host = options.uri.host;
    if (!host.contains('localhost') && options.uri.scheme != 'https') {
      handler.reject(DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: 'HTTPS is required',
      ));
      return;
    }
    handler.next(options);
  }
}
