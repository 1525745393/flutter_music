import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/synology_api.dart';
import '../auth/auth_repository.dart';
import '../../models/library/song_item.dart';
import '../../models/library/lyrics.dart';
import '../../models/library/artist.dart';
import '../../models/library/album.dart';

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

  /// 统一处理音乐库 API 调用的样板逻辑：
  /// 会话校验、API 实例创建、success 校验、会话失效检测、网络与 API 异常处理。
  ///
  /// [apiCall] 接收已创建好的 API 实例与 sessionId，返回原始响应体；
  /// [onSuccess] 在响应成功时被调用，可使用 [api] 构造封面 URL 等附加资源；
  /// [errorPrefix] 用于错误消息前缀（如 "音乐库请求失败"）。
  Future<T> _execute<T>({
    required Future<Map<String, dynamic>> Function(
      SynologyAudioStationApi api,
      String sid,
    ) apiCall,
    required T Function(
      Map<String, dynamic> body,
      SynologyAudioStationApi api,
      String sid,
    ) onSuccess,
    String? errorPrefix,
  }) async {
    final session = await _authRepository.loadSession();
    if (session == null) {
      throw const SessionExpiredException('会话不存在，请先登录');
    }

    final api = SynologyAudioStationApi(
      serverUrl: session.serverUrl,
      apiInfo: _authRepository.apiInfo,
      synoToken: _authRepository.synoToken,
    );
    final sid = session.sessionId;
    try {
      final body = await apiCall(api, sid);

      if (body['success'] != true) {
        final code = (body['error'] as Map<String, dynamic>?)?['code'] as int?;
        // 会话失效相关错误码
        if (_isSessionExpired(code)) {
          await _authRepository.clearSession();
          throw const SessionExpiredException('会话已失效，请重新登录');
        }
        throw LibraryException(
          '${errorPrefix ?? '请求失败'}：${_mapLibraryError(code)}',
        );
      }

      return onSuccess(body, api, sid);
    } on DioException catch (e) {
      throw LibraryException('网络异常：${e.message ?? e.type.name}');
    } on SynologyApiException catch (e) {
      // HTTP 401/403 且响应不是 JSON，可能是会话失效或权限问题
      if (e.statusCode == 401 || e.statusCode == 403) {
        await _authRepository.clearSession();
        throw SessionExpiredException(
          '认证失败（HTTP ${e.statusCode}），请重新登录',
        );
      }
      throw LibraryException('${errorPrefix ?? '请求失败'}：${e.message}');
    }
  }

  Future<List<SongItem>> fetchSongs({int limit = 100}) async {
    return _execute(
      apiCall: (api, sid) => api.listSongs(sid: sid, limit: limit),
      onSuccess: (body, api, sid) {
        final songs =
            (body['data'] as Map<String, dynamic>?)?['songs'] as List<dynamic>? ??
                [];
        return songs
            .whereType<Map<String, dynamic>>()
            .map((map) {
              final song = SongItem.fromMap(map);
              // 构造封面图URL
              final coverUrl = api.buildSongCoverUrl(
                sid: sid,
                songId: song.id,
              );
              return song.copyWith(coverUrl: coverUrl);
            })
            .toList(growable: false);
      },
      errorPrefix: '音乐库请求失败',
    );
  }

  /// 获取歌手列表
  Future<List<Artist>> fetchArtists({int limit = 100}) async {
    return _execute(
      apiCall: (api, sid) => api.listArtists(sid: sid, limit: limit),
      onSuccess: (body, api, sid) {
        final artists =
            (body['data'] as Map<String, dynamic>?)?['artists'] as List<dynamic>? ??
                [];
        return artists
            .whereType<Map<String, dynamic>>()
            .map((map) {
              final artist = Artist.fromMap(map);
              // 构造歌手封面URL
              final coverUrl = api.buildArtistCoverUrl(
                sid: sid,
                artistName: artist.name,
              );
              return artist.copyWith(coverUrl: coverUrl);
            })
            .toList(growable: false);
      },
      errorPrefix: '歌手列表请求失败',
    );
  }

  /// 获取专辑列表
  Future<List<Album>> fetchAlbums({
    int limit = 100,
    String? artistName,
  }) async {
    return _execute(
      apiCall: (api, sid) => api.listAlbums(
        sid: sid,
        limit: limit,
        artist: artistName,
        additional: 'avg_rating',
      ),
      onSuccess: (body, api, sid) {
        final albums =
            (body['data'] as Map<String, dynamic>?)?['albums'] as List<dynamic>? ??
                [];
        return albums
            .whereType<Map<String, dynamic>>()
            .map((map) {
              final album = Album.fromMap(map);
              // 构造专辑封面URL
              final coverUrl = api.buildAlbumCoverUrl(
                sid: sid,
                albumName: album.title,
                albumArtistName: album.artist,
              );
              return album.copyWith(coverUrl: coverUrl);
            })
            .toList(growable: false);
      },
      errorPrefix: '专辑列表请求失败',
    );
  }

  /// 获取指定专辑的歌曲列表
  Future<List<SongItem>> fetchAlbumSongs({
    required String albumName,
    required String albumArtist,
  }) async {
    return _execute(
      apiCall: (api, sid) => api.listSongs(
        sid: sid,
        limit: 500,
        album: albumName,
        albumArtist: albumArtist,
        // 注意：AudioStation 文档中 sort_by 可选值为 title/name/artist/random
        // 专辑内歌曲默认按曲目号排序，此处不指定排序方式以使用 API 默认行为
      ),
      onSuccess: (body, api, sid) {
        final songs =
            (body['data'] as Map<String, dynamic>?)?['songs'] as List<dynamic>? ??
                [];
        return songs
            .whereType<Map<String, dynamic>>()
            .map((map) {
              final song = SongItem.fromMap(map);
              final coverUrl = api.buildSongCoverUrl(
                sid: sid,
                songId: song.id,
              );
              return song.copyWith(coverUrl: coverUrl);
            })
            .toList(growable: false);
      },
      errorPrefix: '专辑歌曲请求失败',
    );
  }

  /// 获取歌词
  Future<List<LyricLine>> fetchLyrics(String songId) async {
    return _execute(
      apiCall: (api, sid) => api.getLyrics(sid: sid, songId: songId),
      onSuccess: (body, api, sid) {
        // 获取歌词文本
        final lyricsData = body['data'] as Map<String, dynamic>?;
        final lyricsText = lyricsData?['lyrics'] as String?;

        if (lyricsText == null || lyricsText.isEmpty) {
          return [];
        }

        // 解析歌词
        return LyricsParser.parseLrc(lyricsText);
      },
      errorPrefix: '歌词请求失败',
    );
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
