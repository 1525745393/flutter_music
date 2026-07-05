import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/synology_api.dart';
import '../../models/auth/login_draft.dart';
import '../../services/auth/auth_repository.dart';

class LoginController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncData(null);
  }

  Future<String?> login({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(authRepositoryProvider)
          .login(serverUrl: serverUrl, username: username, password: password);
      state = const AsyncData(null);
      return null;
    } on AuthException catch (e, st) {
      state = AsyncError(e, st);
      return e.message;
    } on QuickConnectException catch (e, st) {
      state = AsyncError(e, st);
      return e.message;
    } catch (e, st) {
      state = AsyncError(e, st);
      final errorMsg = e.toString();
      if (errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('No address associated with hostname')) {
        return '无法连接到服务器，请检查网络连接或服务器地址是否正确';
      } else if (errorMsg.contains('connection error') ||
          errorMsg.contains('SocketException')) {
        return '网络连接失败，请检查网络设置';
      } else if (errorMsg.contains('SSL') ||
          errorMsg.contains('certificate')) {
        return 'SSL 证书验证失败，请使用正确的 HTTPS 地址';
      }
      return '登录失败：$e';
    }
  }
}

final loginControllerProvider =
    NotifierProvider<LoginController, AsyncValue<void>>(LoginController.new);

final lastLoginDraftProvider = FutureProvider<LoginDraft?>((ref) {
  return ref.read(authRepositoryProvider).loadLastLoginDraft();
});
