import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/library/favorite_song.dart';
import '../../models/library/song_item.dart';

/// 最近播放数据持久层，仅负责读/写 SharedPreferences
class RecentPlaysRepository {
  static const String _key = 'recent_plays';
  static const int _maxCount = 50;

  Future<List<FavoriteSong>> loadRecentPlays() async {
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

  Future<void> saveRecentPlays(List<FavoriteSong> recentPlays) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = recentPlays.map((f) => f.toMap()).toList();
    await prefs.setString(_key, jsonEncode(jsonList));
  }
}

final recentPlaysRepositoryProvider = Provider<RecentPlaysRepository>((ref) {
  return RecentPlaysRepository();
});

/// 最近播放列表 Provider
final recentPlaysListProvider =
    AsyncNotifierProvider<RecentPlaysNotifier, List<FavoriteSong>>(
  RecentPlaysNotifier.new,
);

class RecentPlaysNotifier extends AsyncNotifier<List<FavoriteSong>> {
  @override
  Future<List<FavoriteSong>> build() async {
    final repository = ref.read(recentPlaysRepositoryProvider);
    return repository.loadRecentPlays();
  }

  /// 记录播放，去重后将最近播放的歌曲移动到列表最前面
  ///
  /// 同首歌曲多次播放时，更新时间戳并移动到第一位。
  Future<void> recordPlay(SongItem song) async {
    final current = state.hasValue ? state.requireValue : <FavoriteSong>[];
    final entry = FavoriteSong.fromSongItem(song);

    // 移除已存在的同 ID 记录
    final updated = current.where((f) => f.songId != song.id).toList();

    // 插入到列表最前面
    updated.insert(0, entry);

    // 限制最大数量
    if (updated.length > RecentPlaysRepository._maxCount) {
      updated.removeRange(
        RecentPlaysRepository._maxCount,
        updated.length,
      );
    }

    final repository = ref.read(recentPlaysRepositoryProvider);
    await repository.saveRecentPlays(updated);
    state = AsyncData(updated);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(recentPlaysRepositoryProvider);
      return repository.loadRecentPlays();
    });
  }
}
