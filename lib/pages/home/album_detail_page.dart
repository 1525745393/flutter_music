import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/library/album.dart';
import '../../models/library/song_item.dart';
import '../../services/library/library_repository.dart';
import '../login/login_page.dart';
import '../player/player_page.dart';
import '../player/player_controller.dart';
import 'library_providers.dart';

class AlbumDetailPage extends ConsumerWidget {
  const AlbumDetailPage({super.key, required this.album});

  final Album album;

  static const routeName = 'album_detail';
  static const routePath = '/album_detail';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(albumSongsProvider(album));

    // 监听会话失效
    ref.listen<AsyncValue<List<SongItem>>>(
      albumSongsProvider(album),
      (previous, next) {
        next.whenOrNull(
          error: (error, stackTrace) {
            if (error is SessionExpiredException) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  context.go(LoginPage.routePath);
                }
              });
            }
          },
        );
      },
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(album.title),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  album.coverUrl != null
                      ? Image.network(
                          album.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildDefaultCover(context);
                          },
                        )
                      : _buildDefaultCover(context),
                  // 渐变遮罩
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    album.artist,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _buildAlbumInfo(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                        ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () async {
                      final songs = await ref.read(albumSongsProvider(album).future);
                      if (songs.isNotEmpty && context.mounted) {
                        await ref
                            .read(playerControllerProvider.notifier)
                            .setPlayQueue(songs, startIndex: 0);
                        if (context.mounted) {
                          context.go(PlayerPage.routePath);
                        }
                      }
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('播放全部'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Divider(height: 1),
          ),
          songsAsync.when(
            data: (songs) {
              if (songs.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(child: Text('专辑内暂无歌曲')),
                );
              }
              return SliverList.separated(
                itemCount: songs.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final song = songs[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text('${index + 1}'),
                    ),
                    title: Text(song.title),
                    subtitle: Text(song.artist),
                    trailing: const Icon(Icons.play_arrow),
                    onTap: () async {
                      await ref
                          .read(playerControllerProvider.notifier)
                          .setPlayQueue(songs, startIndex: index);
                      if (context.mounted) {
                        context.go(PlayerPage.routePath);
                      }
                    },
                  );
                },
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) {
              final isSessionExpired = error is SessionExpiredException;
              return SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSessionExpired
                              ? Icons.warning_amber_rounded
                              : Icons.error_outline,
                          size: 48,
                          color: isSessionExpired
                              ? Colors.orange
                              : Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '$error',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: isSessionExpired
                              ? () => context.go(LoginPage.routePath)
                              : () => ref.refresh(albumSongsProvider(album)),
                          child: Text(isSessionExpired ? '去登录' : '重试'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultCover(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.album, size: 96),
    );
  }

  String _buildAlbumInfo() {
    final parts = <String>[];
    if (album.songCount > 0) {
      parts.add('${album.songCount} 首歌曲');
    }
    if (album.duration > 0) {
      final minutes = album.duration ~/ 60;
      final seconds = album.duration % 60;
      parts.add('$minutes:${seconds.toString().padLeft(2, '0')}');
    }
    if (album.year != null) {
      parts.add('${album.year} 年');
    }
    return parts.join(' · ');
  }
}
