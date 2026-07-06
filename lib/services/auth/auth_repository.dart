import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/synology_api.dart';
import '../../models/auth/auth_session.dart';
import '../../models/auth/login_draft.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 2FA 需要验证码的异常
class TwoFactorAuthException implements AuthException {
  const TwoFactorAuthException(this.message);

  @override
  final String message;

  @override
  String toString() => message;
}

class AuthRepository {
  static const _keyServerUrl = 'auth.server_url';
  static const _keyUsername = 'auth.username';
  static const _keySessionId = 'auth.session_id';
  static const _keyDeviceId = 'auth.device_id';

  /// 缓存的 API 元信息（登录成功后加载）
  SynologyApiInfo? _apiInfo;

  /// 2FA 临时 token（首次登录 403 时保存，提交验证码时使用）
  String? _twoFactorToken;

  /// 获取缓存的 API 元信息
  SynologyApiInfo? get apiInfo => _apiInfo;

  Future<void> login({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    // 读取保存的 device_id
    final prefs = await SharedPreferences.getInstance();
    final savedDeviceId = prefs.getString(_keyDeviceId);

    // 如果输入是 QuickConnect ID，解析为候选地址列表
    final candidateUrls = await _resolveServerUrlsIfNeeded(serverUrl);

    // 遍历候选地址，逐一尝试登录
    final List<String> errorMessages = [];
    for (final url in candidateUrls) {
      try {
        final data = await _loginByApi(
          serverUrl: url,
          username: username,
          password: password,
          deviceId: savedDeviceId,
        );

        final success = data['success'] == true;
        if (!success) {
          final errorCode =
              (data['error'] as Map<String, dynamic>?)?['code'] as int?;
          // 2FA 需要特殊处理：保存 token，抛出让上层处理
          if (errorCode == 403 || errorCode == 105) {
            // 从错误响应中提取 token（AudioStation 文档版 2FA 流程）
            final errorData =
                (data['error'] as Map<String, dynamic>?)?['errors']
                    as Map<String, dynamic>?;
            final token = errorData?['token'] as String?;
            if (token != null && token.isNotEmpty) {
              _twoFactorToken = token;
            }
            throw const TwoFactorAuthException('需要两步验证');
          }
          // 非成功但非2FA：记录错误，尝试下一个地址
          errorMessages.add('${_mapLoginError(errorCode)} ($url)');
          continue;
        }

        final sid = (data['data'] as Map<String, dynamic>?)?['sid'] as String?;
        if (sid == null || sid.isEmpty) {
          errorMessages.add('未获取到会话信息 ($url)');
          continue;
        }

        // 保存 device_id（did），下次登录时带上
        final did =
            (data['data'] as Map<String, dynamic>?)?['did'] as String?;
        if (did != null && did.isNotEmpty) {
          await prefs.setString(_keyDeviceId, did);
        }

        // 登录成功：加载 API Info 并缓存
        await _loadApiInfo(url, sid);

        // 保存最终成功的 baseUrl，后续所有请求都用这个地址
        await prefs.setString(_keyServerUrl, url);
        await prefs.setString(_keyUsername, username);
        await prefs.setString(_keySessionId, sid);
        return;
      } on TwoFactorAuthException {
        // 2FA 异常直接向上抛出
        rethrow;
      } on AuthException catch (e) {
        errorMessages.add('${e.message} ($url)');
        continue;
      } catch (e) {
        // 网络错误等，尝试下一个地址
        errorMessages.add('$e ($url)');
        continue;
      }
    }

    // 所有候选地址都失败
    throw AuthException(
      '所有服务器地址均无法连接。错误详情：${errorMessages.join('；')}',
    );
  }

  /// 登录成功后加载 API 元信息（版本自适应）
  ///
  /// 失败时静默忽略，不影响主流程（会 fallback 到硬编码版本）
  Future<void> _loadApiInfo(String serverUrl, String sid) async {
    try {
      final apiInfo = SynologyApiInfo(serverUrl: serverUrl);
      await apiInfo.load(queryApis: [
        SynologyApiConstants.authApiName,
        SynologyApiConstants.songApiName,
        SynologyApiConstants.albumApiName,
        SynologyApiConstants.artistApiName,
        SynologyApiConstants.playlistApiName,
        SynologyApiConstants.folderApiName,
        SynologyApiConstants.lyricsApiName,
        SynologyApiConstants.lyricsSearchApiName,
        SynologyApiConstants.searchApiName,
        SynologyApiConstants.genreApiName,
        SynologyApiConstants.infoApiName,
        SynologyApiConstants.streamApiName,
        SynologyApiConstants.coverApiName,
        SynologyApiConstants.remotePlayerApiName,
      ]);
      _apiInfo = apiInfo;
    } catch (_) {
      // API Info 加载失败不影响主流程，使用硬编码默认值
    }
  }

  /// 判断输入是否为 QuickConnect ID，如果是则解析为候选地址列表
  ///
  /// 非 QuickConnect 输入直接返回原始 URL
  Future<List<String>> _resolveServerUrlsIfNeeded(String input) async {
    if (!QuickConnectService.isQuickConnectId(input)) {
      return [input];
    }

    final quickConnectService = QuickConnectService();
    final info = await quickConnectService.resolve(input);
    return info.candidateUrls;
  }

  Future<Map<String, dynamic>> _loginByApi({
    required String serverUrl,
    required String username,
    required String password,
    String? deviceId,
    String? otpCode,
  }) async {
    final api = SynologyAuthApi(serverUrl: serverUrl);
    try {
      return await api.login(
        username: username,
        password: password,
        deviceId: deviceId,
        otpCode: otpCode,
      );
    } on SynologyApiException catch (e) {
      throw AuthException('登录失败：${e.message}');
    }
  }

  /// 2FA 第二步：提交验证码
  ///
  /// AudioStation 文档版流程：
  /// 1. 首次登录返回 403，错误响应中包含 token
  /// 2. 第二次登录时 passwd 填这个 token，同时传入 otp_code
  Future<void> submitTwoFactorCode({
    required String serverUrl,
    required String username,
    required String otpCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final savedDeviceId = prefs.getString(_keyDeviceId);

    // 使用保存的 token 作为密码（AudioStation 文档版 2FA 流程）
    final token = _twoFactorToken;
    if (token == null || token.isEmpty) {
      throw const AuthException('两步验证失败：未获取到验证令牌，请重新登录');
    }

    final api = SynologyAuthApi(serverUrl: serverUrl);
    try {
      final data = await api.loginWithOtp(
        username: username,
        password: token,
        otpCode: otpCode,
        deviceId: savedDeviceId,
      );

      final success = data['success'] == true;
      if (!success) {
        final errorCode =
            (data['error'] as Map<String, dynamic>?)?['code'] as int?;
        throw AuthException(_mapLoginError(errorCode));
      }

      final sid = (data['data'] as Map<String, dynamic>?)?['sid'] as String?;
      if (sid == null || sid.isEmpty) {
        throw const AuthException('登录失败：未获取到会话信息');
      }

      // 保存 device_id（did）
      final did =
          (data['data'] as Map<String, dynamic>?)?['did'] as String?;
      if (did != null && did.isNotEmpty) {
        await prefs.setString(_keyDeviceId, did);
      }

      // 登录成功：加载 API Info 并缓存
      await _loadApiInfo(serverUrl, sid);

      await prefs.setString(_keyServerUrl, serverUrl);
      await prefs.setString(_keyUsername, username);
      await prefs.setString(_keySessionId, sid);

      // 清除临时 token
      _twoFactorToken = null;
    } on SynologyApiException catch (e) {
      throw AuthException('两步验证失败：${e.message}');
    }
  }

  Future<LoginDraft?> loadLastLoginDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString(_keyServerUrl);
    final username = prefs.getString(_keyUsername);
    if (serverUrl == null || username == null) {
      return null;
    }
    return LoginDraft(serverUrl: serverUrl, username: username);
  }

  Future<AuthSession?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString(_keyServerUrl);
    final sessionId = prefs.getString(_keySessionId);
    if (serverUrl == null || sessionId == null) {
      return null;
    }
    return AuthSession(serverUrl: serverUrl, sessionId: sessionId);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySessionId);
  }

  String _mapLoginError(int? code) {
    switch (code) {
      // 通用错误码（100-107）
      case 100:
        return '未知错误';
      case 101:
        return '请求参数不完整';
      case 102:
        return '该 API 不存在';
      case 103:
        return '请求方法不存在';
      case 104:
        return 'API 版本不支持';
      case 105:
        return '登录权限不足或会话已失效';
      case 106:
        return '会话超时，请重新登录';
      case 107:
        return '会话已被其他登录踢掉';
      // Auth 专属错误码（400+）
      case 400:
        return '请求参数错误（400）';
      case 401:
        return '账号或密码错误';
      case 402:
        return '权限不足（402）';
      case 403:
        return '需要两步验证';
      case 404:
        return '两步验证码错误';
      case 407:
        return 'IP 已被封禁，请稍后重试';
      default:
        return '登录失败：未知错误${code == null ? '' : '（错误码 $code）'}';
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});
