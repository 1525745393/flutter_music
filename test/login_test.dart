import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_music/core/network/quickconnect_service.dart';
import 'package:flutter_music/utils/login_url_builder.dart';

void main() {
  group('QuickConnect ID 识别', () {
    test('QuickConnect ID 应返回 true', () {
      expect(QuickConnectService.isQuickConnectId('my-nas'), true);
      expect(QuickConnectService.isQuickConnectId('MyQuickID'), true);
      expect(QuickConnectService.isQuickConnectId('test-id-123'), true);
    });

    test('IP 地址应返回 false', () {
      expect(QuickConnectService.isQuickConnectId('192.168.1.6'), false);
      expect(QuickConnectService.isQuickConnectId('10.0.0.1'), false);
      expect(QuickConnectService.isQuickConnectId('127.0.0.1'), false);
      expect(QuickConnectService.isQuickConnectId('0.0.0.0'), false);
    });

    test('域名应返回 false', () {
      expect(QuickConnectService.isQuickConnectId('nas.example.com'), false);
      expect(QuickConnectService.isQuickConnectId('my-nas.synology.me'), false);
      expect(QuickConnectService.isQuickConnectId('sub.domain.co.uk'), false);
    });

    test('带协议的 URL 应返回 false', () {
      expect(QuickConnectService.isQuickConnectId('http://192.168.1.6:5000'), false);
      expect(QuickConnectService.isQuickConnectId('https://nas.example.com'), false);
    });

    test('空字符串应返回 false', () {
      expect(QuickConnectService.isQuickConnectId(''), false);
      expect(QuickConnectService.isQuickConnectId('  '), false);
    });
  });

  group('URL 构建', () {
    test('IP + 默认端口 5000 + HTTP', () {
      expect(
        LoginUrlBuilder.buildServerUrl(
          host: '192.168.1.6', port: '5000', useHttps: false,
        ),
        'http://192.168.1.6',
      );
    });

    test('IP + 自定义端口 5001 + HTTPS', () {
      expect(
        LoginUrlBuilder.buildServerUrl(
          host: '192.168.1.6', port: '5001', useHttps: true,
        ),
        'https://192.168.1.6:5001',
      );
    });

    test('域名 + 默认端口 + HTTP', () {
      expect(
        LoginUrlBuilder.buildServerUrl(
          host: 'nas.example.com', port: '5000', useHttps: false,
        ),
        'http://nas.example.com',
      );
    });

    test('域名 + 自定端口 80 + HTTP', () {
      expect(
        LoginUrlBuilder.buildServerUrl(
          host: 'nas.example.com', port: '80', useHttps: false,
        ),
        'http://nas.example.com:80',
      );
    });

    test('域名 + HTTPS + 默认端口', () {
      expect(
        LoginUrlBuilder.buildServerUrl(
          host: 'nas.local', port: '5000', useHttps: true,
        ),
        'https://nas.local',
      );
    });

    test('已含协议的完整 URL 直接返回', () {
      expect(
        LoginUrlBuilder.buildServerUrl(
          host: 'https://nas.home:5001', port: '5000', useHttps: false,
        ),
        'https://nas.home:5001',
      );
    });

    test('端口为空时使用默认', () {
      expect(
        LoginUrlBuilder.buildServerUrl(
          host: '192.168.1.10', port: '', useHttps: false,
        ),
        'http://192.168.1.10',
      );
    });
  });

  group('URL 解析', () {
    test('提取主机地址 - HTTP URL', () {
      expect(LoginUrlBuilder.extractHost('http://192.168.1.6:5000'), '192.168.1.6');
    });

    test('提取主机地址 - HTTPS URL', () {
      expect(LoginUrlBuilder.extractHost('https://nas.example.com:5001'), 'nas.example.com');
    });

    test('提取主机地址 - 无端口', () {
      expect(LoginUrlBuilder.extractHost('http://10.0.0.1'), '10.0.0.1');
    });

    test('提取端口 - 默认', () {
      expect(LoginUrlBuilder.extractPort('http://192.168.1.6'), '5000');
    });

    test('提取端口 - 自定义', () {
      expect(LoginUrlBuilder.extractPort('https://nas.home:8443'), '8443');
    });

    test('提取端口 - 默认端口', () {
      expect(LoginUrlBuilder.extractPort('http://192.168.1.6:5000'), '5000');
    });
  });
}
