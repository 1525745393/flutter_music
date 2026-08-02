import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/library/song_item.dart';
import '../../syno/syno_providers.dart';
import 'nas_providers.dart';

/// NAS 封面占位组件
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
