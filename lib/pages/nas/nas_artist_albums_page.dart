import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/library/album.dart';
import '../player/player_page.dart';
import 'nas_providers.dart';
import 'nas_widgets.dart';

/// 歌手专辑列表页
///
/// 展示指定歌手的专辑，点击专辑进入详情播放。
class NasArtistAlbumsPage extends ConsumerWidget {
  const NasArtistAlbumsPage({super.key, required this.artistName});

  static const routeName = 'nas_artist_albums';
  static const routePath = '/nas/artist';

  final String artistName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(nasArtistAlbumsProvider(artistName));
    return Scaffold(
      appBar: AppBar(title: Text(artistName)),
      body: albums.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('暂无专辑'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) => _NasAlbumCard(
              album: items[index],
              onTap: () => context.push(
                NasAlbumSongsPage.routePath,
                extra: items[index],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
      ),
    );
  }
}

/// 专辑歌曲列表页（点击歌曲播放整张专辑）
class NasAlbumSongsPage extends ConsumerWidget {
  const NasAlbumSongsPage({super.key, required this.album});

  static const routeName = 'nas_album_songs';
  static const routePath = '/nas/album';

  final Album album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(nasAlbumSongsProvider(album));
    return Scaffold(
      appBar: AppBar(title: Text(album.title)),
      body: songs.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('专辑为空'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final song = items[index];
              return ListTile(
                leading: nasCoverBox(url: album.coverUrl, icon: Icons.album),
                title: Text(song.title),
                subtitle: Text(song.artist),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NasAddToPlaylistButton(song: song),
                    NasFavoriteButton(song: song),
                  ],
                ),
                onTap: () async {
                  await playNasQueue(ref, items, startIndex: index);
                  if (context.mounted) {
                    context.go(PlayerPage.routePath);
                  }
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
      ),
    );
  }
}

class _NasAlbumCard extends StatelessWidget {
  const _NasAlbumCard({required this.album, required this.onTap});

  final Album album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: album.coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: album.coverUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => _buildDefaultCover(context),
                      errorWidget: (_, _, _) => _buildDefaultCover(context),
                    )
                  : _buildDefaultCover(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            album.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(
            '${album.songCount} 首',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color
                      ?.withValues(alpha: 0.7),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultCover(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.album, size: 48),
    );
  }
}
