import 'dart:convert';

import 'package:dio/dio.dart';

import 'dio_client.dart';
import 'synology_api_exception.dart';
import 'synology_api_info.dart';

/// 群晖 API 基类，负责：
/// - 复用同一套 Dio 配置
/// - 统一响应校验和错误处理
/// - 提供 API Version 自适应能力
abstract class SynologyBaseApi {
  SynologyBaseApi({
    required String serverUrl,
    SynologyApiInfo? apiInfo,
    String? synoToken,
  })  : serverUrl = _normalizeServerUrl(serverUrl),
        dio = DioClient(baseUrl: _normalizeServerUrl(serverUrl)).dio,
        _apiInfo = apiInfo,
        synoToken = synoToken;

  final String serverUrl;
  final Dio dio;

  /// CSRF 防护令牌，登录后从响应中获取
  ///
  /// 官方文档：version 6+ 支持 SynoToken，后续所有请求都应携带
  final String? synoToken;

  /// API 元信息（可能为 null，此时使用硬编码默认值）
  final SynologyApiInfo? _apiInfo;

  /// 获取指定 API 的推荐版本号（字符串格式）
  ///
  /// 如果 [_apiInfo] 可用，从缓存读取；否则使用 [fallbackVersion]
  String resolveApiVersion(String apiName, String fallbackVersion) {
    final info = _apiInfo;
    if (info == null || !info.isLoaded) return fallbackVersion;
    final fallback = int.tryParse(fallbackVersion) ?? 1;
    return info.getApiVersion(apiName, fallback).toString();
  }

  /// 获取指定 API 的请求路径
  ///
  /// 如果 [_apiInfo] 可用，从缓存读取；否则使用 [fallbackPath]
  String resolveApiPath(String apiName, String fallbackPath) {
    final info = _apiInfo;
    if (info == null || !info.isLoaded) return fallbackPath;
    return info.getApiPath(apiName, fallbackPath);
  }

  /// 校验并解析响应数据为 Map
  ///
  /// 会检查 HTTP 状态码和响应格式，抛出包含详细信息的异常。
  /// 支持部分接口返回的字符串格式 JSON（AudioStation 部分接口特性）。
  Map<String, dynamic> requireBody(Response<dynamic> response) {
    final statusCode = response.statusCode;
    final body = response.data;

    if (body == null) {
      throw SynologyApiException(
        '接口响应为空',
        statusCode: statusCode,
      );
    }

    // 处理字符串类型响应
    if (body is String) {
      if (body.contains('<html') || body.contains('<!DOCTYPE')) {
        throw SynologyApiException(
          '服务器返回了 HTML 页面，请检查服务器地址或路径是否正确',
          statusCode: statusCode,
          responseBody: body,
        );
      }
      // 尝试解析为 JSON（AudioStation 部分接口返回字符串格式的 JSON）
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        throw SynologyApiException(
          '响应 JSON 格式异常：${decoded.runtimeType}',
          statusCode: statusCode,
          responseBody: body,
        );
      } on FormatException catch (e) {
        throw SynologyApiException(
          '响应解析失败：$e',
          statusCode: statusCode,
          responseBody: body,
        );
      }
    }

    if (body is! Map<String, dynamic>) {
      throw SynologyApiException(
        '响应类型错误：${body.runtimeType}',
        statusCode: statusCode,
        responseBody: body,
      );
    }

    // HTTP 状态码非 200 但响应是 JSON 时，仍然返回 body
    // 由业务层根据 success 字段和 error.code 处理
    return body;
  }

  /// 构造完整的请求 URL，自动带上 SynoToken（如果有）
  String buildAbsoluteUrl(String path, Map<String, String> queryParameters) {
    final base = Uri.parse(serverUrl);
    final params = Map<String, String>.from(queryParameters);
    // 官方文档：SynoToken 首字母大写，用于 CSRF 防护
    if (synoToken != null && synoToken!.isNotEmpty) {
      params['SynoToken'] = synoToken!;
    }
    final uri = base.resolve(path).replace(queryParameters: params);
    return uri.toString();
  }

  static String _normalizeServerUrl(String value) {
    if (value.endsWith('/')) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }
}
