import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

final _log = Logger('MineruApi');

class MineruResult {
  final String markdown;
  final List<String> imagePaths;
  final String contentListJson;

  const MineruResult({
    required this.markdown,
    this.imagePaths = const [],
    this.contentListJson = '',
  });
}

class MineruApi {
  final String baseUrl;
  final String? apiKey;
  late final Dio _dio;

  MineruApi({required this.baseUrl, this.apiKey}) {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 300),
      sendTimeout: const Duration(seconds: 120),
      headers: {
        if (apiKey != null && apiKey!.isNotEmpty)
          'Authorization': 'Bearer $apiKey',
      },
    ));
    _dio.interceptors.add(_HttpsInterceptor());
  }

  Future<MineruResult> parsePdf({
    required File pdfFile,
    required String outputDir,
    int startPage = 0,
    int endPage = 99999,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        pdfFile.path,
        filename: pdfFile.path.split(Platform.pathSeparator).last,
      ),
      'start_page_id': startPage.toString(),
      'end_page_id': endPage.toString(),
    });

    final url = baseUrl.endsWith('/file_parse')
        ? baseUrl
        : '$baseUrl/file_parse';

    try {
      final response = await _dio.post(
        url,
        data: formData,
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data as List<int>;
      _log.info('parsePdf: pages=$startPage-$endPage, zip=${bytes.length} bytes');

      return _extractZip(bytes, outputDir);
    } on DioException catch (e) {
      _log.warning('parsePdf failed: pages=$startPage-$endPage, '
          '${e.response?.statusCode} ${e.message}');
      rethrow;
    }
  }

  MineruResult _extractZip(List<int> bytes, String outputDir) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final outDir = Directory(outputDir);
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }

    String? markdown;
    String? contentListJson;
    final imagePaths = <String>[];

    for (final file in archive) {
      if (file.isFile) {
        final name = file.name;
        final data = file.content as List<int>;

        if (name.endsWith('.md') && !name.startsWith('.')) {
          markdown = String.fromCharCodes(data);
        } else if (name.endsWith('_content_list.json') || name.endsWith('content_list_v2.json')) {
          contentListJson = String.fromCharCodes(data);
        } else if (RegExp(r'images?/.*\.(png|jpg|jpeg|gif|svg)$', caseSensitive: false).hasMatch(name)) {
          final destPath = '$outputDir/$name';
          final destFile = File(destPath);
          destFile.parent.createSync(recursive: true);
          destFile.writeAsBytesSync(data);
          imagePaths.add(destPath);
        }
      }
    }

    return MineruResult(
      markdown: markdown ?? '',
      imagePaths: imagePaths,
      contentListJson: contentListJson ?? '',
    );
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
        error: 'HTTPS is required for security',
      ));
      return;
    }
    handler.next(options);
  }
}
