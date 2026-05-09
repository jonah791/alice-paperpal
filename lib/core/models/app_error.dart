class AppError {
  final String type;
  final String message;
  final bool retryable;
  final int? statusCode;
  final int failedBatches;
  final int totalBatches;

  const AppError({
    required this.type,
    required this.message,
    this.retryable = false,
    this.statusCode,
    this.failedBatches = 0,
    this.totalBatches = 0,
  });

  factory AppError.network(String message, {int? statusCode, bool retryable = true}) {
    return AppError(type: 'network', message: message, statusCode: statusCode, retryable: retryable);
  }

  factory AppError.api(String code, String message) {
    return AppError(type: 'api', message: '$code: $message');
  }

  factory AppError.parse(int failed, int total) {
    return AppError(type: 'parse', message: '$failed/$total batches failed', failedBatches: failed, totalBatches: total);
  }

  factory AppError.config(String message) {
    return AppError(type: 'config', message: message);
  }

  factory AppError.unknown(String message) {
    return AppError(type: 'unknown', message: message);
  }
}
