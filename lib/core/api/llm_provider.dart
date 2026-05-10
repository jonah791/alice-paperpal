import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

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

class LLMProvider {
  final LLMConfig config;
  late final Dio _dio;

  LLMProvider({required this.config}) {
    _dio = Dio(BaseOptions(
      baseUrl: config.apiBase,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
      headers: {
        'Authorization': 'Bearer ${config.apiKey}',
        'Content-Type': 'application/json',
      },
    ));
    _dio.interceptors.add(_HttpsInterceptor());
  }

  String get _endpoint {
    return switch (config.type) {
      LLMProviderType.claude => '/v1/messages',
      _ => '/v1/chat/completions',
    };
  }

  Map<String, dynamic> _buildBody(List<Map<String, String>> messages) {
    return switch (config.type) {
      LLMProviderType.claude => _buildClaudeBody(messages),
      _ => {
        'model': config.model,
        'messages': messages,
        'max_tokens': 4096,
      },
    };
  }

  Map<String, dynamic> _buildClaudeBody(List<Map<String, String>> messages) {
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
      'max_tokens': 4096,
      if (system != null) 'system': system,
      'messages': chatMessages,
    };
  }

  String _extractContent(dynamic data) {
    return switch (config.type) {
      LLMProviderType.claude => data['content']?.first?['text'] as String? ?? '',
      _ => data['choices']?.first?['message']?['content'] as String? ?? '',
    };
  }

  Future<String> chat(List<Map<String, String>> messages) async {
    try {
      final response = await _dio.post(_endpoint, data: _buildBody(messages));
      final content = _extractContent(response.data);
      _log.info('chat: ${messages.length} msgs, ${content.length} chars');
      return content;
    } on DioException catch (e) {
      _log.warning('chat failed: ${e.response?.statusCode} ${e.message}');
      rethrow;
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

class _HttpsInterceptor extends Interceptor {
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
