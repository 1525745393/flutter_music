import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

class DioClient {
  DioClient({required String baseUrl})
    : dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
        ),
      ) {
      // 放行所有域名的 SSL 证书校验
      // QuickConnect 会涉及多个域名：quickconnect.to、quickconnect.cn、
      // relay.quickconnect.*、实际 NAS IP/DDNS 等，统一放行避免证书问题
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback =
              (X509Certificate cert, String host, int port) => true;
          return client;
        },
      );
    }

  final Dio dio;
}
