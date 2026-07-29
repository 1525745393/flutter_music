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

/// 收藏数据持久层，仅负责读/写 SharedPreferences
class FavoritesRepository {
  static const String _key = 'favorites';

  Future<List<FavoriteSong>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .whereType<Map<String, dynamic>>()
          .map((json) => FavoriteSong.fromMap(json))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      return [];
    }
  }

  Future<void> saveFavorites(List<FavoriteSong> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = favorites.map((f) => f.toMap()).toList();
    await prefs.setString(_key, jsonEncode(jsonList));
  }
}

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return FavoritesRepository();
});

/// 收藏列表 Provider，由 Notifier 统一管理状态
final favoritesListProvider =
    AsyncNotifierProvider<FavoritesNotifier, List<FavoriteSong>>(
  FavoritesNotifier.new,
);

class FavoritesNotifier extends AsyncNotifier<List<FavoriteSong>> {
  @override
  Future<List<FavoriteSong>> build() async {
    final repository = ref.read(favoritesRepositoryProvider);
    return repository.loadFavorites();
  }

  /// 添加收藏，同步更新状态和持久化
  ///
  /// 如果歌曲已在收藏列表中，则忽略本次操作。
  Future<void> addFavorite(SongItem song) async {
    final current = state.hasValue ? state.requireValue : <FavoriteSong>[];
    if (current.any((f) => f.songId == song.id)) return;

    final favorite = FavoriteSong.fromSongItem(song);
    final updated = [favorite, ...current];
    final repository = ref.read(favoritesRepositoryProvider);
    await repository.saveFavorites(updated);
    state = AsyncData(updated);
  }

  /// 移除收藏，同步更新状态和持久化
  Future<void> removeFavorite(String songId) async {
    final current = state.hasValue ? state.requireValue : <FavoriteSong>[];
    final updated = current.where((f) => f.songId != songId).toList();
    if (updated.length == current.length) return; // 未找到，无需更新

    final repository = ref.read(favoritesRepositoryProvider);
    await repository.saveFavorites(updated);
    state = AsyncData(updated);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(favoritesRepositoryProvider);
      return repository.loadFavorites();
    });
  }
}

/// 收藏 ID 集合 Provider（用于快速 O(1) 判断）
final favoriteIdsProvider = FutureProvider<Set<String>>((ref) async {
  final favorites = await ref.watch(favoritesListProvider.future);
  return favorites.map((f) => f.songId).toSet();
});
