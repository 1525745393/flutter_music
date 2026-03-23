import 'package:dio/dio.dart';

import 'dio_client.dart';
import 'synology_api_exception.dart';

/// 群晖 API 基类，负责：
/// - 复用同一套 Dio 配置
/// - 统一空响应校验
abstract class SynologyBaseApi {
  SynologyBaseApi({required String serverUrl})
    : serverUrl = _normalizeServerUrl(serverUrl),
      dio = DioClient(baseUrl: _normalizeServerUrl(serverUrl)).dio;

  final String serverUrl;
  final Dio dio;

  Map<String, dynamic> requireBody(Map<String, dynamic>? body) {
    if (body == null) {
      throw const SynologyApiException('接口响应为空');
    }
    return body;
  }

  String buildAbsoluteUrl(String path, Map<String, String> queryParameters) {
    final base = Uri.parse(serverUrl);
    final uri = base.resolve(path).replace(queryParameters: queryParameters);
    return uri.toString();
  }

  static String _normalizeServerUrl(String value) {
    if (value.endsWith('/')) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }
}
