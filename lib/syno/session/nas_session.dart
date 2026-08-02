import '../../core/network/synology_api_info.dart';

/// NAS 会话状态
///
/// 持有登录成功后的会话令牌与 API 元信息缓存。
/// [sid] 与 [synoToken] 由认证层刷新，[apiInfo] 用于版本自适应。
class NasSession {
  const NasSession({
    required this.sid,
    this.synoToken,
    this.apiInfo,
  });

  /// 会话 ID
  final String sid;

  /// CSRF 防护令牌（DSM 7）
  final String? synoToken;

  /// API 元信息缓存（DSM 6/7 版本自适应）
  final SynologyApiInfo? apiInfo;

  /// 是否为有效会话
  bool get isValid => sid.isNotEmpty;

  NasSession copyWith({
    String? sid,
    Object? synoToken = _sentinel,
    Object? apiInfo = _sentinel,
  }) {
    return NasSession(
      sid: sid ?? this.sid,
      synoToken: synoToken is String?
          ? synoToken
          : (synoToken == _sentinel ? this.synoToken : null),
      apiInfo: apiInfo is SynologyApiInfo?
          ? apiInfo
          : (apiInfo == _sentinel ? this.apiInfo : null),
    );
  }

  static const _sentinel = Object();
}
