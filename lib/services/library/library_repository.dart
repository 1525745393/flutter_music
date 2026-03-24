import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/synology_api.dart';
import '../auth/auth_repository.dart';
import '../../models/library/song_item.dart';
import '../../models/library/lyrics.dart';

class LibraryException implements Exception {
  const LibraryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LibraryRepository {
  LibraryRepository(this._authRepository);

  final AuthRepository _authRepository;

  Future<List<SongItem>> fetchSongs({int limit = 100}) async {
    final session = await _authRepository.loadSession();
    if (session == null) {
      throw const LibraryException('会话不存在，请先登录');
    }

    final api = SynologyAudioStationApi(serverUrl: session.serverUrl);
    try {
      final body = await api.listSongs(sid: session.sessionId, limit: limit);

      if (body['success'] != true) {
        final code = (body['error'] as Map<String, dynamic>?)?['code'] as int?;
        throw LibraryException('音乐库请求失败：错误码 ${code ?? 'unknown'}');
      }

      final songs =
          (body['data'] as Map<String, dynamic>?)?['songs'] as List<dynamic>? ??
          [];
      return songs
          .whereType<Map<String, dynamic>>()
          .map((map) {
            final song = SongItem.fromMap(map);
            // 构造封面图URL
            final coverUrl = api.buildCoverUrl(
              sid: session.sessionId,
              songId: song.id,
              size: 300,
            );
            return song.copyWith(coverUrl: coverUrl);
          })
          .toList(growable: false);
    } on DioException catch (e) {
      throw LibraryException('网络异常：${e.message}');
    } on SynologyApiException catch (e) {
      throw LibraryException('音乐库请求失败：${e.message}');
    }
  }

  /// 获取歌词
  Future<List<LyricLine>> fetchLyrics(String songId) async {
    final session = await _authRepository.loadSession();
    if (session == null) {
      throw const LibraryException('会话不存在，请先登录');
    }

    final api = SynologyAudioStationApi(serverUrl: session.serverUrl);
    try {
      final body = await api.getLyrics(sid: session.sessionId, songId: songId);

      if (body['success'] != true) {
        final code = (body['error'] as Map<String, dynamic>?)?['code'] as int?;
        throw LibraryException('歌词请求失败：错误码 ${code ?? 'unknown'}');
      }

      // 获取歌词文本
      final lyricsData = body['data'] as Map<String, dynamic>?;
      final lyricsText = lyricsData?['lyrics'] as String?;

      if (lyricsText == null || lyricsText.isEmpty) {
        return [];
      }

      // 解析歌词
      return LyricsParser.parseLrc(lyricsText);
    } on DioException catch (e) {
      throw LibraryException('网络异常：${e.message}');
    } on SynologyApiException catch (e) {
      throw LibraryException('歌词请求失败：${e.message}');
    }
  }
}

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return LibraryRepository(ref.read(authRepositoryProvider));
});
