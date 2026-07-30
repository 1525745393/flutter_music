/// 登录 URL 构建工具
///
/// 将服务器地址、端口、HTTPS 开关拼接为完整 URL。
/// 与 LoginPage._fullServerUrl 逻辑保持一致。
class LoginUrlBuilder {
  /// 拼接完整服务器 URL
  ///
  /// [host] 服务器地址（不含协议前缀）
  /// [port] 端口号
  /// [useHttps] 是否使用 HTTPS
  static String buildServerUrl({
    required String host,
    required String port,
    required bool useHttps,
  }) {
    final scheme = useHttps ? 'https' : 'http';

    if (host.startsWith('http://') || host.startsWith('https://')) {
      return host.trim();
    }

    final cleanHost = host.trim();
    final cleanPort = port.trim();

    if (cleanPort.isNotEmpty && cleanPort != '5000') {
      return '$scheme://$cleanHost:$cleanPort';
    }
    return '$scheme://$cleanHost';
  }

  /// 从 URL 中提取主机地址
  static String extractHost(String url) {
    var host = url.trim();
    if (host.startsWith('https://')) {
      host = host.substring(8);
    } else if (host.startsWith('http://')) {
      host = host.substring(7);
    }
    final colonIndex = host.indexOf(':');
    if (colonIndex > 0) {
      host = host.substring(0, colonIndex);
    }
    final slashIndex = host.indexOf('/');
    if (slashIndex > 0) {
      host = host.substring(0, slashIndex);
    }
    return host;
  }

  /// 从 URL 中提取端口号
  static String extractPort(String url) {
    var host = url.trim();
    if (host.startsWith('https://') || host.startsWith('http://')) {
      host = host.substring(host.indexOf('://') + 3);
    }
    final colonIndex = host.indexOf(':');
    if (colonIndex > 0) {
      final afterColon = host.substring(colonIndex + 1);
      final slashIndex = afterColon.indexOf('/');
      if (slashIndex > 0) {
        return afterColon.substring(0, slashIndex);
      }
      return afterColon;
    }
    return '5000';
  }
}
