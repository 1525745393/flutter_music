import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/pages/login_page.dart';
import '../features/library/presentation/pages/library_page.dart';
import '../features/player/presentation/pages/player_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: LoginPage.routePath,
    routes: [
      GoRoute(
        path: LoginPage.routePath,
        name: LoginPage.routeName,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: LibraryPage.routePath,
        name: LibraryPage.routeName,
        builder: (context, state) => const LibraryPage(),
      ),
      GoRoute(
        path: PlayerPage.routePath,
        name: PlayerPage.routeName,
        builder: (context, state) => const PlayerPage(),
      ),
    ],
  );
});
