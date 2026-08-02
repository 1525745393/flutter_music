import '../../core/network/synology_api.dart';
import '../config/nas_config.dart';
import '../config/nas_config_store.dart';
import '../session/nas_session.dart';

/// NAS 认证异常
class NasAuthException implements Exception {
  const NasAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 2FA 需要验证码的异常
class NasTwoFactorAuthException extends NasAuthException {
  const NasTwoFactorAuthException(super.message);
}

/// NAS 认证封装
///
/// 复用现有 [SynologyAuthApi] / [SynologyApiInfo] 完成登录、2FA、登出，
/// 会话通过 [NasConfigStore] 安全持久化。
class NasAuthApi {
  NasAuthApi(this._store);

  final NasConfigStore _store;

  /// 内存中的当前会话
  NasSession? _session;

  /// 内存中的账号密码（仅用于 401 静默重登，不落盘）
  String? _cachedUsername;
  String? _cachedPassword;

  /// 当前会话
  NasSession? get session => _session;

  /// 是否有有效会话
  bool get isLoggedIn => _session?.isValid == true;

  /// 恢复持久化的会话（启动时调用）
  ///
  /// 返回恢复是否成功；无会话或会话为空视为未登录。
  Future<bool> restoreSession() async {
    final sid = await _store.loadSessionId();
    if (sid == null || sid.isEmpty) {
      _session = null;
      return false;
    }
    _session = NasSession(sid: sid);
    return true;
  }

  /// 登录，返回是否需要 2FA。
  ///
  /// 成功时保存 SID；需要 2FA 时抛 [NasTwoFactorAuthException]，
  /// 由上层收集验证码后调用 [loginWithOtp]。
  Future<void> login({
    required NasConfig config,
    required String password,
  }) async {
    _cachedUsername = config.username;
    _cachedPassword = password;

    final serverUrl = config.fullServerUrl;

    // 查询 API Info（DSM 6/7 版本自适应），失败时用硬编码 fallback
    SynologyApiInfo? apiInfo;
    try {
      apiInfo = SynologyApiInfo(serverUrl: serverUrl);
      await apiInfo.load(queryApis: [
        SynologyApiConstants.authApiName,
        SynologyApiConstants.songApiName,
        SynologyApiConstants.albumApiName,
        SynologyApiConstants.artistApiName,
        SynologyApiConstants.playlistApiName,
        SynologyApiConstants.searchApiName,
        SynologyApiConstants.streamApiName,
        SynologyApiConstants.coverApiName,
      ]);
    } catch (_) {
      apiInfo = null;
    }

    final api = SynologyAuthApi(serverUrl: serverUrl, apiInfo: apiInfo);
    try {
      final data = await api.login(
        username: config.username,
        password: password,
      );
      if (data['success'] != true) {
        final code =
            (data['error'] as Map<String, dynamic>?)?['code'] as int?;
        if (code == 403) {
          throw const NasTwoFactorAuthException('需要两步验证');
        }
        throw NasAuthException('登录失败：${_mapLoginError(code)}');
      }
      await _saveSessionFromLogin(serverUrl, data);
    } on SynologyApiException catch (e) {
      throw NasAuthException('登录失败：${e.message}');
    }
  }

  /// 2FA 第二步：提交验证码
  Future<void> loginWithOtp({
    required NasConfig config,
    required String otpCode,
  }) async {
    final serverUrl = config.fullServerUrl;
    final api = SynologyAuthApi(serverUrl: serverUrl);
    try {
      final data = await api.loginWithOtp(
        username: config.username,
        password: _cachedPassword ?? '',
        otpCode: otpCode,
      );
      if (data['success'] != true) {
        throw const NasAuthException('验证码验证失败，请重试');
      }
      await _saveSessionFromLogin(serverUrl, data);
    } on SynologyApiException catch (e) {
      throw NasAuthException('两步验证失败：${e.message}');
    }
  }

  /// 静默重登（供 401 拦截器调用）
  ///
  /// 使用内存中的账号密码重新登录。无凭据或登录失败时返回 false。
  Future<bool> silentReLogin(NasConfig config) async {
    final username = _cachedUsername;
    final password = _cachedPassword;
    if (username == null || password == null) return false;

    try {
      final serverUrl = config.fullServerUrl;
      final apiInfo = _session?.apiInfo;
      final api = SynologyAuthApi(serverUrl: serverUrl, apiInfo: apiInfo);
      final data = await api.login(username: username, password: password);
      if (data['success'] != true) return false;
      await _saveSessionFromLogin(serverUrl, data);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 登出并清理会话
  Future<void> logout() async {
    final session = _session;
    if (session != null) {
      try {
        // 尽力登出，失败不影响本地清理
        // ignore: avoid_catches_without_on_clauses
      } catch (_) {}
    }
    _session = null;
    _cachedUsername = null;
    _cachedPassword = null;
    await _store.clear();
  }

  /// 保存登录成功后的会话并持久化
  Future<void> _saveSessionFromLogin(
    String serverUrl,
    Map<String, dynamic> data,
  ) async {
    final body = data['data'] as Map<String, dynamic>?;
    final sid = body?['sid'] as String?;
    if (sid == null || sid.isEmpty) {
      throw const NasAuthException('登录成功但未获取到会话信息');
    }

    final synoToken = body?['synotoken'] as String?;

    // 保存新的 API Info 缓存（用于版本自适应）
    SynologyApiInfo? apiInfo;
    try {
      final info = SynologyApiInfo(serverUrl: serverUrl);
      await info.load(queryApis: [
        SynologyApiConstants.authApiName,
        SynologyApiConstants.songApiName,
        SynologyApiConstants.albumApiName,
        SynologyApiConstants.artistApiName,
        SynologyApiConstants.playlistApiName,
        SynologyApiConstants.searchApiName,
        SynologyApiConstants.streamApiName,
        SynologyApiConstants.coverApiName,
      ]);
      apiInfo = info;
    } catch (_) {
      apiInfo = null;
    }

    _session = NasSession(sid: sid, synoToken: synoToken, apiInfo: apiInfo);
    await _store.saveSessionId(sid);
  }

  /// 登录错误码映射
  static String _mapLoginError(int? code) {
    switch (code) {
      case 401:
        return '账号或密码错误';
      case 403:
        return '账号或密码错误';
      case 404:
        return '账号不存在';
      case 406:
        return '两次验证失败，请稍后再试';
      case 407:
        return '两次验证失败，请稍后再试';
      default:
        return '未知错误（错误码 ${code ?? '未知'}）';
    }
  }
}
