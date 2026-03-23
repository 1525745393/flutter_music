import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/login_draft.dart';
import '../../data/repositories/auth_repository.dart';

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
    } catch (e, st) {
      state = AsyncError(e, st);
      return '登录失败：$e';
    }
  }
}

final loginControllerProvider =
    NotifierProvider<LoginController, AsyncValue<void>>(LoginController.new);

final lastLoginDraftProvider = FutureProvider<LoginDraft?>((ref) {
  return ref.read(authRepositoryProvider).loadLastLoginDraft();
});
