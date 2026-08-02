import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../syno/auth/nas_auth_api.dart';
import '../../syno/config/nas_config.dart';
import '../../syno/syno_providers.dart';
import 'nas_library_page.dart';

/// NAS 服务器配置页
///
/// 填写地址、端口、HTTPS、账号密码、忽略自签名证书开关；
/// 开启 2FA 的 NAS 登录后弹出验证码对话框。
class NasConfigPage extends ConsumerStatefulWidget {
  const NasConfigPage({super.key});

  static const routeName = 'nas_config';
  static const routePath = '/nas/config';

  @override
  ConsumerState<NasConfigPage> createState() => _NasConfigPageState();
}

class _NasConfigPageState extends ConsumerState<NasConfigPage> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _portController = TextEditingController(text: '5000');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _useHttps = false;
  bool _ignoreSelfSignedCert = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    Future<void>(() async {
      final store = ref.read(nasConfigStoreProvider);
      final config = await store.loadConfig();
      if (!mounted || config == null) {
        return;
      }
      _serverController.text = config.serverUrl;
      if (config.port != null) {
        _portController.text = '${config.port}';
      }
      _usernameController.text = config.username;
      _useHttps = config.useHttps;
      _ignoreSelfSignedCert = config.ignoreSelfSignedCert;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _serverController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  NasConfig get _draftConfig {
    final port = int.tryParse(_portController.text.trim());
    return NasConfig(
      serverUrl: _serverController.text.trim(),
      username: _usernameController.text.trim(),
      port: port,
      useHttps: _useHttps,
      ignoreSelfSignedCert: _ignoreSelfSignedCert,
    );
  }

  Future<void> _onConnectPressed() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    setState(() => _isLoading = true);

    try {
      final store = ref.read(nasConfigStoreProvider);
      final config = _draftConfig;
      await store.saveConfig(config);

      final authApi = ref.read(nasAuthApiProvider);
      await authApi.login(
        config: config,
        password: _passwordController.text,
      );

      if (!mounted) return;
      context.go(NasLibraryPage.routePath);
    } on NasTwoFactorAuthException {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final ok = await _showTwoFactorDialog();
      if (ok && mounted) {
        context.go(NasLibraryPage.routePath);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      messenger.showSnackBar(SnackBar(content: Text('连接失败：$e')));
    }
  }

  Future<bool> _showTwoFactorDialog() async {
    final codeController = TextEditingController();
    String? errorText;

    final result = await showDialog<bool>(
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
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () async {
                    final code = codeController.text.trim();
                    if (code.length != 6) {
                      setState(() => errorText = '验证码必须是 6 位数字');
                      return;
                    }
                    try {
                      final authApi = ref.read(nasAuthApiProvider);
                      await authApi.loginWithOtp(
                        config: _draftConfig,
                        otpCode: code,
                      );
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(true);
                      }
                    } catch (e) {
                      if (dialogContext.mounted) {
                        setState(() => errorText = '$e');
                      }
                    }
                  },
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );

    codeController.dispose();
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('NAS 服务器配置'),
        actions: [
          if (ref.read(nasAuthApiProvider).isLoggedIn)
            IconButton(
              icon: const Icon(Icons.link_off_rounded),
              tooltip: '断开连接',
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await ref.read(nasAuthApiProvider).logout();
                if (!mounted) return;
                setState(() {});
                messenger.showSnackBar(
                  const SnackBar(content: Text('已断开连接')),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '连接群晖 AudioStation',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _serverController,
                  decoration: const InputDecoration(
                    labelText: '服务器地址',
                    hintText: 'IP、域名或 QuickConnect ID',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                          ? '请输入服务器地址'
                          : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _portController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '端口',
                          hintText: '5000',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: '账号',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? '请输入账号'
                                : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '密码',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value == null || value.isEmpty)
                      ? '请输入密码'
                      : null,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _useHttps,
                  onChanged: (value) => setState(() => _useHttps = value),
                  title: const Text('使用 HTTPS'),
                  subtitle: const Text('NAS 开启了 HTTPS 时勾选'),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  value: _ignoreSelfSignedCert,
                  onChanged: (value) =>
                      setState(() => _ignoreSelfSignedCert = value),
                  title: const Text('忽略自签名证书'),
                  subtitle: const Text('内网 NAS 使用自签名 HTTPS 证书时勾选'),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isLoading ? null : _onConnectPressed,
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('连接'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
