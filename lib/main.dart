import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/router.dart';
import 'services/auth/auth_repository.dart';
import 'services/theme/theme_provider.dart';

class MusicApp extends ConsumerWidget {
  const MusicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Synology Music Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kReleaseMode) {}
  };

  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    debugPrint('未捕获错误: $error\n$stack');
    return true;
  };

  final container = ProviderContainer();
  try {
    await container.read(authRepositoryProvider).loadSession();
  } catch (_) {}

  // 加载主题偏好
  try {
    await container.read(themeModeProvider.notifier).load();
  } catch (_) {}

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MusicApp(),
    ),
  );
}
