import 'synology_api_constants.dart';
import 'synology_base_api.dart';

/// 群晖认证 API 模块。
///
/// 只放登录/登出/会话校验等认证相关接口。
/// 支持 2FA（两步验证）流程。
class SynologyAuthApi extends SynologyBaseApi {
  SynologyAuthApi({required super.serverUrl, super.apiInfo});

  /// DSM 登录，返回原始响应数据（包含 success/data/error）。
  ///
  /// 如果 NAS 开启了两步验证，会返回 error.code: 403 或 105，
  /// 调用方需改用 [loginWithOtp] 传入 OTP 验证码。
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
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
        'method': 'login',
        'account': username,
        'passwd': password,
        'session': session,
        'format': SynologyApiConstants.authFormatSid,
      },
    );
    return requireBody(response);
  }

  /// 带 OTP 验证码的登录（用于 2FA 两步验证）。
  ///
  /// 当 NAS 开启两步验证时，需传入 OTP 验证码完成登录。
  /// DSM 的 2FA 流程：
  /// 1. 先调用普通 login，如果返回 error.code: 403 表示需要 2FA
  /// 2. 用户输入 OTP 验证码后，调用此方法完成登录
  Future<Map<String, dynamic>> loginWithOtp({
    required String username,
    required String password,
    required String otpCode,
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
        'method': 'login',
        'account': username,
        'passwd': password,
        'session': session,
        'format': SynologyApiConstants.authFormatSid,
        'otp_code': otpCode,
      },
    );
    return requireBody(response);
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
        'method': 'login',
        'account': username,
        'passwd': password,
        'session': session,
        'format': SynologyApiConstants.authFormatSid,
        'otp_code': '',
      },
    );
    return requireBody(response);
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
        'method': 'login',
        'account': username,
        'passwd': password,
        'session': session,
        'format': SynologyApiConstants.authFormatSid,
        'otp_code': otpCode,
        'device_id': deviceId,
      },
    );
    return requireBody(response);
  }
}
