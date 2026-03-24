import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlayerPage extends ConsumerWidget {
  const PlayerPage({super.key});

  static const routeName = 'player';
  static const routePath = '/player';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong = ref.watch(currentSongProvider);
    final playerState = ref.watch(playerControllerProvider);
    final playQueue = ref.watch(playQueueProvider);
    final currentIndex = ref.watch(currentIndexProvider);
    final positionAsync = ref.watch(positionStreamProvider);
    final durationAsync = ref.watch(durationStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('正在播放'),
        actions: [
          IconButton(
            onPressed: () {
              // 添加播放列表按钮（后续实现）
            },
            icon: const Icon(Icons.playlist_play_rounded),
            tooltip: '播放列表',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 专辑封面
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: currentSong != null
                  ? const Icon(Icons.album_rounded, size: 80)
                  : const Icon(Icons.music_note_rounded, size: 80),
            ),
            const SizedBox(height: 24),
            
            // 歌曲信息
            if (currentSong != null)
              Column(
                children: [
                  Text(
                    currentSong.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${currentSong.artist} · ${currentSong.album}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  
                  // 播放进度条
                  positionAsync.when(
                    data: (position) {
                      return durationAsync.when(
                        data: (duration) {
                          final progress = duration != null && duration.inMilliseconds > 0
                              ? position.inMilliseconds / duration.inMilliseconds
                              : 0.0;
                          
                          return Column(
                            children: [
                              Slider(
                                value: progress.clamp(0.0, 1.0),
                                onChanged: (value) {
                                  if (duration != null) {
                                    final newPosition = value * duration.inSeconds;
                                    ref.read(playerControllerProvider.notifier).seekTo(newPosition);
                                  }
                                },
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(position),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    duration != null ? _formatDuration(duration) : '--:--',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const Text('加载时长失败'),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('加载进度失败'),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 播放控制按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () async {
                          await ref.read(playerControllerProvider.notifier).previous();
                        },
                        icon: const Icon(Icons.skip_previous_rounded, size: 36),
                        tooltip: '上一首',
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        onPressed: () async {
                          switch (playerState) {
                            case PlayerState.playing:
                              await ref.read(playerControllerProvider.notifier).pause();
                              break;
                            case PlayerState.paused:
                            case PlayerState.idle:
                            case PlayerState.error:
                              await ref.read(playerControllerProvider.notifier).play();
                              break;
                            case PlayerState.loading:
                              // 加载中，不执行任何操作
                              break;
                          }
                        },
                        icon: Icon(
                          playerState == PlayerState.playing
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_filled_rounded,
                          size: 56,
                        ),
                        tooltip: playerState == PlayerState.playing ? '暂停' : '播放',
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        onPressed: () async {
                          await ref.read(playerControllerProvider.notifier).next();
                        },
                        icon: const Icon(Icons.skip_next_rounded, size: 36),
                        tooltip: '下一首',
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 播放队列信息
                  if (playQueue.isNotEmpty && currentIndex >= 0 && currentIndex < playQueue.length)
                    Text(
                      '${currentIndex + 1} / ${playQueue.length}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              )
            else
              const Column(
                children: [
                  Icon(Icons.music_off_rounded, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('没有正在播放的歌曲'),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// 格式化时长（Duration -> 分:秒）
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
