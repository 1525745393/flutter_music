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
  final _portController = TextEditingController(text: '5000');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _useHttps = false;

  @override
  void initState() {
    super.initState();
    Future<void>(() async {
      final draft = await ref.read(lastLoginDraftProvider.future);
      if (!mounted || draft == null) {
        return;
      }
      final url = draft.serverUrl;
      _serverController.text = _extractHost(url);
      _portController.text = _extractPort(url);
      _usernameController.text = draft.username;
      _useHttps = url.startsWith('https://');
    });
  }

  /// 从 URL 中提取主机地址（不含协议和端口）
  String _extractHost(String url) {
    var host = url.trim();
    // 移除协议前缀
    if (host.startsWith('https://')) {
      host = host.substring(8);
    } else if (host.startsWith('http://')) {
      host = host.substring(7);
    }
    // 移除端口和路径
    final colonIndex = host.indexOf(':');
    if (colonIndex > 0) {
      host = host.substring(0, colonIndex);
    }
    final slashIndex = host.indexOf('/');
    if (slashIndex > 0) {
      host = host.substring(0, slashIndex);
    }
    return host;
  }

  /// 从 URL 中提取端口号
  String _extractPort(String url) {
    var host = url.trim();
    // 移除协议前缀
    if (host.startsWith('https://') || host.startsWith('http://')) {
      host = host.substring(host.indexOf('://') + 3);
    }
    final colonIndex = host.indexOf(':');
    if (colonIndex > 0) {
      final afterColon = host.substring(colonIndex + 1);
      final slashIndex = afterColon.indexOf('/');
      if (slashIndex > 0) {
        return afterColon.substring(0, slashIndex);
      }
      return afterColon;
    }
    return '5000';
  }

  /// 拼接完整的服务器 URL
  String get _fullServerUrl {
    final host = _serverController.text.trim();
    final port = _portController.text.trim();
    final scheme = _useHttps ? 'https' : 'http';

    // 如果输入是 QuickConnect ID，直接返回
    if (QuickConnectService.isQuickConnectId(host)) {
      return host;
    }

    // 如果已经包含协议前缀，直接返回
    if (host.startsWith('http://') || host.startsWith('https://')) {
      return host;
    }

    if (port.isNotEmpty && port != '5000') {
      return '$scheme://$host:$port';
    }
    return '$scheme://$host';
  }

  bool _isValidHost(String input) {
    final text = input.trim().toLowerCase();
    if (text.isEmpty) return false;

    // 完整 URL
    if (text.startsWith('http://') || text.startsWith('https://')) {
      return true;
    }

    // QuickConnect ID
    if (QuickConnectService.isQuickConnectId(text)) {
      return true;
    }

    // 去除端口号后检查
    final host = text.split(':')[0];
    if (host.isEmpty) return false;

    // IPv4
    final ipv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');
    if (ipv4.hasMatch(host)) {
      final parts = host.split('.');
      return parts.every((p) {
        final n = int.tryParse(p);
        return n != null && n >= 0 && n <= 255;
      });
    }

    // 域名
    final domain = RegExp(r'^[a-z0-9-]+(\.[a-z0-9-]+)+$');
    return domain.hasMatch(host);
  }

  @override
  void dispose() {
    _serverController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _showTwoFactorDialog({
    required String serverUrl,
    required String username,
  }) async {
    final codeController = TextEditingController();
    final focusNode = FocusNode();

    String? errorText;
    bool isLoading = false;

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setState) {
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

    final error = await ref
        .read(loginControllerProvider.notifier)
        .login(
          serverUrl: _fullServerUrl,
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) {
      return;
    }

    if (error != null) {
      final loginState = ref.read(loginControllerProvider);
      final isTwoFactorError = loginState.error is TwoFactorAuthException;

      if (isTwoFactorError) {
        await _showTwoFactorDialog(
          serverUrl: _fullServerUrl,
          username: _usernameController.text.trim(),
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
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 音乐图标
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.library_music_rounded,
                      size: 44,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 标题
                  Text(
                    '连接群晖 NAS',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '登录您的 Audio Station',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 服务器地址 + 端口
                  Row(
                    children: [
                      // 服务器地址（占据大部分空间）
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _serverController,
                          decoration: InputDecoration(
                            labelText: '服务器地址',
                            hintText: '192.168.1.6 或 nas.example.com',
                            prefixIcon: const Icon(Icons.dns_outlined),
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.url,
                          autofillHints: const [AutofillHints.url],
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) {
                              return '请输入服务器地址';
                            }
                            if (!_isValidHost(text)) {
                              return '请输入有效的地址';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 端口号
                      SizedBox(
                        width: 85,
                        child: TextFormField(
                          controller: _portController,
                          decoration: const InputDecoration(
                            labelText: '端口',
                            hintText: '5000',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return null;
                            final n = int.tryParse(text);
                            if (n == null || n < 1 || n > 65535) {
                              return '无效';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // HTTPS 开关
                  Row(
                    children: [
                      Icon(
                        Icons.https_outlined,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'HTTPS 安全连接',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: _useHttps,
                        onChanged: (value) {
                          setState(() => _useHttps = value);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 账号
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: '账号',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    validator: (value) {
                      if ((value?.trim().isEmpty ?? true)) {
                        return '请输入账号';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // 密码
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '密码',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: isLoading ? null : (_) => _onLoginPressed(),
                    validator: (value) {
                      if ((value?.isEmpty ?? true)) {
                        return '请输入密码';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // 登录按钮
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: isLoading ? null : _onLoginPressed,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '登录',
                              style: TextStyle(fontSize: 17),
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
