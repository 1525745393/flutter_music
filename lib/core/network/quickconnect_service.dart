import 'dart:convert';

import 'package:dio/dio.dart';

/// QuickConnect 解析异常
class QuickConnectException implements Exception {
  const QuickConnectException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// QuickConnect 区域
enum QuickConnectRegion {
  /// 中国区 (.quickconnect.cn)
  china,

  /// 全球区 (.quickconnect.to)
  global,
}

/// QuickConnect 解析结果
class QuickConnectInfo {
  const QuickConnectInfo({
    required this.serverUrl,
    required this.relayRegion,
    required this.controlHost,
    required this.area,
    this.directHost,
    this.lanHosts = const [],
  });

  /// 最终可访问的 NAS 地址（含 https:// 前缀）
  final String serverUrl;

  /// 中继区域（如 cnc、cnx、us、tw 等）
  final String relayRegion;

  /// 控制服务器主机
  final String controlHost;

  /// 所属区域（中国/全球）
  final QuickConnectRegion area;

  /// 外部直连地址（Smart DNS）
  final String? directHost;

  /// 局域网直连地址列表
  final List<String> lanHosts;

  /// 域名后缀
  String get domainSuffix =>
      area == QuickConnectRegion.china ? 'quickconnect.cn' : 'quickconnect.to';
}

/// 群晖 QuickConnect 协议解析服务
///
/// 基于抓包分析的真实 API 格式实现
/// 支持中国区和全球区自动切换
/// 支持 Smart DNS 直连地址获取
class QuickConnectService {
  QuickConnectService();

  /// 中国区全局服务地址
  static const _globalUrlChina = 'https://global.quickconnect.cn/Serv.php';

  /// 全球区全局服务地址
  static const _globalUrlGlobal = 'https://global.quickconnect.to/Serv.php';

  /// 域名后缀
  static const _domainChina = 'quickconnect.cn';
  static const _domainGlobal = 'quickconnect.to';

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

  /// 构建 request_tunnel 请求 payload
  Map<String, dynamic> _buildTunnelPayload(String quickConnectId) {
    return {
      'version': 1,
      'command': 'request_tunnel',
      'id': 'dsm',
      'serverID': quickConnectId,
      'platform': 'Android',
    };
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
        // HTML 页面，提取可能的错误信息
        if (trimmed.contains('<html') || trimmed.contains('<title')) {
          throw QuickConnectException(
            'QuickConnect $command 返回 HTML 页面，请检查网络代理或 DNS 设置',
          );
        }
        throw QuickConnectException('QuickConnect $command 响应格式异常');
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

  /// 解析 QuickConnect ID，返回 NAS 可访问地址
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
      final servers = preferChina
          ? [
              (_globalUrlChina, QuickConnectRegion.china),
              (_globalUrlGlobal, QuickConnectRegion.global),
            ]
          : [
              (_globalUrlGlobal, QuickConnectRegion.global),
              (_globalUrlChina, QuickConnectRegion.china),
            ];

      final List<String> errorMessages = [];

      for (final server in servers) {
        try {
          final result = await _resolveWithServer(
            dio: dio,
            quickConnectId: cleanId,
            globalUrl: server.$1,
            region: server.$2,
          );
          return result;
        } on QuickConnectException catch (e) {
          errorMessages.add(e.message);
          continue;
        } on DioException catch (e) {
          errorMessages.add(
            '连接${server.$2 == QuickConnectRegion.china ? '中国区' : '全球区'}服务器失败：${e.message ?? e.toString()}',
          );
          continue;
        }
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
    required QuickConnectRegion region,
  }) async {
    final domainSuffix =
        region == QuickConnectRegion.china ? _domainChina : _domainGlobal;

    // 第一步：获取 server info
    final serverInfo = await _requestServerInfo(
      dio,
      globalUrl,
      quickConnectId,
    );

    final env =
        (serverInfo['env'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final controlHost = env['control_host'] as String?;
    final relayRegion = env['relay_region'] as String?;

    if (controlHost == null || controlHost.isEmpty) {
      throw QuickConnectException(
        '无法从${region == QuickConnectRegion.china ? '中国区' : '全球区'}服务器获取 control_host，请检查 QuickConnect ID 是否正确',
      );
    }

    // 提取 Smart DNS 直连地址
    final smartDns =
        (serverInfo['smartdns'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final directHost = smartDns['host'] as String?;
    final lanHosts = <String>[];
    final lanList = smartDns['lan'] as List<dynamic>?;
    if (lanList != null) {
      for (final lan in lanList) {
        if (lan is String && lan.isNotEmpty) {
          lanHosts.add(lan);
        }
      }
    }

    // 如果有 relay_region，直接构造 URL（第一步就能拿到）
    if (relayRegion != null && relayRegion.isNotEmpty) {
      final serverUrl = 'https://$quickConnectId.$relayRegion.$domainSuffix';
      return QuickConnectInfo(
        serverUrl: serverUrl,
        relayRegion: relayRegion,
        controlHost: controlHost,
        area: region,
        directHost: directHost,
        lanHosts: lanHosts,
      );
    }

    // 第二步：请求 tunnel，拿到 relay_region
    final tunnelInfo = await _requestTunnel(
      dio,
      controlHost,
      quickConnectId,
    );
    final tunnelEnv =
        (tunnelInfo['env'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final tunnelRelayRegion = tunnelEnv['relay_region'] as String?;
    if (tunnelRelayRegion == null || tunnelRelayRegion.isEmpty) {
      throw const QuickConnectException('无法获取 QuickConnect relay_region');
    }

    final serverUrl = 'https://$quickConnectId.$tunnelRelayRegion.$domainSuffix';

    return QuickConnectInfo(
      serverUrl: serverUrl,
      relayRegion: tunnelRelayRegion,
      controlHost: controlHost,
      area: region,
      directHost: directHost,
      lanHosts: lanHosts,
    );
  }

  /// 请求 server info
  Future<Map<String, dynamic>> _requestServerInfo(
    Dio dio,
    String globalUrl,
    String quickConnectId,
  ) async {
    final response = await dio.post<dynamic>(
      globalUrl,
      data: _buildServerInfoPayload(quickConnectId),
      options: Options(
        headers: {'Content-Type': 'application/json'},
        responseType: ResponseType.json,
      ),
    );
    return _parseResponse(response.data, 'get_server_info');
  }

  /// 请求 tunnel
  Future<Map<String, dynamic>> _requestTunnel(
    Dio dio,
    String controlHost,
    String quickConnectId,
  ) async {
    final tunnelUrl = 'https://$controlHost/Serv.php';
    final response = await dio.post<dynamic>(
      tunnelUrl,
      data: _buildTunnelPayload(quickConnectId),
      options: Options(
        headers: {'Content-Type': 'application/json'},
        responseType: ResponseType.json,
      ),
    );
    return _parseResponse(response.data, 'request_tunnel');
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
