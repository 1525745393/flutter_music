import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/library/song_item.dart';
import '../../models/library/artist.dart';
import '../../models/library/album.dart';
import '../../services/library/library_repository.dart';

final songsProvider = FutureProvider<List<SongItem>>((ref) {
  return ref.read(libraryRepositoryProvider).fetchSongs();
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
