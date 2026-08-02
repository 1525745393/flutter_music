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
            // 放行所有 SSL 证书校验 — 权衡安全与可用性的设计决策。
            // 群晖 QuickConnect 场景下，NAS 通常使用自签名证书或 QuickConnect relay
            // 服务器的动态域名，证书校验会因为域名不匹配而失败。
            // 如果不放行，自签名证书和 relay 连接都会直接断开。
            client.badCertificateCallback =
                (X509Certificate cert, String host, int port) => true;
            return client;
          },
        );
      }
      if (interceptors != null && interceptors.isNotEmpty) {
        dio.interceptors.addAll(interceptors);
      }
    }

  final Dio dio;
}
