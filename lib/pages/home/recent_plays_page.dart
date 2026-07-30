import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/library/favorite_song.dart';
import '../../services/library/recent_plays_repository.dart';
import '../../services/library/library_repository.dart';
import '../player/player_page.dart';
import '../player/player_controller.dart';
import '../login/login_page.dart';

class RecentPlaysPage extends ConsumerWidget {
  const RecentPlaysPage({super.key});

  static const routeName = 'recent_plays';
  static const routePath = '/recent_plays';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentPlaysAsync = ref.watch(recentPlaysListProvider);

    ref.listen<AsyncValue<List<FavoriteSong>>>(
      recentPlaysListProvider,
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
      appBar: AppBar(title: const Text('最近播放')),
      body: recentPlaysAsync.when(
        data: (recentPlays) {
          if (recentPlays.isEmpty) {
            return const Center(child: Text('暂无播放记录'));
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: recentPlays.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final song = recentPlays[index];
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
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            child: const Icon(Icons.history),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 48,
                            height: 48,
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            child: const Icon(Icons.history),
                          ),
                        ),
                      )
                    : Container(
                        width: 48,
                        height: 48,
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: const Icon(Icons.history),
                      ),
                trailing: const Icon(Icons.play_arrow_rounded),
                onTap: () async {
                  final songItem = song.toSongItem();
                  await ref
                      .read(playerControllerProvider.notifier)
                      .setPlayQueue([songItem], startIndex: 0);
                  if (context.mounted) {
                    context.go(PlayerPage.routePath);
                  }
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          final isSessionExpired = error is SessionExpiredException;
          return Center(
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
                  Text('$error', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: isSessionExpired
                        ? () => context.go(LoginPage.routePath)
                        : () => ref.refresh(recentPlaysListProvider),
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
