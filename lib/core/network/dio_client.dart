import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

class DioClient {
  DioClient({
    required String baseUrl,
    List<Interceptor>? interceptors,
    bool ignoreSelfSignedCert = true,
  }) : dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          // 接受所有 HTTP 状态码，统一交给业务层处理
          // 这样即使返回 403/401，也能读取响应体中的 JSON 错误信息
          validateStatus: (status) => status != null,
        ),
      ) {
      // 默认放行所有域名的 SSL 证书校验（保持 QuickConnect 场景可用）。
      // 通过 [ignoreSelfSignedCert] 开关可恢复严格校验（如公网 HTTPS 场景）。
      if (ignoreSelfSignedCert) {
        dio.httpClientAdapter = IOHttpClientAdapter(
          createHttpClient: () {
            final client = HttpClient();
            // 放行自签名/未知 CA 证书，但始终校验证书主机名与访问 host 一致，
            // 避免忽略自签名开关被滥用为 MITM 通道。
            client.badCertificateCallback =
                (X509Certificate cert, String host, int port) {
              final certHosts = _certificateHosts(cert);
              if (certHosts.isEmpty) return false;
              return certHosts.any((name) => _hostMatches(name, host));
            };
            return client;
          },
        );
      }
      if (interceptors != null && interceptors.isNotEmpty) {
        dio.interceptors.addAll(interceptors);
      }
    }

  final Dio dio;

  /// 提取证书中可用于主机名校验的主机名（从 subject 解析 CN）
  static Set<String> _certificateHosts(X509Certificate cert) {
    final hosts = <String>{};
    try {
      final subject = cert.subject;
      final cn = subject
          .split(',')
          .map((part) => part.trim())
          .where((part) => part.startsWith('CN='))
          .map((part) => part.substring(3).trim())
          .where((name) => name.isNotEmpty)
          .firstOrNull;
      if (cn != null) hosts.add(cn);
    } catch (_) {
      // 证书字段解析失败时，退回严格校验（不匹配任何 host）
    }
    return hosts;
  }

  /// 判断证书主机名是否匹配访问 host，支持通配符 `*.example.com`
  static bool _hostMatches(String certName, String host) {
    final name = certName.toLowerCase();
    final target = host.toLowerCase();
    if (name == target) return true;
    if (name.startsWith('*.')) {
      final suffix = name.substring(1);
      return target.endsWith(suffix);
    }
    return false;
  }
}
