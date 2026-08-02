/// NAS 连接配置
///
/// 由用户在「NAS 服务器配置页」填写，保存于 flutter_secure_storage。
class NasConfig {
  const NasConfig({
    required this.serverUrl,
    required this.username,
    this.port,
    this.useHttps = false,
    this.ignoreSelfSignedCert = false,
    this.quickConnectId,
  });

  /// 服务器地址：QuickConnect ID、IP、域名（不含协议前缀）
  final String serverUrl;

  /// 登录账号
  final String username;

  /// 端口（默认 null，QuickConnect 不需要端口）
  final int? port;

  /// 是否使用 HTTPS
  final bool useHttps;

  /// 是否忽略自签名 HTTPS 证书（内网 NAS 常用）
  final bool ignoreSelfSignedCert;

  /// QuickConnect ID（若通过 QuickConnect 连接）
  final String? quickConnectId;

  /// 计算最终的服务器 URL（含协议与端口）
  String get fullServerUrl {
    final scheme = useHttps ? 'https' : 'http';
    final host = serverUrl.trim();
    if (port != null) {
      return '$scheme://$host:$port';
    }
    return '$scheme://$host';
  }

  /// 是否为 QuickConnect 连接
  bool get isQuickConnect => quickConnectId != null && quickConnectId!.isNotEmpty;

  NasConfig copyWith({
    String? serverUrl,
    String? username,
    Object? port = _sentinel,
    bool? useHttps,
    bool? ignoreSelfSignedCert,
    Object? quickConnectId = _sentinel,
  }) {
    return NasConfig(
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      port: port is int? ? port : (port == _sentinel ? this.port : null),
      useHttps: useHttps ?? this.useHttps,
      ignoreSelfSignedCert:
          ignoreSelfSignedCert ?? this.ignoreSelfSignedCert,
      quickConnectId: quickConnectId is String?
          ? quickConnectId
          : (quickConnectId == _sentinel ? this.quickConnectId : null),
    );
  }

  static const _sentinel = Object();
}
