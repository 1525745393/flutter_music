import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'player_controller.dart';
import '../../models/library/lyrics.dart';
import '../../models/library/song_item.dart';
import '../../services/library/library_repository.dart';
import '../login/login_page.dart';

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
    final lyricsAsync = ref.watch(lyricsProvider);
    final errorMessage = ref.watch(playerErrorMessageProvider);

    ref.listen(lyricsProvider, (previous, next) {
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
    });

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
            _buildCoverArt(context, currentSong),

            if (currentSong != null)
              Expanded(
                child: Column(
                  children: [
                    // 歌曲信息
                    Text(
                      currentSong.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${currentSong.artist} . ${currentSong.album}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // 错误提示
                    if (playerState == PlayerState.error && errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          errorMessage,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    const SizedBox(height: 16),

                    // 歌词区域（独立 widget，position tick 不影响外层）
                    Expanded(
                      child: _LyricsDisplay(lyricsAsync: lyricsAsync),
                    ),

                    const SizedBox(height: 8),

                    // 播放进度条（独立 widget，position tick 不影响外层）
                    const _ProgressSection(),

                    const SizedBox(height: 16),

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

                    const SizedBox(height: 8),

                    // 播放队列信息
                    if (playQueue.isNotEmpty &&
                        currentIndex >= 0 &&
                        currentIndex < playQueue.length)
                      Text(
                        '${currentIndex + 1} / ${playQueue.length}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
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

  Widget _buildCoverArt(BuildContext context, SongItem? currentSong) {
    return Container(
      width: 200,
      height: 200,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
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
    );
  }

  /// 格式化时长（Duration -> 分:秒）
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
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
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  child: const Icon(Icons.music_note),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: 48,
                                  height: 48,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  child: const Icon(Icons.album_rounded),
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
                        title: Text(
                          song.title,
                          style: TextStyle(
                            fontWeight:
                                isCurrentSong ? FontWeight.w600 : FontWeight.normal,
                            color: isCurrentSong
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                        ),
                        subtitle: Text(
                          '${song.artist} . ${song.album}',
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
}

/// 播放进度条（独立 widget，仅重建自身）
class _ProgressSection extends ConsumerWidget {
  const _ProgressSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positionAsync = ref.watch(positionStreamProvider);
    final durationAsync = ref.watch(durationStreamProvider);
    final isPlaying = ref.watch(playerControllerProvider) == PlayerState.playing;

    return positionAsync.when(
      data: (position) {
        return durationAsync.when(
          data: (duration) {
            final progress = duration != null && duration.inMilliseconds > 0
                ? position.inMilliseconds / duration.inMilliseconds
                : 0.0;

            return Column(
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    thumbShape: isPlaying
                        ? const RoundSliderThumbShape(enabledThumbRadius: 6)
                        : const RoundSliderThumbShape(enabledThumbRadius: 1),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: Theme.of(context).colorScheme.primary,
                    inactiveTrackColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    thumbColor: Theme.of(context).colorScheme.primary,
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: (value) {
                      if (duration != null) {
                        final newPosition = value * duration.inSeconds;
                        ref
                            .read(playerControllerProvider.notifier)
                            .seekTo(newPosition);
                      }
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        PlayerPage.formatDuration(position),
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        duration != null
                            ? PlayerPage.formatDuration(duration)
                            : '--:--',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const SizedBox(
            height: 52,
            child: Center(child: LinearProgressIndicator()),
          ),
          error: (error, stackTrace) => const SizedBox(
            height: 52,
            child: Center(child: Text('加载时长失败')),
          ),
        );
      },
      loading: () => const SizedBox(
        height: 52,
        child: Center(child: LinearProgressIndicator()),
      ),
      error: (error, stackTrace) => const SizedBox(
        height: 52,
        child: Center(child: Text('加载进度失败')),
      ),
    );
  }
}

/// 歌词显示区域（独立 widget，仅在歌词数据或播放位置变化时重建）
class _LyricsDisplay extends ConsumerWidget {
  const _LyricsDisplay({required this.lyricsAsync});

  final AsyncValue<List<LyricLine>> lyricsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positionAsync = ref.watch(positionStreamProvider);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: lyricsAsync.when(
        data: (lyrics) {
          if (lyrics.isEmpty) {
            return const Center(
              child: Text(
                '暂无歌词',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            );
          }

          final position = positionAsync.hasValue ? positionAsync.requireValue : null;
          final currentIndex = position != null
              ? LyricsParser.findCurrentLineIndex(lyrics, position.inMilliseconds)
              : 0;

          return ListView.builder(
            itemCount: lyrics.length,
            itemExtent: 36,
            padding: EdgeInsets.symmetric(
              vertical: (200.0 - 36) / 2, // 居中当前行
            ),
            itemBuilder: (context, index) {
              final line = lyrics[index];
              final isCurrentLine = index == currentIndex;

              return Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: isCurrentLine
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Text(
                    line.text,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: isCurrentLine
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight:
                          isCurrentLine ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => const Center(
          child: Text('加载歌词失败'),
        ),
      ),
    );
  }
}

/// 歌词 Provider
final lyricsProvider = FutureProvider<List<LyricLine>>((ref) async {
  final currentSong = ref.watch(currentSongProvider);
  if (currentSong == null) {
    return [];
  }

  final libraryRepository = ref.read(libraryRepositoryProvider);
  return await libraryRepository.fetchLyrics(currentSong.id);
});
