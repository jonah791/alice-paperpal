import 'dart:io';
import 'dart:async';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'dio_client.dart';

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

enum MineruTaskState { pending, running, done, failed, converting }

class MineruTask {
  final String id;
  final MineruTaskState state;
  final String? zipUrl;
  final String? errorMessage;
  final int extractedPages;
  final int totalPages;

  const MineruTask({
    required this.id,
    required this.state,
    this.zipUrl,
    this.errorMessage,
    this.extractedPages = 0,
    this.totalPages = 0,
  });

  bool get isTerminal =>
      state == MineruTaskState.done || state == MineruTaskState.failed;
}

class MineruApi {
  final String apiKey;
  final String modelVersion;
  final bool enableFormula;
  final bool enableTable;
  late final Dio _dio;
  late final Dio _downloadDio;

  MineruApi({
    required this.apiKey,
    this.modelVersion = 'vlm',
    this.enableFormula = true,
    this.enableTable = true,
  }) {
    _dio = createApiClient(
      baseUrl: 'https://mineru.net',
      authToken: apiKey,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    );
    _downloadDio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 300),
    ));
  }

  Future<MineruResult> parseUrl(String pdfUrl, {
    String? pageRanges,
    Duration pollTimeout = const Duration(minutes: 10),
  }) async {
    final taskId = await _submitUrlTask(pdfUrl, pageRanges: pageRanges);
    final task = await _pollTask(taskId, timeout: pollTimeout);
    if (task.state == MineruTaskState.failed) {
      throw Exception('Parse failed: ${task.errorMessage}');
    }
    final tempDir = await Directory.systemTemp.createTemp('mineru_');
    return _downloadAndExtract(task.zipUrl!, tempDir.path);
  }

  Future<MineruResult> parseFile(File pdfFile, {
    String? pageRanges,
    Duration pollTimeout = const Duration(minutes: 10),
  }) async {
    final fileName = pdfFile.path.split(Platform.pathSeparator).last;
    final batchId = await _submitFileUpload(pdfFile, pageRanges: pageRanges);
    final task = await _pollBatch(batchId, timeout: pollTimeout);
    if (task.state == MineruTaskState.failed) {
      throw Exception('MinerU parse failed for "$fileName": ${task.errorMessage ?? 'unknown error'}');
    }
    final tempDir = await Directory.systemTemp.createTemp('mineru_');
    return _downloadAndExtract(task.zipUrl!, tempDir.path);
  }

  Future<String> _submitUrlTask(String url, {String? pageRanges}) async {
    final body = <String, dynamic>{
      'url': url,
      'model_version': modelVersion,
      'enable_formula': enableFormula,
      'enable_table': enableTable,
    };
    if (pageRanges != null && pageRanges.isNotEmpty) {
      body['page_ranges'] = pageRanges;
    }

    final response = await _dio.post('/api/v4/extract/task', data: body);
    final data = response.data as Map<String, dynamic>;
    if (data['code'] != 0) {
      throw Exception('MinerU submit failed: ${data['msg']}');
    }
    final taskId = (data['data']['task_id'] as String?) ?? '';
    _log.info('submitUrlTask: task_id=$taskId');
    return taskId;
  }

  Future<String> _submitFileUpload(File pdfFile, {String? pageRanges}) async {
    final body = <String, dynamic>{
      'files': [
        {
          'name': pdfFile.path.split(Platform.pathSeparator).last,
          if (pageRanges != null && pageRanges.isNotEmpty)
            'page_ranges': pageRanges,
        },
      ],
      'model_version': modelVersion,
      'enable_formula': enableFormula,
      'enable_table': enableTable,
    };

    try {
      final response = await _dio.post('/api/v4/file-urls/batch', data: body);
      final data = response.data as Map<String, dynamic>;
      if (data['code'] != 0) {
        throw Exception('MinerU presign failed: ${data['msg']}');
      }
      final batchId = data['data']['batch_id'] as String?;
      if (batchId == null || batchId.isEmpty) {
        throw Exception('MinerU: missing batch_id in response');
      }
      final uploadUrlsRaw = data['data']['file_urls'];
      if (uploadUrlsRaw is! List) {
        throw Exception('MinerU: missing file_urls in response');
      }
      final uploadUrls = List<String>.from(uploadUrlsRaw);
      if (uploadUrls.isEmpty) {
        throw Exception('MinerU: no upload URL returned');
      }

      final uploadUrl = uploadUrls.first;
      final fileBytes = await pdfFile.readAsBytes();
      await _downloadDio.put(
        uploadUrl,
        data: Stream.fromIterable([fileBytes]),
        options: Options(
          headers: {'Content-Type': 'application/octet-stream'},
        ),
      );
      _log.info('submitFileUpload: batch_id=$batchId, file uploaded (${fileBytes.length} bytes)');
      return batchId;
    } on DioException catch (e) {
      final cause = e.error != null ? e.error.toString() : e.message;
      final httpCode = e.response?.statusCode;
      final apiMsg = (e.response?.data is Map) ? (e.response!.data as Map)['msg'] ?? '' : '';
      final detail = [if (apiMsg.isNotEmpty) apiMsg, if (cause != null) cause].join('; ');
      throw Exception('MinerU upload failed${httpCode != null ? ' (HTTP $httpCode)' : ''}: $detail');
    }
  }

  Future<MineruTask> _pollTask(String taskId, {required Duration timeout}) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final response = await _dio.get('/api/v4/extract/task/$taskId');
      final data = response.data as Map<String, dynamic>;
      if (data['code'] != 0) {
        throw Exception('MinerU poll failed: ${data['msg']}');
      }
      final result = data['data'] as Map<String, dynamic>;
      final state = parseState(result['state'] as String? ?? '');
      final task = MineruTask(
        id: taskId,
        state: state,
        zipUrl: result['full_zip_url'] as String?,
        errorMessage: result['err_msg'] as String?,
        extractedPages: result['extract_progress']?['extracted_pages'] as int? ?? 0,
        totalPages: result['extract_progress']?['total_pages'] as int? ?? 0,
      );
      if (task.isTerminal) return task;

      _log.info('pollTask: $taskId state=$state '
          '${task.extractedPages}/${task.totalPages} pages');
      await Future.delayed(const Duration(seconds: 2));
    }
    throw TimeoutException('MinerU poll timed out after ${timeout.inSeconds}s');
  }

  Future<MineruTask> _pollBatch(String batchId, {required Duration timeout}) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final response = await _dio.get('/api/v4/extract-results/batch/$batchId');
        final data = response.data as Map<String, dynamic>;
        if (data['code'] != 0) {
          throw Exception('MinerU batch poll failed: ${data['msg']}');
        }
        final resultsRaw = data['data']['extract_result'];
        final results = (resultsRaw is List) ? resultsRaw : <dynamic>[];
        if (results.isEmpty) {
          _log.info('pollBatch: $batchId no results yet');
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        final r = results.first as Map<String, dynamic>;
        final state = parseState(r['state'] as String? ?? '');
        final task = MineruTask(
          id: batchId,
          state: state,
          zipUrl: r['full_zip_url'] as String?,
          errorMessage: r['err_msg'] as String?,
        );
        if (task.isTerminal) return task;

        _log.info('pollBatch: $batchId state=$state');
        await Future.delayed(const Duration(seconds: 2));
      } on DioException catch (e) {
        _log.warning('pollBatch: $batchId network error, retrying: $e');
        await Future.delayed(const Duration(seconds: 3));
      }
    }
    throw TimeoutException('MinerU batch poll timed out after ${timeout.inSeconds}s');
  }

  MineruTaskState parseState(String s) {
    return switch (s) {
      'done' => MineruTaskState.done,
      'failed' => MineruTaskState.failed,
      'running' => MineruTaskState.running,
      'converting' => MineruTaskState.converting,
      'pending' => MineruTaskState.pending,
      'waiting-file' => MineruTaskState.pending,
      'uploading' => MineruTaskState.running,
      _ => MineruTaskState.pending,
    };
  }

  Future<MineruResult> _downloadAndExtract(String zipUrl, String outputDir) async {
    _log.info('downloadAndExtract: downloading $zipUrl');
    try {
      final response = await _downloadDio.get(
        zipUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data as List<int>;
      _log.info('downloadAndExtract: ${bytes.length} bytes');
      return extractZip(bytes, outputDir);
    } on DioException catch (e) {
      final cause = e.error != null ? e.error.toString() : e.message;
      throw Exception('MinerU download result failed (HTTP ${e.response?.statusCode}): $cause');
    }
  }

  MineruResult extractZip(List<int> bytes, String outputDir) {
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
