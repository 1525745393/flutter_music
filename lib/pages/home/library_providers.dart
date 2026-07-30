import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/library/song_item.dart';
import '../../models/library/artist.dart';
import '../../models/library/album.dart';
import '../../models/library/folder_item.dart';
import '../../services/library/library_repository.dart';

/// 歌曲排序字段
class SongSortByNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? value) => state = value;
}

final songSortByProvider = NotifierProvider<SongSortByNotifier, String?>(
  SongSortByNotifier.new,
);

/// 歌曲排序方向
class SongSortDirectionNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? value) => state = value;
}

final songSortDirectionProvider =
    NotifierProvider<SongSortDirectionNotifier, String?>(
  SongSortDirectionNotifier.new,
);

final songsProvider = FutureProvider<List<SongItem>>((ref) {
  final sortBy = ref.watch(songSortByProvider);
  final sortDirection = ref.watch(songSortDirectionProvider);
  return ref
      .read(libraryRepositoryProvider)
      .fetchSongs(sortBy: sortBy, sortDirection: sortDirection);
});

final artistsProvider = FutureProvider<List<Artist>>((ref) {
  return ref.read(libraryRepositoryProvider).fetchArtists();
});

final albumsProvider =
    FutureProvider.family<List<Album>, String?>((ref, artistName) {
  return ref
      .read(libraryRepositoryProvider)
      .fetchAlbums(artistName: artistName);
});

final albumSongsProvider =
    FutureProvider.family<List<SongItem>, Album>((ref, album) {
  return ref.read(libraryRepositoryProvider).fetchAlbumSongs(
        albumName: album.title,
        albumArtist: album.artist,
      );
});

final foldersProvider =
    FutureProvider.family<List<FolderItem>, String?>((ref, parentId) {
  return ref.read(libraryRepositoryProvider).fetchFolders(id: parentId);
});
