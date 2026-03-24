import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../pages/login/login_page.dart';
import '../pages/home/library_page.dart';
import '../pages/player/player_page.dart';

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
