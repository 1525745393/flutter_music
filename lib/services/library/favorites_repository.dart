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

  Future<List<FavoriteSong>> getAllFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
    return jsonList
        .map((json) => FavoriteSong.fromMap(json as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> addFavorite(SongItem song) async {
    final favorites = await getAllFavorites();
    final existingIndex = favorites.indexWhere((f) => f.songId == song.id);
    if (existingIndex >= 0) {
      return;
    }
    final favorite = FavoriteSong.fromSongItem(song);
    favorites.insert(0, favorite);
    await _saveFavorites(favorites);
  }

  Future<void> removeFavorite(String songId) async {
    final favorites = await getAllFavorites();
    favorites.removeWhere((f) => f.songId == songId);
    await _saveFavorites(favorites);
  }

  Future<bool> isFavorite(String songId) async {
    final favorites = await getAllFavorites();
    return favorites.any((f) => f.songId == songId);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
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

final favoritesListProvider = FutureProvider<List<FavoriteSong>>((ref) async {
  final repository = ref.read(favoritesRepositoryProvider);
  return repository.getAllFavorites();
});

final isFavoriteProvider = FutureProvider.family<bool, String>((
  ref,
  songId,
) async {
  final repository = ref.read(favoritesRepositoryProvider);
  return repository.isFavorite(songId);
});
