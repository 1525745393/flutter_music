import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/library/favorite_song.dart';
import '../../models/library/song_item.dart';

class FavoritesException implements Exception {
  const FavoritesException(this.message);
  final String message;
  @override
  String toString() => message;
}

class FavoritesRepository {
  static const String _key = 'favorites';

  List<FavoriteSong>? _cached;

  Future<List<FavoriteSong>> getAllFavorites() async {
    if (_cached != null) return List.unmodifiable(_cached!);
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null || jsonString.isEmpty) {
      _cached = [];
      return [];
    }
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
      _cached = jsonList
          .whereType<Map<String, dynamic>>()
          .map((json) => FavoriteSong.fromMap(json))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return List.unmodifiable(_cached!);
    } catch (e) {
      _cached = [];
      return [];
    }
  }

  Future<void> addFavorite(SongItem song) async {
    final favorites = await getAllFavorites();
    final mutable = List<FavoriteSong>.from(favorites);
    final existingIndex = mutable.indexWhere((f) => f.songId == song.id);
    if (existingIndex >= 0) {
      return;
    }
    final favorite = FavoriteSong.fromSongItem(song);
    mutable.insert(0, favorite);
    _cached = mutable;
    await _saveFavorites(mutable);
  }

  Future<void> removeFavorite(String songId) async {
    final favorites = await getAllFavorites();
    final mutable = List<FavoriteSong>.from(favorites);
    mutable.removeWhere((f) => f.songId == songId);
    _cached = mutable;
    await _saveFavorites(mutable);
  }

  Future<bool> isFavorite(String songId) async {
    final favorites = await getAllFavorites();
    return favorites.any((f) => f.songId == songId);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    _cached = [];
  }

  Future<void> _saveFavorites(List<FavoriteSong> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = favorites.map((f) => f.toMap()).toList();
    await prefs.setString(_key, jsonEncode(jsonList));
  }
}

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return FavoritesRepository();
});

final favoritesListProvider = AsyncNotifierProvider<FavoritesNotifier, List<FavoriteSong>>(
  FavoritesNotifier.new,
);

class FavoritesNotifier extends AsyncNotifier<List<FavoriteSong>> {
  @override
  Future<List<FavoriteSong>> build() async {
    final repository = ref.read(favoritesRepositoryProvider);
    return repository.getAllFavorites();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(favoritesRepositoryProvider);
      return repository.getAllFavorites();
    });
  }
}

final isFavoriteProvider = FutureProvider.family<bool, String>((
  ref,
  songId,
) async {
  final repository = ref.read(favoritesRepositoryProvider);
  return repository.isFavorite(songId);
});

final favoriteIdsProvider = FutureProvider<Set<String>>((ref) async {
  final favorites = await ref.watch(favoritesListProvider.future);
  return favorites.map((f) => f.songId).toSet();
});
