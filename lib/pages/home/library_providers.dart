import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/library/song_item.dart';
import '../../services/library/library_repository.dart';

final songsProvider = FutureProvider<List<SongItem>>((ref) {
  return ref.read(libraryRepositoryProvider).fetchSongs();
});
