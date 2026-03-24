import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'player_controller.dart';
import '../../models/library/lyrics.dart';
import '../../services/library/library_repository.dart';

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
    final lyricsAsync = ref.watch(lyricsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('正在播放'),
        actions: [
          IconButton(
            onPressed: () {
              _showPlayQueueBottomSheet(context, ref);
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
              clipBehavior: Clip.antiAlias,
              child: currentSong?.coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: currentSong!.coverUrl!,
                      placeholder: (context, url) => const Center(
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => const Icon(
                        Icons.album_rounded,
                        size: 80,
                        color: Colors.grey,
                      ),
                      fit: BoxFit.cover,
                    )
                  : currentSong != null
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

                  // 歌词显示
                  _buildLyricsSection(context, lyricsAsync, positionAsync),
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
                        error: (error, stackTrace) => const Text('加载时长失败'),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (error, stackTrace) => const Text('加载进度失败'),
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

  /// 显示播放列表底部弹窗
  void _showPlayQueueBottomSheet(BuildContext context, WidgetRef ref) {
    final playQueue = ref.read(playQueueProvider);
    final currentIndex = ref.read(currentIndexProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '播放列表',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      tooltip: '关闭',
                    ),
                  ],
                ),
              ),
              // 播放列表
              if (playQueue.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('播放列表为空'),
                )
              else
                SizedBox(
                  height: 300,
                  child: ListView.builder(
                    itemCount: playQueue.length,
                    itemBuilder: (context, index) {
                      final song = playQueue[index];
                      final isCurrentSong = index == currentIndex;
                      return ListTile(
                        leading: song.coverUrl != null
                            ? CachedNetworkImage(
                                imageUrl: song.coverUrl!,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  width: 48,
                                  height: 48,
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  child: const Icon(Icons.music_note),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: 48,
                                  height: 48,
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  child: const Icon(Icons.album_rounded),
                                ),
                              )
                            : Container(
                                width: 48,
                                height: 48,
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.music_note),
                              ),
                        title: Text(
                          song.title,
                          style: TextStyle(
                            fontWeight: isCurrentSong ? FontWeight.w600 : FontWeight.normal,
                            color: isCurrentSong
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                        ),
                        subtitle: Text(
                          '${song.artist} · ${song.album}',
                          style: TextStyle(
                            color: isCurrentSong
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: isCurrentSong
                            ? Icon(
                                Icons.play_circle_filled,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                        onTap: () async {
                          // 切换到选中的歌曲
                          await ref
                              .read(playerControllerProvider.notifier)
                              .setPlayQueue(playQueue, startIndex: index);
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 构建歌词显示区域
  Widget _buildLyricsSection(
    BuildContext context,
    AsyncValue<List<LyricLine>> lyricsAsync,
    AsyncValue<Duration> positionAsync,
  ) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: lyricsAsync.when(
        data: (lyrics) {
          if (lyrics.isEmpty) {
            return const Center(
              child: Text(
                '暂无歌词',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            );
          }

          return positionAsync.when(
            data: (position) {
              final currentIndex = LyricsParser.findCurrentLineIndex(
                lyrics,
                position.inMilliseconds,
              );

              return ListView.builder(
                itemCount: lyrics.length,
                itemExtent: 32,
                itemBuilder: (context, index) {
                  final line = lyrics[index];
                  final isCurrentLine = index == currentIndex;

                  return Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        color: isCurrentLine
                            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        line.text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: isCurrentLine
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: isCurrentLine ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (error, stackTrace) => const Center(
              child: Text('加载歌词失败'),
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => const Center(
          child: Text('加载歌词失败'),
        ),
      ),
    );
  }
}

/// 歌词Provider
final lyricsProvider = FutureProvider<List<LyricLine>>((ref) async {
  final currentSong = ref.watch(currentSongProvider);
  if (currentSong == null) {
    return [];
  }

  final libraryRepository = ref.read(libraryRepositoryProvider);
  return await libraryRepository.fetchLyrics(currentSong.id);
});
