import 'dart:async';

import 'package:dio/dio.dart';

import '../../core/network/synology_api_constants.dart';
import '../config/nas_config.dart';
import 'nas_auth_api.dart';

/// 会话失效错误码（群晖 AudioStation 通用）
///
/// 参考 AudioStation 接口文档：105/106/107 表示会话不存在或已过期。
const int _kSessionExpiredCode105 = 105;
const int _kSessionExpiredCode106 = 106;
const int _kSessionExpiredCode107 = 107;

/// 请求重放标记 key（存放在 RequestOptions.extra）
const String _kRetriedKey = 'syno_auth_retried';

/// 会话失效检测
///
/// 判断一次 API 响应是否因会话失效导致。
bool isSessionExpiredError(Response<dynamic>? response, int? apiErrorCode) {
  if (response != null) {
    final status = response.statusCode;
    if (status == 401 || status == 403) {
      final body = response.data;
      // 403 可能是 2FA 或权限问题，但会话场景下统一视为可重登
      if (body is Map && body['success'] == false) {
        final code = (body['error'] as Map?)?['code'];
        if (code is num &&
            (code == _kSessionExpiredCode105 ||
                code == _kSessionExpiredCode106 ||
                code == _kSessionExpiredCode107)) {
          return true;
        }
      }
      if (status == 401) return true;
    }
  }
  if (apiErrorCode != null &&
      (apiErrorCode == _kSessionExpiredCode105 ||
          apiErrorCode == _kSessionExpiredCode106 ||
          apiErrorCode == _kSessionExpiredCode107)) {
    return true;
  }
  return false;
}

/// 认证拦截器：捕获 401 / 会话失效，自动静默重登后重放请求
///
/// 挂载在 NAS 数据请求使用的 Dio 实例上。
/// 重登成功则克隆原请求（用新会话刷新 sid/token）重放一次；
/// 同一请求最多重放一次，避免会话失效场景下无限重试。
/// 重放失败则抛出原始错误交给上层。
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.authApi,
    required this.configProvider,
    required this.dioProvider,
  });

  /// 认证 API（用于静默重登）
  final NasAuthApi authApi;

  /// 获取当前 NAS 配置（重登时需要）
  final NasConfig Function() configProvider;

  /// 获取用于重放请求的 Dio 实例（挂载拦截器的同一个 Dio）
  final Dio Function() dioProvider;

  /// 重登进行中标记，避免并发请求同时触发多次重登
  Future<bool>? _reLoginFuture;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final options = err.requestOptions;

    // 已重放过一次，不再重试，直接交给上层（避免死循环）
    if (options.extra[_kRetriedKey] == true) {
      return handler.next(err);
    }

    if (!isSessionExpiredError(response, null)) {
      return handler.next(err);
    }

    final reLoginOk = await _reLogin();
    if (!reLoginOk) {
      return handler.next(err);
    }

    try {
      // 用新会话刷新 URL 中的 sid / SynoToken，否则重放仍带旧凭据
      final refreshed = _refreshSessionInUrl(options);
      refreshed.extra[_kRetriedKey] = true;
      final retryResponse = await dioProvider().fetch<dynamic>(refreshed);
      return handler.resolve(retryResponse);
    } catch (_) {
      // 重放失败，继续走原始错误
    }
    return handler.next(err);
  }

  /// 用重登后的新会话刷新请求 URL 中的 `_sid` 与 `SynoToken`
  RequestOptions _refreshSessionInUrl(RequestOptions options) {
    final session = authApi.session;
    if (session == null) {
      return options;
    }
    var uri = Uri.parse(options.path);
    final params = Map<String, dynamic>.from(uri.queryParameters);
    params[SynologyApiConstants.sidKey] = session.sid;
    if (session.synoToken != null && session.synoToken!.isNotEmpty) {
      params['SynoToken'] = session.synoToken;
    }
    uri = uri.replace(queryParameters: params);
    return options.copyWith(
      path: uri.toString(),
      extra: Map<String, dynamic>.from(options.extra),
    );
  }

  /// 静默重登（带并发去重）
  Future<bool> _reLogin() {
    final pending = _reLoginFuture;
    if (pending != null) return pending;
    final future = authApi.silentReLogin(configProvider());
    _reLoginFuture = future.whenComplete(() => _reLoginFuture = null);
    return _reLoginFuture!;
  }
}
