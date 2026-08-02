import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/library/album.dart';
import '../../models/library/artist.dart';
import '../../models/library/favorite_song.dart';
import '../../models/library/playlist.dart';
import '../../models/library/song_item.dart';
import '../../syno/syno_providers.dart';
import '../player/player_controller.dart';

/// NAS 音乐库数据 Provider（直接依赖群晖实现）
final nasSongsProvider = FutureProvider<List<SongItem>>((ref) {
  final repo = ref.watch(synoMusicRepositoryProvider);
  return repo.fetchSongs();
});

final nasAlbumsProvider = FutureProvider<List<Album>>((ref) {
  final repo = ref.watch(synoMusicRepositoryProvider);
  return repo.fetchAlbums();
});

final nasArtistsProvider = FutureProvider<List<Artist>>((ref) {
  final repo = ref.watch(synoMusicRepositoryProvider);
  return repo.fetchArtists();
});

/// 某歌手的专辑列表
final nasArtistAlbumsProvider =
    FutureProvider.family<List<Album>, String>((ref, artistName) {
  final repo = ref.watch(synoMusicRepositoryProvider);
  return repo.fetchAlbums(artistName: artistName);
});

/// 某专辑的歌曲列表
final nasAlbumSongsProvider =
    FutureProvider.family<List<SongItem>, Album>((ref, album) {
  final repo = ref.watch(synoMusicRepositoryProvider);
  return repo.fetchAlbumSongs(album);
});

final nasFavoritesProvider = FutureProvider<List<FavoriteSong>>((ref) {
  final repo = ref.watch(synoMusicRepositoryProvider);
  return repo.fetchFavorites();
});

final nasPlaylistsProvider = FutureProvider<List<Playlist>>((ref) {
  final repo = ref.watch(synoMusicRepositoryProvider);
  return repo.fetchPlaylists();
});

/// 某歌单内的歌曲
final nasPlaylistSongsProvider =
    FutureProvider.family<List<SongItem>, String>((ref, playlistId) {
  final repo = ref.watch(synoMusicRepositoryProvider);
  return repo.fetchPlaylistSongs(playlistId);
});

/// 通过 NAS 源播放队列
///
/// [resolver] 由 SynoMusicRepository 提供完整音频 URL，
/// 复用现有 [PlayerController] 与播放页。
Future<void> playNasQueue(
  WidgetRef ref,
  List<SongItem> queue, {
  int startIndex = 0,
}) async {
  final repo = ref.read(synoMusicRepositoryProvider);
  await ref.read(playerControllerProvider.notifier).setPlayQueueWithResolver(
        queue,
        startIndex: startIndex,
        resolver: (song) => repo.getPlaybackUrl(song),
      );
}
