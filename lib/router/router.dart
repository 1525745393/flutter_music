import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../pages/login/login_page.dart';
import '../pages/home/home_page.dart';
import '../pages/home/library_page.dart';
import '../pages/home/artists_page.dart';
import '../pages/home/albums_page.dart';
import '../pages/home/album_detail_page.dart';
import '../pages/player/player_page.dart';
import '../models/library/album.dart';

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
        path: HomePage.routePath,
        name: HomePage.routeName,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: LibraryPage.routePath,
        name: LibraryPage.routeName,
        builder: (context, state) => const LibraryPage(),
      ),
      GoRoute(
        path: ArtistsPage.routePath,
        name: ArtistsPage.routeName,
        builder: (context, state) => const ArtistsPage(),
      ),
      GoRoute(
        path: AlbumsPage.routePath,
        name: AlbumsPage.routeName,
        builder: (context, state) {
          final artist = state.uri.queryParameters['artist'];
          return AlbumsPage(artistName: artist);
        },
      ),
      GoRoute(
        path: AlbumDetailPage.routePath,
        name: AlbumDetailPage.routeName,
        builder: (context, state) {
          final album = state.extra as Album?;
          if (album == null) {
            return const Scaffold(body: Center(child: Text('无效的专辑信息')));
          }
          return AlbumDetailPage(album: album);
        },
      ),
      GoRoute(
        path: PlayerPage.routePath,
        name: PlayerPage.routeName,
        builder: (context, state) => const PlayerPage(),
      ),
    ],
  );
});
