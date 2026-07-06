import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/synology_api.dart';
import '../auth/auth_repository.dart';
import '../../models/library/song_item.dart';
import '../../models/library/lyrics.dart';

/// 音乐库异常类
class LibraryException implements Exception {
  const LibraryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 会话失效异常，需要重新登录
class SessionExpiredException extends LibraryException {
  const SessionExpiredException(super.message);
}

class LibraryRepository {
  LibraryRepository(this._authRepository);

  final AuthRepository _authRepository;

  Future<List<SongItem>> fetchSongs({int limit = 100}) async {
    final session = await _authRepository.loadSession();
    if (session == null) {
      throw const SessionExpiredException('会话不存在，请先登录');
    }

    final api = SynologyAudioStationApi(
      serverUrl: session.serverUrl,
      apiInfo: _authRepository.apiInfo,
    );
    try {
      final body = await api.listSongs(sid: session.sessionId, limit: limit);

      if (body['success'] != true) {
        final code = (body['error'] as Map<String, dynamic>?)?['code'] as int?;
        // 会话失效相关错误码
        if (_isSessionExpired(code)) {
          await _authRepository.clearSession();
          throw const SessionExpiredException('会话已失效，请重新登录');
        }
        throw LibraryException(
          '音乐库请求失败：${_mapLibraryError(code)}',
        );
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
      // HTTP 401/403 且响应不是 JSON，可能是会话失效或权限问题
      if (e.statusCode == 401 || e.statusCode == 403) {
        await _authRepository.clearSession();
        throw SessionExpiredException(
          '认证失败（HTTP ${e.statusCode}），请重新登录',
        );
      }
      throw LibraryException('音乐库请求失败：${e.message}');
    }
  }

  /// 获取歌词
  Future<List<LyricLine>> fetchLyrics(String songId) async {
    final session = await _authRepository.loadSession();
    if (session == null) {
      throw const SessionExpiredException('会话不存在，请先登录');
    }

    final api = SynologyAudioStationApi(
      serverUrl: session.serverUrl,
      apiInfo: _authRepository.apiInfo,
    );
    try {
      final body = await api.getLyrics(sid: session.sessionId, songId: songId);

      if (body['success'] != true) {
        final code = (body['error'] as Map<String, dynamic>?)?['code'] as int?;
        if (_isSessionExpired(code)) {
          await _authRepository.clearSession();
          throw const SessionExpiredException('会话已失效，请重新登录');
        }
        throw LibraryException(
          '歌词请求失败：${_mapLibraryError(code)}',
        );
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
      if (e.statusCode == 401 || e.statusCode == 403) {
        await _authRepository.clearSession();
        throw SessionExpiredException(
          '认证失败（HTTP ${e.statusCode}），请重新登录',
        );
      }
      throw LibraryException('歌词请求失败：${e.message}');
    }
  }

  /// 判断错误码是否表示会话失效
  bool _isSessionExpired(int? code) {
    // 群晖 API 常见的会话失效错误码
    // 105: 会话超时或失效
    // 106: 会话不存在
    // 107: 会话已被其他登录踢掉
    // 401: 未授权
    // 402: 权限不足（也可能是会话问题）
    return code == 105 || code == 106 || code == 107 || code == 401;
  }

  /// 映射音乐库错误码为用户友好消息
  String _mapLibraryError(int? code) {
    switch (code) {
      case 100:
        return '未知错误';
      case 101:
        return '参数错误';
      case 102:
        return 'API不存在';
      case 103:
        return '方法不存在';
      case 104:
        return 'API版本不支持';
      case 105:
        return '会话已失效，请重新登录';
      case 106:
        return '会话不存在';
      case 107:
        return '会话已被踢下线';
      case 108:
        return '文件不存在';
      case 400:
        return '请求参数错误';
      case 401:
        return '未授权，请重新登录';
      case 402:
        return '权限不足，请检查账户权限';
      case 403:
        return '需要两步验证';
      case 404:
        return '资源不存在';
      case 407:
        return 'IP 已被封禁';
      default:
        return '错误码 ${code ?? 'unknown'}';
    }
  }
}

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return LibraryRepository(ref.read(authRepositoryProvider));
});
