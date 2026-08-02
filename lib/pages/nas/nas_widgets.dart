import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/library/playlist.dart';
import '../../models/library/song_item.dart';
import '../../syno/syno_providers.dart';
import 'nas_providers.dart';/// NAS 封面占位组件
Widget nasCoverBox({required String? url, required IconData icon}) {
  if (url == null || url.isEmpty) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Icon(icon, size: 48),
    );
  }
  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: CachedNetworkImage(
      imageUrl: url,
      width: 48,
      height: 48,
      fit: BoxFit.cover,
      placeholder: (_, _) =>
          SizedBox(width: 48, height: 48, child: Icon(icon)),
      errorWidget: (_, _, _) =>
          SizedBox(width: 48, height: 48, child: Icon(icon)),
    ),
  );
}

/// NAS 歌曲收藏按钮
///
/// 通过 [nasFavoritesProvider] 判断收藏状态，
/// 点击后调用群晖评分 5（收藏）/ 0（取消）接口。
class NasFavoriteButton extends ConsumerWidget {
  const NasFavoriteButton({super.key, required this.song});

  final SongItem song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(nasFavoritesProvider);
    final isFavorite = favoritesAsync.maybeWhen(
      data: (items) => items.any((f) => f.songId == song.id),
      orElse: () => false,
    );

    return IconButton(
      icon: Icon(
        isFavorite ? Icons.favorite : Icons.favorite_border,
        color: isFavorite ? Colors.red : null,
      ),
      tooltip: isFavorite ? '取消收藏' : '收藏',
      onPressed: () async {
        try {
          final repo = ref.read(synoMusicRepositoryProvider);
          if (isFavorite) {
            await repo.removeFavorite(song.id);
          } else {
            await repo.addFavorite(song);
          }
          ref.invalidate(nasFavoritesProvider);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('操作失败：$e')),
            );
          }
        }
      },
    );
  }
}

/// NAS 添加到歌单按钮
///
/// 弹出当前 NAS 歌单列表供选择，选中后调用
/// [SynoMusicRepository.addSongToPlaylist]。
class NasAddToPlaylistButton extends ConsumerWidget {
  const NasAddToPlaylistButton({super.key, required this.song});

  final SongItem song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.playlist_add),
      tooltip: '添加到歌单',
      onPressed: () async {
        final playlists = ref.read(nasPlaylistsProvider);
        final list = playlists.maybeWhen(
          data: (items) => items,
          orElse: () => <Playlist>[],
        );
        if (list.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('暂无歌单，请先在「歌单」Tab 创建')),
            );
          }
          return;
        }
        final selected = await showModalBottomSheet<String>(
          context: context,
          builder: (sheetContext) {
            return SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      '添加到歌单',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...list.map(
                    (p) => ListTile(
                      leading: const Icon(Icons.queue_music),
                      title: Text(p.name),
                      subtitle: Text('${p.songCount} 首'),
                      onTap: () => Navigator.of(sheetContext).pop(p.id),
                    ),
                  ),
                ],
              ),
            );
          },
        );
        if (selected == null || !context.mounted) return;
        try {
          final repo = ref.read(synoMusicRepositoryProvider);
          await repo.addSongToPlaylist(selected, song.id);
          ref.invalidate(nasPlaylistSongsProvider(selected));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('已添加到歌单')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('添加失败：$e')),
            );
          }
        }
      },
    );
  }
}
