import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/synology_api.dart';
import '../../services/auth/auth_repository.dart';
import '../home/home_page.dart';
import './login_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  static const routeName = 'login';
  static const routePath = '/login';

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future<void>(() async {
      final draft = await ref.read(lastLoginDraftProvider.future);
      if (!mounted || draft == null) {
        return;
      }
      _serverController.text = draft.serverUrl;
      _usernameController.text = draft.username;
    });
  }

  /// 检查输入是否为有效的服务器地址（IP、域名或完整URL）
  ///
  /// 支持格式：
  /// - IP地址：192.168.1.6、10.0.0.1:5000
  /// - 域名：nas.example.com、nas.example.com:5001
  /// - 完整URL：http://...、https://...
  bool _isValidAddress(String input) {
    final text = input.trim().toLowerCase();
    if (text.isEmpty) return false;

    // 完整 URL
    if (text.startsWith('http://') || text.startsWith('https://')) {
      return true;
    }

    // 去除可能的端口号后检查
    final host = text.split(':')[0];
    if (host.isEmpty) return false;

    // IPv4 格式
    final ipv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');
    if (ipv4.hasMatch(host)) {
      final parts = host.split('.');
      return parts.every((p) {
        final n = int.tryParse(p);
        return n != null && n >= 0 && n <= 255;
      });
    }

    // 域名格式（至少有一个点，各段为字母数字连字符）
    final domain = RegExp(r'^[a-z0-9-]+(\.[a-z0-9-]+)+$');
    return domain.hasMatch(host);
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 显示两步验证验证码输入对话框
  Future<void> _showTwoFactorDialog({
    required String serverUrl,
    required String username,
  }) async {
    final codeController = TextEditingController();
    final focusNode = FocusNode();

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            String? errorText;
            bool isLoading = false;

            return AlertDialog(
              title: const Text('两步验证'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('请输入 6 位验证码'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: codeController,
                    focusNode: focusNode,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      hintText: '请输入验证码',
                      errorText: errorText,
                      counterText: '',
                    ),
                    autofocus: true,
                    onChanged: (value) {
                      if (errorText != null) {
                        setState(() => errorText = null);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final code = codeController.text.trim();
                          if (code.isEmpty) {
                            setState(() => errorText = '请输入验证码');
                            return;
                          }
                          if (code.length != 6) {
                            setState(() => errorText = '验证码必须是 6 位数字');
                            return;
                          }

                          setState(() {
                            isLoading = true;
                            errorText = null;
                          });

                          final error = await ref
                              .read(loginControllerProvider.notifier)
                              .submitTwoFactorCode(
                                serverUrl: serverUrl,
                                username: username,
                                otpCode: code,
                              );

                          if (!dialogContext.mounted) {
                            return;
                          }

                          setState(() => isLoading = false);

                          if (error != null) {
                            setState(() => errorText = error);
                            return;
                          }

                          Navigator.of(dialogContext).pop();
                          if (mounted) {
                            context.go(HomePage.routePath);
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );

    codeController.dispose();
    focusNode.dispose();
  }

  Future<void> _onLoginPressed() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    final serverUrl = _serverController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    final error = await ref
        .read(loginControllerProvider.notifier)
        .login(
          serverUrl: serverUrl,
          username: username,
          password: password,
        );

    if (!mounted) {
      return;
    }

    if (error != null) {
      // 检查是否为两步验证异常
      final loginState = ref.read(loginControllerProvider);
      final isTwoFactorError = loginState.error is TwoFactorAuthException;

      if (isTwoFactorError) {
        // 弹出两步验证对话框
        await _showTwoFactorDialog(
          serverUrl: serverUrl,
          username: username,
        );
        return;
      }

      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    context.go(HomePage.routePath);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(loginControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('连接群晖 NAS')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _serverController,
                decoration: const InputDecoration(
                  labelText: '服务器地址或 QuickConnect ID',
                  hintText: '192.168.1.6 或 nas.xxx.com 或 mynas',
                ),
                keyboardType: TextInputType.url,
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) {
                    return '请输入服务器地址或 QuickConnect ID';
                  }
                  // 支持 QuickConnect ID、纯 IP/域名、完整 URL
                  final isQuickConnect =
                      QuickConnectService.isQuickConnectId(text);
                  if (isQuickConnect) return null;
                  // IP 地址或域名格式（允许含端口号）
                  if (_isValidAddress(text)) return null;
                  return '请输入有效的地址或 QuickConnect ID';
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: '账号'),
                validator: (value) {
                  if ((value?.trim().isEmpty ?? true)) {
                    return '请输入账号';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '密码'),
                validator: (value) {
                  if ((value?.isEmpty ?? true)) {
                    return '请输入密码';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: isLoading ? null : _onLoginPressed,
                child: Text(isLoading ? '登录中...' : '登录'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
