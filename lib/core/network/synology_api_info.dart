import 'package:dio/dio.dart';

import 'dio_client.dart';
import 'synology_api_constants.dart';
import 'synology_api_exception.dart';
import 'synology_base_api.dart';

/// 单个 API 的元信息
class ApiMeta {
  const ApiMeta({
    required this.path,
    required this.maxVersion,
    required this.minVersion,
    this.requestFormat,
  });

  final String path;
  final int maxVersion;
  final int minVersion;

  /// 请求格式：JSON 或其他
  final String? requestFormat;

  /// 获取推荐使用的版本号（取 maxVersion）
  int get recommendedVersion => maxVersion;
}

/// SYNO.API.Info 查询服务
///
/// 用于获取所有 DSM API 的元信息（路径、支持版本范围等），
/// 是 DSM 6/7 版本自适应的标准做法。
///
/// 参考：File Station API Guide 中的 SYNO.API.Info 章节
class SynologyApiInfo extends SynologyBaseApi {
  SynologyApiInfo({required super.serverUrl});

  /// 缓存的 API 元信息（key 为 API 名称）
  final Map<String, ApiMeta> _cache = {};

  /// 是否已完成查询
  bool _loaded = false;

  /// 是否已完成查询
  bool get isLoaded => _loaded;

  /// 查询所有 API 信息并缓存
  ///
  /// 如果指定 [queryApis]，则只查询指定的 API；否则查询全部
  Future<void> load({List<String>? queryApis}) async {
    final query = queryApis == null || queryApis.isEmpty
        ? 'all'
        : queryApis.join(',');

    final response = await dio.get(
      SynologyApiConstants.apiInfoPath,
      queryParameters: {
        'api': SynologyApiConstants.apiInfoApiName,
        'version': 1,
        'method': 'query',
        'query': query,
      },
    );

    final body = requireBody(response);
    if (body['success'] != true) {
      throw SynologyApiException(
        '查询 API Info 失败',
        errorCode: (body['error'] as Map<String, dynamic>?)?['code'] as int?,
      );
    }

    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) return;

    data.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        _cache[key] = ApiMeta(
          path: value['path'] as String? ?? '',
          maxVersion: (value['maxVersion'] as num?)?.toInt() ?? 1,
          minVersion: (value['minVersion'] as num?)?.toInt() ?? 1,
          requestFormat: value['requestFormat'] as String?,
        );
      }
    });

    _loaded = true;
  }

  /// 获取指定 API 的元信息
  ///
  /// 如果缓存中没有，返回 null；调用方应使用硬编码默认值作为 fallback
  ApiMeta? getApiMeta(String apiName) {
    return _cache[apiName];
  }

  /// 获取指定 API 的推荐版本号
  ///
  /// 如果缓存中没有，返回 [fallbackVersion]
  int getApiVersion(String apiName, int fallbackVersion) {
    final meta = _cache[apiName];
    if (meta == null) return fallbackVersion;
    return meta.recommendedVersion;
  }

  /// 获取指定 API 的路径
  ///
  /// 如果缓存中没有，返回 [fallbackPath]
  String getApiPath(String apiName, String fallbackPath) {
    final meta = _cache[apiName];
    if (meta == null || meta.path.isEmpty) return fallbackPath;
    // API Info 返回的 path 不带 /webapi/ 前缀，需要补上
    if (meta.path.startsWith('/')) {
      return '/webapi${meta.path}';
    }
    return '/webapi/${meta.path}';
  }
}
