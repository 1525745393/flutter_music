import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../pages/player/player_controller.dart';
import '../pages/player/player_page.dart';

/// 迷你播放控制栏
///
/// 显示在 HomePage 底部，展示当前播放信息并提供基本播放控制。
/// 点击可跳转到完整播放页面。
class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong = ref.watch(currentSongProvider);
    final playerState = ref.watch(playerControllerProvider);

    if (currentSong == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => context.go(PlayerPage.routePath),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 0.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            // 封面缩略图
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 44,
                height: 44,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.music_note, size: 24),
              ),
            ),
            const SizedBox(width: 12),

            // 歌曲信息
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentSong.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${currentSong.artist} . ${currentSong.album}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // 播放控制
            IconButton(
              onPressed: () async {
                final notifier = ref.read(playerControllerProvider.notifier);
                if (playerState == PlayerState.playing) {
                  await notifier.pause();
                } else {
                  await notifier.play();
                }
              },
              icon: Icon(
                playerState == PlayerState.playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
              iconSize: 32,
              tooltip: playerState == PlayerState.playing ? '暂停' : '播放',
            ),
            IconButton(
              onPressed: () async {
                await ref.read(playerControllerProvider.notifier).next();
              },
              icon: const Icon(Icons.skip_next_rounded),
              tooltip: '下一首',
            ),
          ],
        ),
      ),
    );
  }
}
