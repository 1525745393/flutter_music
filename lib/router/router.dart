import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../pages/login/login_page.dart';
import '../pages/nas/nas_config_page.dart';
import '../pages/nas/nas_library_page.dart';
import '../pages/nas/nas_artist_albums_page.dart';
import '../pages/home/home_page.dart';
import '../pages/home/library_page.dart';
import '../pages/home/artists_page.dart';
import '../pages/home/albums_page.dart';
import '../pages/home/album_detail_page.dart';
import '../pages/home/favorites_page.dart';
import '../pages/home/search_page.dart';
import '../pages/home/folders_page.dart';
import '../pages/home/recent_plays_page.dart';
import '../pages/player/player_page.dart';
import '../models/library/album.dart';
import '../models/library/playlist.dart';
import '../services/auth/auth_repository.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.read(authRepositoryProvider);

  return GoRouter(
    initialLocation: LoginPage.routePath,
    redirect: (context, state) {
      final isLoggedIn = authRepository.cachedSession != null;
      final isLoginPage = state.matchedLocation == LoginPage.routePath;

      if (!isLoggedIn && !isLoginPage) {
        return LoginPage.routePath;
      }
      if (isLoggedIn && isLoginPage) {
        return HomePage.routePath;
      }
      return null;
    },
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
          final extra = state.extra;
          if (extra is! Album) {
            return const Scaffold(body: Center(child: Text('无效的专辑信息')));
          }
          return AlbumDetailPage(album: extra);
        },
      ),
      GoRoute(
        path: PlayerPage.routePath,
        name: PlayerPage.routeName,
        builder: (context, state) => const PlayerPage(),
      ),
      GoRoute(
        path: SearchPage.routePath,
        name: SearchPage.routeName,
        builder: (context, state) => const SearchPage(),
      ),
      GoRoute(
        path: FavoritesPage.routePath,
        name: FavoritesPage.routeName,
        builder: (context, state) => const FavoritesPage(),
      ),
      GoRoute(
        path: FoldersPage.routePath,
        name: FoldersPage.routeName,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Map<String, String?>) {
            return FoldersPage(
              parentId: extra['parentId'],
              title: extra['title'],
            );
          }
          return const FoldersPage();
        },
      ),
      GoRoute(
        path: RecentPlaysPage.routePath,
        name: RecentPlaysPage.routeName,
        builder: (context, state) => const RecentPlaysPage(),
      ),
      GoRoute(
        path: NasConfigPage.routePath,
        name: NasConfigPage.routeName,
        builder: (context, state) => const NasConfigPage(),
      ),
      GoRoute(
        path: NasLibraryPage.routePath,
        name: NasLibraryPage.routeName,
        builder: (context, state) => const NasLibraryPage(),
      ),
      GoRoute(
        path: NasSearchPage.routePath,
        name: NasSearchPage.routeName,
        builder: (context, state) => const NasSearchPage(),
      ),
      GoRoute(
        path: NasPlaylistDetailPage.routePath,
        name: NasPlaylistDetailPage.routeName,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Playlist) {
            return NasPlaylistDetailPage(playlist: extra);
          }
          return const Scaffold(
            body: Center(child: Text('无效的歌单信息')),
          );
        },
      ),
      GoRoute(
        path: NasArtistAlbumsPage.routePath,
        name: NasArtistAlbumsPage.routeName,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is String && extra.isNotEmpty) {
            return NasArtistAlbumsPage(artistName: extra);
          }
          return const Scaffold(
            body: Center(child: Text('无效的歌手信息')),
          );
        },
      ),
      GoRoute(
        path: NasAlbumSongsPage.routePath,
        name: NasAlbumSongsPage.routeName,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Album) {
            return NasAlbumSongsPage(album: extra);
          }
          return const Scaffold(
            body: Center(child: Text('无效的专辑信息')),
          );
        },
      ),
    ],
  );
});
