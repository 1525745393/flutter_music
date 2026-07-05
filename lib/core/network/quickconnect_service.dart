import 'dart:convert';

import 'package:dio/dio.dart';

/// QuickConnect 解析异常
class QuickConnectException implements Exception {
  const QuickConnectException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// QuickConnect 解析结果
///
/// 包含多个候选地址，调用方需逐一尝试登录，
/// 第一个成功的地址即为最终使用的 baseUrl。
class QuickConnectInfo {
  const QuickConnectInfo({
    required this.candidateUrls,
    this.relayRegion,
    this.controlHost,
  });

  /// 候选 NAS 地址列表（含 https:// 前缀），按优先级排序
  ///
  /// 顺序通常为：直连地址 → control_host 地址 → relay 中继地址
  final List<String> candidateUrls;

  /// 中继区域（如 cn、us、tw 等）
  final String? relayRegion;

  /// 控制服务器主机
  final String? controlHost;
}

/// 群晖 QuickConnect 协议解析服务
///
/// 实现流程：
/// 1. POST 请求 global.quickconnect.cn/Serv.php 获取 server info
/// 2. 从响应中提取 control_host、relay_region、smartdns 等信息
/// 3. 构造多个候选 URL（直连、中继、relay 兜底）
/// 4. 调用方遍历候选 URL 尝试登录，第一个成功即使用
///
/// 自动支持中国区 (.cn) 和全球区 (.to) fallback
class QuickConnectService {
  QuickConnectService();

  /// 中国区全局服务地址
  static const _globalUrlChina = 'https://global.quickconnect.cn/Serv.php';

  /// 全球区全局服务地址
  static const _globalUrlGlobal = 'https://global.quickconnect.to/Serv.php';

  /// 中国区 relay 兜底地址
  static const _relayUrlChina = 'https://relay.quickconnect.cn';

  /// 全球区 relay 兜底地址
  static const _relayUrlGlobal = 'https://relay.quickconnect.to';

  /// 构建 get_server_info 请求 payload
  Map<String, dynamic> _buildServerInfoPayload(String quickConnectId) {
    return {
      'version': 1,
      'command': 'get_server_info',
      'id': 'dsm',
      'serverID': quickConnectId,
      'get_ca_fingerprints': true,
    };
  }

  /// 解析 QuickConnect ID，返回候选 NAS 地址列表
  ///
  /// 自动尝试中国区和全球区服务器
  Future<QuickConnectInfo> resolve(String quickConnectId) async {
    final cleanId = _cleanQuickConnectId(quickConnectId);
    if (cleanId.isEmpty) {
      throw const QuickConnectException('QuickConnect ID 不能为空');
    }

    final preferChina = _preferChinaRegion(quickConnectId);

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 20),
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    try {
      // 按优先级尝试不同区域的全局服务器
      final servers = preferChina
          ? [_globalUrlChina, _globalUrlGlobal]
          : [_globalUrlGlobal, _globalUrlChina];

      final List<String> errorMessages = [];
      QuickConnectInfo? lastResult;

      for (final globalUrl in servers) {
        try {
          lastResult = await _resolveWithServer(
            dio: dio,
            quickConnectId: cleanId,
            globalUrl: globalUrl,
          );
          // 如果拿到了候选地址，直接返回
          if (lastResult.candidateUrls.isNotEmpty) {
            return lastResult;
          }
        } on QuickConnectException catch (e) {
          errorMessages.add(e.message);
          continue;
        } on DioException catch (e) {
          errorMessages.add('连接服务器失败：${e.message ?? e.toString()}');
          continue;
        }
      }

      // 所有服务器都失败，用已知模式构造兜底候选 URL
      final fallbackUrls = _buildFallbackUrls(cleanId, preferChina);
      if (fallbackUrls.isNotEmpty) {
        return QuickConnectInfo(
          candidateUrls: fallbackUrls,
          relayRegion: null,
          controlHost: null,
        );
      }

      final errorMsg = errorMessages.join('；');
      throw QuickConnectException(
        'QuickConnect 解析失败，请检查网络连接或 QuickConnect ID 是否正确。错误详情：$errorMsg',
      );
    } finally {
      dio.close();
    }
  }

