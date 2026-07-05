import 'package:dio/dio.dart';

/// QuickConnect 解析异常
class QuickConnectException implements Exception {
  const QuickConnectException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// QuickConnect 解析结果
class QuickConnectInfo {
  const QuickConnectInfo({
    required this.serverUrl,
    required this.relayRegion,
    required this.controlHost,
  });

  /// 最终可访问的 NAS 地址（含 https:// 前缀）
  final String serverUrl;

  /// 中继区域（如 cnx、us、tw 等）
  final String relayRegion;

  /// 控制服务器主机
  final String controlHost;
}

/// 群晖 QuickConnect 协议解析服务
///
/// 实现两步请求流程：
/// 1. 向全局 QuickConnect 服务器请求 server info，获取 control_host
/// 2. 向 control_host 请求 tunnel，获取 relay_region
/// 3. 拼装最终 URL：https://{id}.{relay_region}.quickconnect.to
class QuickConnectService {
  QuickConnectService();

  /// QuickConnect 全局服务地址
  static const _globalUrl = 'https://global.quickconnect.to/Serv.php';

  /// 构建请求 payload
  Map<String, dynamic> _buildPayload(String command, String quickConnectId) {
    return {
      'version': 1,
      'command': command,
      'id': 'mainapp_https',
      'serverID': quickConnectId,
      'stop_when_error': false,
      // request_tunnel 命令在成功时停止尝试
      'stop_when_success': command == 'request_tunnel',
      'is_gofile': false,
      'path': '',
    };
  }

  /// 校验响应并返回数据部分
  Map<String, dynamic> _parseResponse(
    dynamic responseData,
    String command,
  ) {
    // QuickConnect 服务端返回的是数组，取第一个元素
    final List<dynamic> responseList =
        responseData is List ? responseData : [responseData];

    if (responseList.isEmpty) {
      throw QuickConnectException('QuickConnect $command 响应为空');
    }

    final Map<String, dynamic> item =
        responseList[0] is Map<String, dynamic>
            ? responseList[0] as Map<String, dynamic>
            : <String, dynamic>{};

    final errno = item['errno'];
    if (errno != null && errno != 0) {
      final errinfo = item['errinfo'] ?? '';
      throw QuickConnectException(
        'QuickConnect $command 失败（错误码：$errno ${errinfo.toString().trim()}）',
      );
    }

    return item;
  }

  /// 解析 QuickConnect ID，返回 NAS 可访问地址
  ///
  /// 输入示例：`mynas` 或 `mynas.quickconnect.to`
  /// 输出示例：`https://mynas.cnx.quickconnect.to`
  Future<QuickConnectInfo> resolve(String quickConnectId) async {
    // 清理输入：去掉协议前缀和 .quickconnect.to 后缀
    final cleanId = _cleanQuickConnectId(quickConnectId);
    if (cleanId.isEmpty) {
      throw const QuickConnectException('QuickConnect ID 不能为空');
    }

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        // QuickConnect 服务器可能使用自签证书，临时关闭校验
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    try {
      // 第一步：获取 server info，拿到 control_host
      final serverInfo = await _requestServerInfo(dio, cleanId);
      final env =
          (serverInfo['env'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final controlHost = env['control_host'] as String?;
      if (controlHost == null || controlHost.isEmpty) {
        throw const QuickConnectException(
          '无法获取 QuickConnect control_host，请检查 ID 是否正确',
        );
      }

      // 第二步：请求 tunnel，拿到 relay_region
      final tunnelInfo = await _requestTunnel(dio, controlHost, cleanId);
      final tunnelEnv =
          (tunnelInfo['env'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final relayRegion = tunnelEnv['relay_region'] as String?;
      if (relayRegion == null || relayRegion.isEmpty) {
        throw const QuickConnectException(
          '无法获取 QuickConnect relay_region',
        );
      }

      // 拼装最终 URL
      final serverUrl = 'https://$cleanId.$relayRegion.quickconnect.to';

      return QuickConnectInfo(
        serverUrl: serverUrl,
        relayRegion: relayRegion,
        controlHost: controlHost,
      );
    } on QuickConnectException {
      rethrow;
    } on DioException catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('No address associated with hostname')) {
        throw const QuickConnectException(
          '无法连接 QuickConnect 服务器，请检查网络连接',
        );
      }
      throw QuickConnectException('QuickConnect 解析失败：${e.message}');
    } catch (e) {
      throw QuickConnectException('QuickConnect 解析失败：$e');
    } finally {
      dio.close();
    }
  }

  /// 请求 server info
  Future<Map<String, dynamic>> _requestServerInfo(
    Dio dio,
    String quickConnectId,
  ) async {
    final response = await dio.post<dynamic>(
      _globalUrl,
      data: [_buildPayload('get_server_info', quickConnectId)],
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
      data: [_buildPayload('request_tunnel', quickConnectId)],
      options: Options(
        headers: {'Content-Type': 'application/json'},
        responseType: ResponseType.json,
      ),
    );
    return _parseResponse(response.data, 'request_tunnel');
  }

  /// 清理 QuickConnect ID 输入
  ///
  /// 支持以下输入格式：
  /// - `mynas`
  /// - `mynas.quickconnect.to`
  /// - `https://mynas.quickconnect.to`
  /// - `https://mynas.cnx.quickconnect.to`
  /// - `https://quickconnect.to/mynas` (Web 门户格式)
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

    // 检查是否是 Web 门户格式：quickconnect.to/{id}
    if (result.startsWith('quickconnect.to/')) {
      final pathPart = result.substring('quickconnect.to/'.length);
      // 提取第一个路径段作为 ID
      final slashIndex = pathPart.indexOf('/');
      return slashIndex > 0 ? pathPart.substring(0, slashIndex) : pathPart;
    }

    // 去掉路径（对于其他格式）
    final slashIndex = result.indexOf('/');
    if (slashIndex > 0) {
      result = result.substring(0, slashIndex);
    }

    // 提取 ID：如果是 xxx.quickconnect.to 格式，取第一段
    if (result.endsWith('.quickconnect.to')) {
      final parts = result.split('.');
      if (parts.length >= 4 && parts.last == 'to') {
        result = parts.first;
      } else if (parts.length == 3) {
        // 格式：id.quickconnect.to -> 取 id
        result = parts.first;
      }
    }

    return result;
  }

  /// 判断输入是否是 QuickConnect ID
  ///
  /// 规则：
  /// - 不以 http:// 或 https:// 开头
  /// - 或者以 xxx.quickconnect.to 格式结尾
  static bool isQuickConnectId(String input) {
    final trimmed = input.trim().toLowerCase();
    if (trimmed.isEmpty) return false;

    // 以 http(s):// 开头但不是 quickconnect.to 域名的，视为普通 URL
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed.contains('quickconnect.to');
    }

    // 不以 http 开头的，视为 QuickConnect ID
    return true;
  }
}
