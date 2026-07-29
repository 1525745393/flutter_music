import 'dart:convert';

import 'package:dio/dio.dart';

import 'synology_api_constants.dart';
import 'synology_base_api.dart';

/// 群晖认证 API 模块。
///
/// 只放登录/登出/会话校验等认证相关接口。
/// 支持 2FA（两步验证）流程。
class SynologyAuthApi extends SynologyBaseApi {
  SynologyAuthApi({
    required super.serverUrl,
    super.apiInfo,
    super.synoToken,
  });

  /// DSM 登录，返回原始响应数据（包含 success/data/error）。
  ///
  /// 依次尝试两种 POST 请求格式，任意一种成功（success=true）即返回：
  /// 1. POST + application/json
  /// 2. POST + application/x-www-form-urlencoded
  ///
  /// 注意：不使用 GET 格式发送登录请求，因为密码会出现在 URL 查询参数中，
  /// 可能被服务器访问日志、代理日志或浏览器历史记录泄露。
  ///
  /// 如果 NAS 开启了两步验证，会返回 error.code: 403，
  /// 调用方需改用 [loginWithOtp] 传入 OTP 验证码。
  ///
  /// 官方文档确认：POST 请求，version=6，返回 sid/did/synotoken
  /// 请求体格式：application/json
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
    String session = SynologyApiConstants.authSessionAudioStation,
    String deviceName = 'FlutterMusic',
    String? deviceId,
    String? otpCode,
  }) async {
    final versionStr = resolveApiVersion(
      SynologyApiConstants.authApiName,
      SynologyApiConstants.authVersion,
    );

    // 构造通用参数（version 为 String 格式，用于 form-urlencoded）
    final paramsStringVersion = <String, dynamic>{
      'api': SynologyApiConstants.authApiName,
      'version': versionStr,
      'method': 'login',
      'account': username,
      'passwd': password,
      'session': session,
      'format': SynologyApiConstants.authFormatSid,
      'enable_syno_token': 'yes',
      'enable_device_token': 'yes',
      'device_name': deviceName,
    };
    if (deviceId != null && deviceId.isNotEmpty) {
      paramsStringVersion['device_id'] = deviceId;
    }
    if (otpCode != null && otpCode.isNotEmpty) {
      paramsStringVersion['otp_code'] = otpCode;
    }

    // POST JSON 格式使用 int 类型的 version
    final paramsIntVersion = Map<String, dynamic>.from(paramsStringVersion);
    paramsIntVersion['version'] = int.parse(versionStr);

    final requestPath = resolveApiPath(
      SynologyApiConstants.authApiName,
      SynologyApiConstants.authPath,
    );

    // 依次尝试两种 POST 请求格式，任意一种成功即返回。
    // 如果返回了有效 JSON（success=false），说明格式兼容但业务失败（如密码错误、需要2FA），
    // 此时直接返回业务错误，不再 fallback，避免重复请求触发 IP 封禁。
    final attempts = <(dynamic, String)>[
      (jsonEncode(paramsIntVersion), 'application/json'),
      (paramsStringVersion, 'application/x-www-form-urlencoded'),
    ];

    dynamic lastError;

    for (final (data, contentType) in attempts) {
      try {
        final response = await _postWithRedirect(
          requestPath,
          data: data,
          contentType: contentType,
        );
        final body = requireBody(response);
        if (body['success'] == true) {
          return body;
        }
        // 有效 JSON 且 success=false：格式兼容，业务失败，直接返回
        return body;
      } catch (e) {
        // 仅网络错误或响应无法解析时，记录错误并尝试下一种格式
        lastError = e;
      }
    }

    // 所有格式均出现网络错误
    if (lastError != null) {
      throw lastError;
    }
    throw StateError('登录请求失败：所有格式均未返回有效结果');
  }

  /// 手动处理重定向的 POST 请求。
  ///
  /// - 禁用 Dio 自动重定向，手动跟随 3xx 重定向
  /// - 保持 POST 方法和请求体不变
  /// - 支持相对路径重定向（与 baseUrl 拼接）
  /// - 最多跟随 5 次重定向
  /// - 检测循环重定向（同一 URL 出现第二次即停止）
  Future<Response<dynamic>> _postWithRedirect(
    String path, {
    required dynamic data,
    required String contentType,
  }) async {
    const maxRedirects = 5;
    final visitedUrls = <String>{};
    String currentUrl = path;

    for (int i = 0; i <= maxRedirects; i++) {
      // 检测循环重定向：同一 URL 出现第二次则停止
      if (visitedUrls.contains(currentUrl)) {
        throw DioException(
          requestOptions: RequestOptions(path: currentUrl),
          error: '检测到循环重定向：$currentUrl',
        );
      }
      visitedUrls.add(currentUrl);

      Response<dynamic> response;
      response = await dio.post(
        currentUrl,
        data: data,
        options: Options(
          contentType: contentType,
          followRedirects: false,
          validateStatus: (status) => status != null,
        ),
      );

      // 判断是否为重定向响应（3xx）
      final statusCode = response.statusCode;
      if (statusCode == null || statusCode < 300 || statusCode >= 400) {
        return response;
      }

      // 获取重定向地址
      final redirectUrl = response.headers.value('location');
      if (redirectUrl == null || redirectUrl.isEmpty) {
        return response;
      }

      // 解析重定向 URL：支持相对路径，与 baseUrl 拼接
      final baseUri = Uri.parse(serverUrl);
      final resolvedUri = baseUri.resolve(redirectUrl);
      currentUrl = resolvedUri.toString();
    }

    // 超过最大重定向次数
    throw DioException(
      requestOptions: RequestOptions(path: currentUrl),
      error: '重定向次数超过上限（$maxRedirects 次）',
    );
  }

  /// 带 OTP 验证码的登录（用于 2FA 两步验证）。
  ///
  /// 当 NAS 开启两步验证时，需传入 OTP 验证码完成登录。
  /// DSM 的 2FA 流程（AudioStation 文档版）：
  /// 1. 先调用普通 login，如果返回 error.code: 403 表示需要 2FA
  /// 2. 错误响应中包含 token，第二次登录时 passwd 填这个 token
  /// 3. 同时传入 otp_code 完成验证
  ///
  /// 注意：[password] 在 2FA 重试时应为首次登录返回的 token，而非原始密码
  Future<Map<String, dynamic>> loginWithOtp({
    required String username,
    required String password,
    required String otpCode,
    String? deviceId,
    String session = SynologyApiConstants.authSessionAudioStation,
  }) async {
    return login(
      username: username,
      password: password,
      session: session,
      deviceId: deviceId,
      otpCode: otpCode,
    );
  }

  /// 退出指定会话。
  Future<Map<String, dynamic>> logout({
    required String sid,
    String session = SynologyApiConstants.authSessionAudioStation,
  }) async {
    final response = await dio.get(
      resolveApiPath(
        SynologyApiConstants.authApiName,
        SynologyApiConstants.authPath,
      ),
      queryParameters: {
        'api': SynologyApiConstants.authApiName,
        'version': resolveApiVersion(
          SynologyApiConstants.authApiName,
          SynologyApiConstants.authVersion,
        ),
        'method': 'logout',
        'session': session,
        SynologyApiConstants.sidKey: sid,
      },
    );
    return requireBody(response);
  }

  /// 请求第二步验证（2FA 标准流程第一步）
  ///
  /// 当首次登录返回 403 错误码时，调用此方法获取 deviceid，
  /// 用于后续 SubmitSecondStep 提交验证码。
  ///
  /// 官方文档：DSM Login Web API Guide - RequestSecondStep
  Future<Map<String, dynamic>> requestSecondStep({
    required String username,
    required String password,
    String session = SynologyApiConstants.authSessionAudioStation,
  }) async {
    return login(
      username: username,
      password: password,
      session: session,
      otpCode: '',
    );
  }

  /// 提交第二步验证码（2FA 标准流程第二步）
  ///
  /// 使用 requestSecondStep 返回的 deviceid 和用户输入的 OTP 验证码完成登录。
  ///
  /// 官方文档：DSM Login Web API Guide - SubmitSecondStep
  Future<Map<String, dynamic>> submitSecondStep({
    required String username,
    required String password,
    required String otpCode,
    required String deviceId,
    String session = SynologyApiConstants.authSessionAudioStation,
  }) async {
    return login(
      username: username,
      password: password,
      session: session,
      deviceId: deviceId,
      otpCode: otpCode,
    );
  }
}