  /// 使用指定全局服务器解析
  Future<QuickConnectInfo> _resolveWithServer({
    required Dio dio,
    required String quickConnectId,
    required String globalUrl,
  }) async {
    // POST 请求 global.quickconnect.cn/Serv.php 获取 server info
    final serverInfo = await _requestServerInfo(
      dio,
      globalUrl,
      quickConnectId,
    );

    final env =
        (serverInfo['env'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final controlHost = env['control_host'] as String?;
    final relayRegion = env['relay_region'] as String?;

    // 判断域名后缀（根据请求的全局服务器）
    final isChina = globalUrl.contains('.quickconnect.cn');
    final domainSuffix = isChina ? 'quickconnect.cn' : 'quickconnect.to';

    final candidateUrls = <String>[];

    // 1. Smart DNS 直连地址（优先级最高）
    final smartDns =
        (serverInfo['smartdns'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final directHost = smartDns['host'] as String?;
    if (directHost != null && directHost.isNotEmpty) {
      candidateUrls.add('https://$directHost');
    }

    // 2. 局域网地址
    final lanList = smartDns['lan'] as List<dynamic>?;
    if (lanList != null) {
      for (final lan in lanList) {
        if (lan is String && lan.isNotEmpty) {
          candidateUrls.add('https://$lan');
        }
      }
    }

    // 3. 基于 relay_region 构造的中继地址
    if (relayRegion != null && relayRegion.isNotEmpty) {
      candidateUrls.add(
        'https://$quickConnectId.$relayRegion.$domainSuffix',
      );
    }

    // 4. control_host 直连地址
    if (controlHost != null && controlHost.isNotEmpty) {
      // control_host 可能带端口（如 host:port），也可能不带
      if (!candidateUrls.contains('https://$controlHost')) {
        candidateUrls.add('https://$controlHost');
      }
    }

    // 5. relay 兜底地址
    final relayUrl = isChina ? _relayUrlChina : _relayUrlGlobal;
    candidateUrls.add('$relayUrl/$quickConnectId');

    // 去重
    final uniqueUrls = candidateUrls.toSet().toList();

    return QuickConnectInfo(
      candidateUrls: uniqueUrls,
      relayRegion: relayRegion,
      controlHost: controlHost,
    );
  }

  /// 构造兜底候选 URL（当 API 请求失败时使用）
  ///
  /// 基于已知 QuickConnect URL 模式构造
  List<String> _buildFallbackUrls(String quickConnectId, bool preferChina) {
    final urls = <String>[];

    if (preferChina) {
      // 中国区常见 relay_region
      for (final region in ['cn', 'cnc']) {
        urls.add('https://$quickConnectId.$region.quickconnect.cn');
      }
      // relay 兜底
      urls.add('$_relayUrlChina/$quickConnectId');
    }

    // 全球区兜底
    for (final region in ['us', 'tw', 'de']) {
      urls.add('https://$quickConnectId.$region.quickconnect.to');
    }

    return urls;
  }

  /// POST 请求 server info
  ///
  /// 使用 jsonEncode 确保发送真正的 JSON body
  Future<Map<String, dynamic>> _requestServerInfo(
    Dio dio,
    String globalUrl,
    String quickConnectId,
  ) async {
    final response = await dio.post<dynamic>(
      globalUrl,
      data: jsonEncode(_buildServerInfoPayload(quickConnectId)),
      options: Options(
        headers: {'Content-Type': 'application/json'},
        responseType: ResponseType.json,
      ),
    );
    return _parseResponse(response.data, 'get_server_info');
  }

  /// 校验响应并返回数据部分
  Map<String, dynamic> _parseResponse(
    dynamic responseData,
    String command,
  ) {
    // 响应可能是 String 类型（HTML 或 JSON 字符串）
    dynamic data = responseData;
    if (responseData is String) {
      final trimmed = responseData.trim();
      if (trimmed.isEmpty) {
        throw QuickConnectException('QuickConnect $command 响应为空');
      }
      // 如果看起来像 JSON，尝试解析
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        try {
          data = jsonDecode(trimmed);
        } catch (_) {
          // 解析失败，保持原样
        }
      } else {
        // HTML 页面
        if (trimmed.contains('<html') || trimmed.contains('<title')) {
          throw QuickConnectException(
            'QuickConnect $command 返回 HTML 页面，请检查网络代理或 DNS 设置',
          );
        }
        throw QuickConnectException(
          'QuickConnect $command 响应格式异常: ${trimmed.substring(0, trimmed.length > 100 ? 100 : trimmed.length)}',
        );
      }
    }

    // 响应可能是单个对象，也可能是数组（取第一个）
    final Map<String, dynamic> item;
    if (data is List && data.isNotEmpty) {
      item = data[0] is Map<String, dynamic>
          ? data[0] as Map<String, dynamic>
          : <String, dynamic>{};
    } else if (data is Map<String, dynamic>) {
      item = data;
    } else {
      throw QuickConnectException('QuickConnect $command 响应格式异常');
    }

    if (item.isEmpty) {
      throw QuickConnectException('QuickConnect $command 响应为空');
    }

    final errno = item['errno'];
    if (errno != null && errno != 0) {
      final errinfo = item['errinfo'] ?? '';
      final errMsg = errinfo.toString().trim();
      throw QuickConnectException(
        'QuickConnect $command 失败（错误码：$errno${errMsg.isNotEmpty ? ' $errMsg' : ''}）',
      );
    }

    return item;
  }

  /// 判断输入是否偏向中国区
  static bool _preferChinaRegion(String input) {
    final lower = input.trim().toLowerCase();
    if (lower.contains('.quickconnect.cn') ||
        lower.contains('quickconnect.cn/')) {
      return true;
    }
    // 默认优先尝试中国区
    return true;
  }

  /// 清理 QuickConnect ID 输入
  ///
  /// 支持以下输入格式：
  /// - `mynas`
  /// - `mynas.quickconnect.to`
  /// - `mynas.quickconnect.cn`
  /// - `https://mynas.quickconnect.to`
  /// - `https://mynas.cnc.quickconnect.cn`
  /// - `https://quickconnect.to/mynas` (Web 门户格式)
  /// - `https://quickconnect.cn/mynas` (中国区 Web 门户格式)
  static String _cleanQuickConnectId(String input) {
    var result = input.trim().toLowerCase();

    // 去掉协议前缀
    if (result.startsWith('https://')) {
      result = result.substring(8);
    } else if (result.startsWith('http://')) {
      result = result.substring(7);
    }

    // 去掉端口
    final colonIndex = result.indexOf(':');
    if (colonIndex > 0) {
      result = result.substring(0, colonIndex);
    }

    // 检查是否是 Web 门户格式：quickconnect.to/{id} 或 quickconnect.cn/{id}
    if (result.startsWith('quickconnect.to/')) {
      final pathPart = result.substring('quickconnect.to/'.length);
      final slashIndex = pathPart.indexOf('/');
      return slashIndex > 0 ? pathPart.substring(0, slashIndex) : pathPart;
    }
    if (result.startsWith('quickconnect.cn/')) {
      final pathPart = result.substring('quickconnect.cn/'.length);
      final slashIndex = pathPart.indexOf('/');
      return slashIndex > 0 ? pathPart.substring(0, slashIndex) : pathPart;
    }

    // 去掉路径（对于其他格式）
    final slashIndex = result.indexOf('/');
    if (slashIndex > 0) {
      result = result.substring(0, slashIndex);
    }

    // 提取 ID：如果是 xxx.quickconnect.to 或 xxx.quickconnect.cn 格式，取第一段
    if (result.endsWith('.quickconnect.to') ||
        result.endsWith('.quickconnect.cn')) {
      final parts = result.split('.');
      if (parts.length >= 3) {
        result = parts.first;
      }
    }

    return result;
  }

  /// 判断输入是否是 QuickConnect ID
  ///
  /// 规则：
  /// - 不以 http:// 或 https:// 开头
  /// - 或者包含 quickconnect.to 或 quickconnect.cn
  static bool isQuickConnectId(String input) {
    final trimmed = input.trim().toLowerCase();
    if (trimmed.isEmpty) return false;

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed.contains('quickconnect.to') ||
          trimmed.contains('quickconnect.cn');
    }

    return true;
  }
}
