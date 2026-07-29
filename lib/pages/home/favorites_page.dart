import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/library/favorites_repository.dart';
import '../player/player_page.dart';
import '../player/player_controller.dart';

/// 收藏歌曲列表页
class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  static const routeName = 'favorites';
  static const routePath = '/favorites';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的收藏'),
      ),
      body: favoritesAsync.when(
        data: (favorites) {
          if (favorites.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_border_rounded, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('还没有收藏歌曲', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.separated(
            itemCount: favorites.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final fav = favorites[index];
              return ListTile(
                leading: fav.coverUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedNetworkImage(
                          imageUrl: fav.coverUrl!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Container(
                            width: 48,
                            height: 48,
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            child: const Icon(Icons.music_note),
                          ),
                          errorWidget: (_, _, _) => Container(
                            width: 48,
                            height: 48,
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            child: const Icon(Icons.music_note),
                          ),
                        ),
                      )
                    : Container(
                        width: 48,
                        height: 48,
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: const Icon(Icons.music_note),
                      ),
                title: Text(fav.title),
                subtitle: Text('${fav.artist} . ${fav.album}'),
                trailing: IconButton(
                  icon: const Icon(Icons.favorite, color: Colors.red),
                  onPressed: () async {
                    await ref
                        .read(favoritesListProvider.notifier)
                        .removeFavorite(fav.songId);
                  },
                  tooltip: '取消收藏',
                ),
                onTap: () async {
                  final songs = favorites.map((f) => f.toSongItem()).toList();
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('加载失败：$error')),
      ),
    );
  }
}
