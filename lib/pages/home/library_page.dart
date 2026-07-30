import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../login/login_page.dart';
import '../../services/auth/auth_repository.dart';
import '../../services/library/library_repository.dart';
import '../../services/library/favorites_repository.dart';
import '../../models/library/song_item.dart';
import '../player/player_page.dart';
import 'library_providers.dart';
import '../player/player_controller.dart';

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  static const routeName = 'library';
  static const routePath = '/library';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(songsProvider);
    final favoriteIdsAsync = ref.watch(favoriteIdsProvider);
    final favoriteIds = favoriteIdsAsync.maybeWhen(
      data: (ids) => ids,
      orElse: () => const <String>{},
    );

    // 监听会话失效，自动跳转到登录页
    ref.listen<AsyncValue<List<SongItem>>>(
      songsProvider,
      (previous, next) {
        next.whenOrNull(
          error: (error, stackTrace) {
            if (error is SessionExpiredException) {
              // 会话失效，跳转到登录页
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
      appBar: AppBar(
        title: const Text('音乐库'),
        actions: [
          PopupMenuButton<_SortOption>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: '排序',
            onSelected: (option) {
              ref.read(songSortByProvider.notifier).set(option.sortBy);
              ref.read(songSortDirectionProvider.notifier)
                  .set(option.sortDirection);
              ref.invalidate(songsProvider);
            },
            itemBuilder: (context) => _sortOptions
                .map((opt) => PopupMenuItem<_SortOption>(
                      value: opt,
                      child: Text(opt.label),
                    ))
                .toList(),
          ),
          IconButton(
            onPressed: () async {
              await ref.read(authRepositoryProvider).clearSession();
              if (context.mounted) {
                context.go(LoginPage.routePath);
              }
            },
            icon: const Icon(Icons.logout_rounded),
            tooltip: '退出登录',
          ),
        ],
      ),
      body: songsAsync.when(
        data: (songs) {
          if (songs.isEmpty) {
            return const Center(child: Text('音乐库为空'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(songsProvider.future),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: songs.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final song = songs[index];
                final isFavorite = favoriteIds.contains(song.id);

                return ListTile(
                  title: Text(song.title),
                  subtitle: Text('${song.artist} · ${song.album}'),
                  leading: song.coverUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: song.coverUrl!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 48,
                              height: 48,
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.music_note),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 48,
                              height: 48,
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.music_note),
                            ),
                          ),
                        )
                      : Container(
                          width: 48,
                          height: 48,
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.music_note),
                        ),
                  trailing: IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : null,
                    ),
                    onPressed: () async {
                      final notifier = ref.read(favoritesListProvider.notifier);
                      if (isFavorite) {
                        await notifier.removeFavorite(song.id);
                      } else {
                        await notifier.addFavorite(song);
                      }
                    },
                    tooltip: isFavorite ? '取消收藏' : '收藏',
                  ),
                  onTap: () async {
                    // 设置当前播放的歌曲和播放队列
                    await ref
                        .read(playerControllerProvider.notifier)
                        .setPlayQueue(songs, startIndex: index);

                    // 跳转到播放页面
                    if (context.mounted) {
                      context.go(PlayerPage.routePath);
                    }
                  },
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          // 会话失效时显示特殊提示
          final isSessionExpired = error is SessionExpiredException;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSessionExpired ? Icons.warning_amber_rounded : Icons.error_outline,
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
                        : () => ref.refresh(songsProvider),
                    child: Text(isSessionExpired ? '去登录' : '重试'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 排序选项
class _SortOption {
  const _SortOption({required this.label, required this.sortBy, required this.sortDirection});
  final String label;
  final String? sortBy;
  final String? sortDirection;
}

const _sortOptions = [
  _SortOption(label: '默认排序', sortBy: null, sortDirection: null),
  _SortOption(label: '标题 A-Z', sortBy: 'title', sortDirection: 'ASC'),
  _SortOption(label: '标题 Z-A', sortBy: 'title', sortDirection: 'DESC'),
  _SortOption(label: '艺术家 A-Z', sortBy: 'artist', sortDirection: 'ASC'),
  _SortOption(label: '专辑 A-Z', sortBy: 'album', sortDirection: 'ASC'),
  _SortOption(label: '年份 新-旧', sortBy: 'year', sortDirection: 'DESC'),
  _SortOption(label: '时长 长-短', sortBy: 'duration', sortDirection: 'DESC'),
  _SortOption(label: '评分 高-低', sortBy: 'rating', sortDirection: 'DESC'),
  _SortOption(label: '随机', sortBy: 'random', sortDirection: 'ASC'),
];
