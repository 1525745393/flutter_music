import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'nas_config.dart';

/// NAS 配置与 SID 会话的安全持久化层
///
/// 使用 flutter_secure_storage（Keychain / Keystore / 加密存储）保存
/// 连接配置与会话令牌，避免明文落盘。
class NasConfigStore {
  NasConfigStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _keyServerUrl = 'syno.server_url';
  static const _keyUsername = 'syno.username';
  static const _keyPort = 'syno.port';
  static const _keyUseHttps = 'syno.use_https';
  static const _keyIgnoreCert = 'syno.ignore_self_signed_cert';
  static const _keyQuickConnectId = 'syno.quickconnect_id';
  static const _keySessionId = 'syno.session_id';

  final FlutterSecureStorage _storage;

  /// 读取保存的连接配置，不存在时返回 null
  Future<NasConfig?> loadConfig() async {
    final serverUrl = await _storage.read(key: _keyServerUrl);
    if (serverUrl == null || serverUrl.isEmpty) return null;

    final username = await _storage.read(key: _keyUsername) ?? '';
    final portStr = await _storage.read(key: _keyPort);
    final useHttps = await _storage.read(key: _keyUseHttps) == 'true';
    final ignoreCert =
        await _storage.read(key: _keyIgnoreCert) == 'true';
    final quickConnectId =
        await _storage.read(key: _keyQuickConnectId);

    return NasConfig(
      serverUrl: serverUrl,
      username: username,
      port: portStr != null ? int.tryParse(portStr) : null,
      useHttps: useHttps,
      ignoreSelfSignedCert: ignoreCert,
      quickConnectId:
          (quickConnectId != null && quickConnectId.isNotEmpty)
              ? quickConnectId
              : null,
    );
  }

  /// 保存连接配置
  Future<void> saveConfig(NasConfig config) async {
    await _storage.write(key: _keyServerUrl, value: config.serverUrl);
    await _storage.write(key: _keyUsername, value: config.username);
    await _storage.write(key: _keyPort, value: '${config.port}');
    await _storage.write(key: _keyUseHttps, value: '${config.useHttps}');
    await _storage.write(
      key: _keyIgnoreCert,
      value: '${config.ignoreSelfSignedCert}',
    );
    if (config.quickConnectId != null && config.quickConnectId!.isNotEmpty) {
      await _storage.write(
        key: _keyQuickConnectId,
        value: config.quickConnectId,
      );
    }
  }

  /// 读取已保存的 SID 会话，不存在时返回 null
  Future<String?> loadSessionId() => _storage.read(key: _keySessionId);

  /// 保存 SID 会话
  Future<void> saveSessionId(String sid) =>
      _storage.write(key: _keySessionId, value: sid);

  /// 清除全部 NAS 配置与会话
  Future<void> clear() async {
    await _storage.delete(key: _keyServerUrl);
    await _storage.delete(key: _keyUsername);
    await _storage.delete(key: _keyPort);
    await _storage.delete(key: _keyUseHttps);
    await _storage.delete(key: _keyIgnoreCert);
    await _storage.delete(key: _keyQuickConnectId);
    await _storage.delete(key: _keySessionId);
  }
}
