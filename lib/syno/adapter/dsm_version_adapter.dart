import '../../core/network/synology_api_constants.dart';
import '../../core/network/synology_api_info.dart';

/// DSM 版本差异适配器
///
/// 封装 DSM 6.x 与 7.x 之间的认证路径、API 版本差异，
/// 避免业务层散落版本判断逻辑。
///
/// 已知差异（来自实测）：
/// - 认证路径：DSM 6.x 为 /webapi/auth.cgi，DSM 7.x 为 /webapi/entry.cgi
/// - API Info 查询：/webapi/query.cgi 通用
/// - SynoToken：DSM 7 推荐携带，DSM 6 可忽略
/// - 登录请求格式：form-urlencoded 最兼容
class DsmVersionAdapter {
  const DsmVersionAdapter({this.apiInfo});

  /// 登录成功后缓存的 API 元信息（可能为 null）
  final SynologyApiInfo? apiInfo;

  /// 是否为 DSM 7.x
  ///
  /// DSM 7.x 的认证路径为 entry.cgi，DSM 6.x 为 auth.cgi。
  bool get isDsm7 {
    final info = apiInfo;
    if (info == null || !info.isLoaded) return false;
    final path = info.getApiPath(
      SynologyApiConstants.authApiName,
      SynologyApiConstants.authPath,
    );
    return path.contains('entry.cgi');
  }

  /// 认证接口推荐版本
  String get authVersion => apiInfo?.isLoaded == true
      ? '${apiInfo!.getApiVersion(
          SynologyApiConstants.authApiName,
          int.parse(SynologyApiConstants.authVersion),
        )}'
      : SynologyApiConstants.authVersion;

  /// 当前采用的认证路径
  String get authPath => apiInfo?.isLoaded == true
      ? apiInfo!.getApiPath(
          SynologyApiConstants.authApiName,
          SynologyApiConstants.authPath,
        )
      : SynologyApiConstants.authPath;

  /// 是否需要在请求中携带 SynoToken（DSM 7 推荐，DSM 6 可忽略）
  bool get shouldSendSynoToken => isDsm7;
}
