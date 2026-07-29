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
class TwoFactorAuthException extends AuthException {
  const TwoFactorAuthException(super.message);
}

class AuthRepository {
  static const _keyServerUrl = 'auth.server_url';
  static const _keyUsername = 'auth.username';
  static const _keySessionId = 'auth.session_id';
  static const _keyDeviceId = 'auth.device_id';
  static const _keySynoToken = 'auth.syno_token';

  /// 缓存的 API 元信息（登录成功后加载）
  SynologyApiInfo? _apiInfo;

  /// 缓存的 SynoToken（CSRF 防护令牌）
  String? _synoToken;

  /// 2FA 临时 token（首次登录 403 时保存，提交验证码时使用）
  String? _twoFactorToken;

  /// 缓存的会话信息（登录成功后设置，登出时清除）
  AuthSession? _cachedSession;

  /// 获取缓存的 API 元信息
  SynologyApiInfo? get apiInfo => _apiInfo;

  /// 获取缓存的 SynoToken
  String? get synoToken => _synoToken;

  /// 同步获取已缓存的会话（用于路由守卫等需要同步检查的场景）
  AuthSession? get cachedSession => _cachedSession;

  Future<void> login({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    _twoFactorToken = null;

    // 读取保存的 device_id
    final prefs = await SharedPreferences.getInstance();
    final savedDeviceId = prefs.getString(_keyDeviceId);

    // 如果输入是 QuickConnect ID，解析为候选地址列表
    final candidateUrls = await _resolveServerUrlsIfNeeded(serverUrl);

    // 在多个候选地址上尝试登录
    await _tryLoginOnServers(
      candidateUrls: candidateUrls,
      username: username,
      password: password,
      deviceId: savedDeviceId,
    );
  }

  /// 在多个候选服务器地址上尝试登录
  ///
  /// 遍历候选地址列表，逐个尝试登录，第一个成功的地址即为最终地址。
  /// 遇到 2FA 异常（errorCode 403）会直接向上抛出。
  /// 所有地址都失败时抛出统一的错误信息。
  Future<void> _tryLoginOnServers({
    required List<String> candidateUrls,
    required String username,
    required String password,
    String? deviceId,
  }) async {
    // 业务错误（账号密码错误、权限不足等）- 优先展示
    final List<String> businessErrors = [];
    // 网络错误（连接超时、无法连接等）- 次之
    final List<String> networkErrors = [];

    for (final url in candidateUrls) {
      try {
        final data = await _loginByApi(
          serverUrl: url,
          username: username,
          password: password,
          deviceId: deviceId,
        );

        final success = data['success'] == true;
        if (!success) {
          final errorCode =
              (data['error'] as Map<String, dynamic>?)?['code'] as int?;
          // 2FA 需要特殊处理：保存 token，抛出让上层处理
          if (errorCode == 403) {
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
          // 非成功但非2FA：记录业务错误，尝试下一个地址
          businessErrors.add('${_mapLoginError(errorCode)} ($url)');
          continue;
        }

        final sid = (data['data'] as Map<String, dynamic>?)?['sid'] as String?;
        if (sid == null || sid.isEmpty) {
          businessErrors.add('未获取到会话信息 ($url)');
          continue;
        }

        // 登录成功：保存所有登录结果
        await _saveLoginResult(
          body: data,
          serverUrl: url,
          username: username,
        );
        return;
      } on TwoFactorAuthException {
        // 2FA 异常直接向上抛出
        rethrow;
      } on AuthException catch (e) {
        // AuthException 属于业务相关错误
        businessErrors.add('${e.message} ($url)');
        continue;
      } catch (e) {
        // 网络错误等，归类为网络错误
        networkErrors.add('$e ($url)');
        continue;
      }
    }

    // 所有候选地址都失败，按优先级生成错误信息
    throw AuthException(
      _buildMultiServerError(
        businessErrors: businessErrors,
        networkErrors: networkErrors,
        totalCount: candidateUrls.length,
        action: '登录',
      ),
    );
  }

  /// 保存登录成功后的所有数据
  ///
  /// 统一处理登录成功后的保存逻辑，包括：
  /// - 保存 device_id（did）
  /// - 保存 SynoToken（CSRF 防护令牌）
  /// - 加载并缓存 API Info
  /// - 保存 serverUrl、username、sessionId
  Future<void> _saveLoginResult({
    required Map<String, dynamic> body,
    required String serverUrl,
    required String username,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final data = body['data'] as Map<String, dynamic>?;
    final sid = data?['sid'] as String?;

    if (sid == null || sid.isEmpty) {
      return;
    }

    // 保存 device_id（did），下次登录时带上
    final did = data?['did'] as String?;
    if (did != null && did.isNotEmpty) {
      await prefs.setString(_keyDeviceId, did);
    }

    // 保存 SynoToken（CSRF 防护令牌）
    final synoTokenValue = data?['synotoken'] as String?;
    if (synoTokenValue != null && synoTokenValue.isNotEmpty) {
      _synoToken = synoTokenValue;
      await prefs.setString(_keySynoToken, synoTokenValue);
    }

    // 登录成功：加载 API Info 并缓存
    await _loadApiInfo(serverUrl, sid);

    // 保存最终成功的 baseUrl，后续所有请求都用这个地址
    await prefs.setString(_keyServerUrl, serverUrl);
    await prefs.setString(_keyUsername, username);
    await prefs.setString(_keySessionId, sid);

    // 缓存会话信息（用于同步路由守卫检查）
    _cachedSession = AuthSession(serverUrl: serverUrl, sessionId: sid);
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
  /// 非 QuickConnect 输入：
  /// - 已有 http/https 前缀 → 直接返回
  /// - 纯 IP/域名 → 自动补全 http:// 前缀
  Future<List<String>> _resolveServerUrlsIfNeeded(String input) async {
    if (QuickConnectService.isQuickConnectId(input)) {
      final quickConnectService = QuickConnectService();
      final info = await quickConnectService.resolve(input);
      return info.candidateUrls;
    }

    // 非 QuickConnect：如果没有协议前缀，自动补全 http://
    final lower = input.trim().toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      return ['http://${input.trim()}'];
    }
    return [input.trim()];
  }

  Future<Map<String, dynamic>> _loginByApi({
    required String serverUrl,
    required String username,
    required String password,
    String? deviceId,
  }) async {
    final api = SynologyAuthApi(serverUrl: serverUrl);
    try {
      return await api.login(
        username: username,
        password: password,
        deviceId: deviceId,
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

    // 如果输入是 QuickConnect ID，解析为候选地址列表
    final candidateUrls = await _resolveServerUrlsIfNeeded(serverUrl);

    // 在多个候选地址上尝试 2FA 验证
    await _tryTwoFactorOnServers(
      candidateUrls: candidateUrls,
      username: username,
      password: token,
      otpCode: otpCode,
      deviceId: savedDeviceId,
    );

    // 清除临时 token
    _twoFactorToken = null;
  }

  /// 在多个候选服务器地址上尝试 2FA 验证
  ///
  /// 遍历候选地址列表，逐个尝试提交验证码，第一个成功的地址即为最终地址。
  /// 所有地址都失败时抛出统一的错误信息。
  Future<void> _tryTwoFactorOnServers({
    required List<String> candidateUrls,
    required String username,
    required String password,
    required String otpCode,
    String? deviceId,
  }) async {
    // 业务错误（验证码错误、权限不足等）- 优先展示
    final List<String> businessErrors = [];
    // 网络错误（连接超时、无法连接等）- 次之
    final List<String> networkErrors = [];

    for (final url in candidateUrls) {
      try {
        final api = SynologyAuthApi(serverUrl: url);
        final data = await api.loginWithOtp(
          username: username,
          password: password,
          otpCode: otpCode,
          deviceId: deviceId,
        );

        final success = data['success'] == true;
        if (!success) {
          final errorCode =
              (data['error'] as Map<String, dynamic>?)?['code'] as int?;
          businessErrors.add('${_mapLoginError(errorCode)} ($url)');
          continue;
        }

        final sid = (data['data'] as Map<String, dynamic>?)?['sid'] as String?;
        if (sid == null || sid.isEmpty) {
          businessErrors.add('未获取到会话信息 ($url)');
          continue;
        }

        // 验证成功：保存所有登录结果
        await _saveLoginResult(
          body: data,
          serverUrl: url,
          username: username,
        );
        return;
      } on SynologyApiException catch (e) {
        // API 异常属于业务相关错误
        businessErrors.add('两步验证失败：${e.message} ($url)');
        continue;
      } on AuthException catch (e) {
        businessErrors.add('${e.message} ($url)');
        continue;
      } catch (e) {
        // 网络错误等，归类为网络错误
        networkErrors.add('$e ($url)');
        continue;
      }
    }

    // 所有候选地址都失败，按优先级生成错误信息
    throw AuthException(
      _buildMultiServerError(
        businessErrors: businessErrors,
        networkErrors: networkErrors,
        totalCount: candidateUrls.length,
        action: '两步验证',
      ),
    );
  }

  /// 构建多地址尝试失败的错误信息
  ///
  /// 错误展示优先级：
  /// 1. 优先展示业务错误（账号密码错误、验证码错误等）
  /// 2. 只有网络错误时展示第一条网络错误
  /// 格式："{action}失败：{错误信息}（共尝试 X 个地址）"
  String _buildMultiServerError({
    required List<String> businessErrors,
    required List<String> networkErrors,
    required int totalCount,
    required String action,
  }) {
    if (businessErrors.isNotEmpty) {
      // 有业务错误时，优先展示第一条业务错误
      return '$action失败：${businessErrors.first}（共尝试 $totalCount 个地址）';
    }
    if (networkErrors.isNotEmpty) {
      // 只有网络错误时，展示第一条网络错误
      return '$action失败：${networkErrors.first}（共尝试 $totalCount 个地址）';
    }
    return '$action失败：未知错误（共尝试 $totalCount 个地址）';
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
      _cachedSession = null;
      return null;
    }
    // 加载 SynoToken
    _synoToken = prefs.getString(_keySynoToken);
    _cachedSession = AuthSession(serverUrl: serverUrl, sessionId: sessionId);
    return _cachedSession;
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySessionId);
    await prefs.remove(_keySynoToken);
    _synoToken = null;
    _cachedSession = null;
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
      // Auth 专属错误码（400-410，官方文档定义）
      case 400:
        return '账号不存在或密码错误';
      case 401:
        return '账号已被禁用';
      case 402:
        return '权限不足，无法登录';
      case 403:
        return '需要两步验证';
      case 404:
        return '两步验证码错误，请重试';
      case 406:
        return '必须启用两步验证才能登录';
      case 407:
        return 'IP 已被封禁，请稍后重试';
      case 408:
        return '密码已过期且无法修改';
      case 409:
        return '密码已过期，请修改密码后再登录';
      case 410:
        return '首次登录必须修改密码';
      default:
        return '登录失败：未知错误${code == null ? '' : '（错误码 $code）'}';
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});
