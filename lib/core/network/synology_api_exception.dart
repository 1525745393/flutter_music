/// 群晖 API 异常类
///
/// 包含详细的错误信息，便于问题定位。
class SynologyApiException implements Exception {
  const SynologyApiException(
    this.message, {
    this.statusCode,
    this.responseBody,
  });

  /// 错误消息
  final String message;

  /// HTTP 状态码（如有）
  final int? statusCode;

  /// 原始响应体（如有，用于调试）
  final dynamic responseBody;

  @override
  String toString() {
    final buffer = StringBuffer(message);
    if (statusCode != null) {
      buffer.write('（HTTP $statusCode）');
    }
    return buffer.toString();
  }
}
