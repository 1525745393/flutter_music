import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/synology_api.dart';
import '../models/auth_session.dart';
import '../models/login_draft.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthRepository {
  static const _keyServerUrl = 'auth.server_url';
  static const _keyUsername = 'auth.username';
  static const _keySessionId = 'auth.session_id';

  Future<void> login({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final data = await _loginByApi(
      serverUrl: serverUrl,
      username: username,
      password: password,
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

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServerUrl, serverUrl);
    await prefs.setString(_keyUsername, username);
    await prefs.setString(_keySessionId, sid);
  }

  Future<Map<String, dynamic>> _loginByApi({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final api = SynologyAuthApi(serverUrl: serverUrl);
    try {
      return await api.login(username: username, password: password);
    } on SynologyApiException catch (e) {
      throw AuthException('登录失败：${e.message}');
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
      case 400:
        return '请求参数错误（400）';
      case 401:
        return '账号或密码错误（401）';
      case 402:
        return '权限不足（402）';
      case 403:
        return '需要二次验证（403）';
      case 404:
        return '二次验证码错误（404）';
      case 407:
        return 'IP 已被封禁，请稍后重试（407）';
      default:
        return '登录失败：未知错误${code == null ? '' : '（$code）'}';
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});
