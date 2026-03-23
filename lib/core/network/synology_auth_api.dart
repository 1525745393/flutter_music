import 'synology_api_constants.dart';
import 'synology_base_api.dart';

/// 群晖认证 API 模块。
///
/// 只放登录/登出/会话校验等认证相关接口。
class SynologyAuthApi extends SynologyBaseApi {
  SynologyAuthApi({required super.serverUrl});

  /// DSM 登录，返回原始响应数据（包含 success/data/error）。
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
    String session = SynologyApiConstants.authSessionAudioStation,
  }) async {
    final response = await dio.get<Map<String, dynamic>>(
      SynologyApiConstants.authPath,
      queryParameters: {
        'api': SynologyApiConstants.authApiName,
        'version': SynologyApiConstants.authVersion,
        'method': 'login',
        'account': username,
        'passwd': password,
        'session': session,
        'format': SynologyApiConstants.authFormatSid,
      },
    );
    return requireBody(response.data);
  }

  /// 退出指定会话。
  Future<Map<String, dynamic>> logout({
    required String sid,
    String session = SynologyApiConstants.authSessionAudioStation,
  }) async {
    final response = await dio.get<Map<String, dynamic>>(
      SynologyApiConstants.authPath,
      queryParameters: {
        'api': SynologyApiConstants.authApiName,
        'version': SynologyApiConstants.authVersion,
        'method': 'logout',
        'session': session,
        SynologyApiConstants.sidKey: sid,
      },
    );
    return requireBody(response.data);
  }
}
