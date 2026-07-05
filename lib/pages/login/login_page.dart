import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/synology_api.dart';
import '../home/library_page.dart';
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

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
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
          serverUrl: _serverController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) {
      return;
    }

    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    context.go(LibraryPage.routePath);
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
                  hintText: 'https://nas.xxx.com 或 mynas',
                ),
                keyboardType: TextInputType.url,
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) {
                    return '请输入服务器地址或 QuickConnect ID';
                  }
                  // 支持 QuickConnect ID 或标准 URL
                  final isQuickConnect =
                      QuickConnectService.isQuickConnectId(text);
                  if (!isQuickConnect &&
                      !text.startsWith('http://') &&
                      !text.startsWith('https://')) {
                    return '请输入有效的 URL 或 QuickConnect ID';
                  }
                  return null;
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
