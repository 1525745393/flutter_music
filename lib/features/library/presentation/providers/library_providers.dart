import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/song_item.dart';
import '../../data/repositories/library_repository.dart';

final songsProvider = FutureProvider<List<SongItem>>((ref) {
  return ref.read(libraryRepositoryProvider).fetchSongs();
});
