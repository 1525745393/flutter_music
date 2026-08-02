import 'package:dio/dio.dart';

import '../../core/network/synology_api.dart';
import '../../models/library/album.dart';
import '../../models/library/artist.dart';
import '../../models/library/favorite_song.dart';
import '../../models/library/playlist.dart';
import '../../models/library/song_item.dart';
import '../../syno/adapter/dsm_version_adapter.dart';
import '../../syno/auth/auth_interceptor.dart';
import '../../syno/auth/nas_auth_api.dart';
import '../../syno/config/nas_config.dart';
import '../../syno/config/nas_config_store.dart';
import '../../syno/session/nas_session.dart';
import 'music_source_repository.dart';

/// 群晖 AudioStation 音乐数据源实现
///
/// 组合现有 Synology API 层（SynologyAudioStationApi / SynologyAuthApi），
/// 实现 [MusicSourceRepository] 统一接口。返回的封面/播放地址为完整 URL，
/// 可直接交给现有播放器。
class SynoMusicRepository implements MusicSourceRepository {
  SynoMusicRepository({
    required this.configStore,
    required NasAuthApi authApi,
  }) : _authApi = authApi;

  final NasConfigStore configStore;
  final NasAuthApi _authApi;

  /// 当前 NAS 配置（内存缓存，connect 后有效）
  NasConfig? _config;

  /// 当前 API 实例（按需创建，持有拦截器与证书配置）
  SynologyAudioStationApi? _api;

  /// 版本适配器
  DsmVersionAdapter get _versionAdapter =>
      DsmVersionAdapter(apiInfo: _authApi.session?.apiInfo);

  @override
  String get sourceId => 'syno';

  @override
  String get sourceName => '群晖 AudioStation';

  @override
  bool get isConnected => _authApi.isLoggedIn;

  // ---------- 会话 ----------

  @override
  Future<void> connect() async {
    final config = await configStore.loadConfig();
    if (config == null) {
      throw const MusicSourceConnectionException('未配置 NAS 服务器');
    }
    _config = config;

    // 优先使用内存会话（登录后保留 apiInfo/synoToken）
    if (_authApi.isLoggedIn) return;

    // 无内存会话时尝试恢复持久化会话；仍未恢复则需走登录流程
    final restored = await _authApi.restoreSession();
    if (!restored) {
      throw const MusicSourceConnectionException('未登录，请先在 NAS 配置页登录');
    }
  }

  @override
  Future<void> disconnect() async {
    await _authApi.logout();
    _config = null;
    _api = null;
  }

  // ---------- 内部工具 ----------

  /// 获取会话，未连接时抛出异常
  NasSession _requireSession() {
    final session = _authApi.session;
    if (session == null || !session.isValid) {
      throw const MusicSourceConnectionException('NAS 未连接或会话已失效');
    }
    return session;
  }

  /// 获取（或创建）API 实例
  SynologyAudioStationApi _requireApi() {
    final session = _requireSession();
    final config = _config;
    if (config == null) {
      throw const MusicSourceConnectionException('未配置 NAS 服务器');
    }

    final existing = _api;
    if (existing != null) {
      return existing;
    }

    final interceptor = AuthInterceptor(
      authApi: _authApi,
      configProvider: () => _config ?? config,
      dioProvider: () => _api!.dio,
    );

    // DSM 7 需要携带 SynoToken，DSM 6 可忽略（版本自适应）
    final adapter = _versionAdapter;
    final synoToken = adapter.shouldSendSynoToken ? session.synoToken : null;

    final api = SynologyAudioStationApi(
      serverUrl: config.fullServerUrl,
      apiInfo: session.apiInfo,
      synoToken: synoToken,
      interceptors: [interceptor],
      ignoreSelfSignedCert: config.ignoreSelfSignedCert,
    );
    _api = api;
    return api;
  }

  /// 统一请求样板：会话校验 + success 校验 + 封面注入
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
    final session = _requireSession();
    final api = _requireApi();
    final sid = session.sid;
    try {
      final body = await apiCall(api, sid);
      if (body['success'] != true) {
        throw MusicSourceConnectionException(
          '${errorPrefix ?? '请求失败'}：${_mapError(body)}',
        );
      }
      return onSuccess(body, api, sid);
    } on DioException catch (e) {
      throw MusicSourceConnectionException(
        '${errorPrefix ?? '请求失败'}：网络异常（${e.type.name}）',
      );
    } on SynologyApiException catch (e) {
      throw MusicSourceConnectionException(
        '${errorPrefix ?? '请求失败'}：${e.message}',
      );
    }
  }

  // ---------- 音乐库浏览 ----------

  @override
  Future<List<SongItem>> fetchSongs({
    String? sortBy,
    String? sortDirection,
  }) {
    return _execute(
      apiCall: (api, sid) => api.listSongs(
        sid: sid,
        limit: 500,
        sortBy: sortBy,
        sortDirection: sortDirection,
      ),
      onSuccess: _parseSongs,
      errorPrefix: '歌曲列表请求失败',
    );
  }

  @override
  Future<List<Album>> fetchAlbums({String? artistName}) {
    return _execute(
      apiCall: (api, sid) => api.listAlbums(
        sid: sid,
        limit: 500,
        artist: artistName,
      ),
      onSuccess: (body, api, sid) {
        final albums =
            (body['data'] as Map<String, dynamic>?)?['albums']
                as List<dynamic>? ??
                [];
        return albums.whereType<Map<String, dynamic>>().map((map) {
          final album = Album.fromMap(map);
          final coverUrl = api.buildAlbumCoverUrl(
            sid: sid,
            albumName: album.title,
            albumArtistName: album.artist,
          );
          return album.copyWith(coverUrl: coverUrl);
        }).toList(growable: false);
      },
      errorPrefix: '专辑列表请求失败',
    );
  }

  @override
  Future<List<Artist>> fetchArtists() {
    return _execute(
      apiCall: (api, sid) => api.listArtists(sid: sid, limit: 500),
      onSuccess: (body, api, sid) {
        final artists =
            (body['data'] as Map<String, dynamic>?)?['artists']
                as List<dynamic>? ??
                [];
        return artists.whereType<Map<String, dynamic>>().map((map) {
          final artist = Artist.fromMap(map);
          final coverUrl = api.buildArtistCoverUrl(
            sid: sid,
            artistName: artist.name,
          );
          return artist.copyWith(coverUrl: coverUrl);
        }).toList(growable: false);
      },
      errorPrefix: '歌手列表请求失败',
    );
  }

  @override
  Future<List<SongItem>> fetchAlbumSongs(Album album) {
    return _execute(
      apiCall: (api, sid) => api.listSongs(
        sid: sid,
        limit: 500,
        album: album.title,
        albumArtist: album.artist,
      ),
      onSuccess: _parseSongs,
      errorPrefix: '专辑歌曲请求失败',
    );
  }

  // ---------- 搜索 ----------

  @override
  Future<List<SongItem>> search(String keyword) {
    return _execute(
      apiCall: (api, sid) => api.search(sid: sid, keyword: keyword),
      onSuccess: _parseSongs,
      errorPrefix: '搜索失败',
    );
  }

  // ---------- 收藏（AudioStation 用歌曲评分 5 表示收藏） ----------

  @override
  Future<List<FavoriteSong>> fetchFavorites() async {
    final songs = await _execute(
      apiCall: (api, sid) => api.listSongs(
        sid: sid,
        limit: 500,
        ratingFilter: 5,
      ),
      onSuccess: _parseSongs,
      errorPrefix: '收藏列表请求失败',
    );
    return songs
        .map((song) => FavoriteSong.fromSongItem(song))
        .toList(growable: false);
  }

  @override
  Future<void> addFavorite(SongItem song) {
    return _execute<void>(
      apiCall: (api, sid) =>
          api.setSongRating(sid: sid, id: song.id, rating: 5),
      onSuccess: (body, api, sid) {},
      errorPrefix: '收藏失败',
    );
  }

  @override
  Future<void> removeFavorite(String songId) {
    return _execute<void>(
      apiCall: (api, sid) =>
          api.setSongRating(sid: sid, id: songId, rating: 0),
      onSuccess: (body, api, sid) {},
      errorPrefix: '取消收藏失败',
    );
  }

  // ---------- 播放资源 ----------

  @override
  Future<String> getPlaybackUrl(SongItem song) async {
    final session = _requireSession();
    final api = _requireApi();
    return api.buildSmartStreamUrl(songId: song.id, sid: session.sid);
  }

  @override
  Future<String?> getCoverUrl(SongItem song) async {
    if (song.coverUrl != null) return song.coverUrl;
    final session = _requireSession();
    final api = _requireApi();
    return api.buildSongCoverUrl(sid: session.sid, songId: song.id);
  }

  // ---------- 歌单 CRUD ----------

  @override
  Future<List<Playlist>> fetchPlaylists() {
    return _execute(
      apiCall: (api, sid) => api.listPlaylists(sid: sid),
      onSuccess: (body, api, sid) {
        final playlists =
            (body['data'] as Map<String, dynamic>?)?['playlists']
                as List<dynamic>? ??
                [];
        return playlists
            .whereType<Map<String, dynamic>>()
            .map(Playlist.fromMap)
            .toList(growable: false);
      },
      errorPrefix: '歌单列表请求失败',
    );
  }

  @override
  Future<List<SongItem>> fetchPlaylistSongs(String playlistId) {
    return _execute(
      apiCall: (api, sid) => api.getPlaylistInfo(sid: sid, id: playlistId),
      onSuccess: (body, api, sid) {
        // 歌单歌曲在 data.playlists[0].additional 的 songs 字段中
        final data = body['data'] as Map<String, dynamic>?;
        final playlists = data?['playlists'] as List<dynamic>? ?? [];
        if (playlists.isEmpty) return <SongItem>[];
        final first = playlists.first;
        if (first is! Map<String, dynamic>) return <SongItem>[];
        final additional = first['additional'] as Map<String, dynamic>?;
        final songs = additional?['songs'] as List<dynamic>? ?? [];
        return _parseSongList(songs, api, sid);
      },
      errorPrefix: '歌单歌曲请求失败',
    );
  }

  @override
  Future<Playlist> createPlaylist(String name) async {
    final created = await _execute<Playlist>(
      apiCall: (api, sid) => api.createPlaylist(sid: sid, name: name),
      onSuccess: (body, api, sid) {
        // create 响应 data 中可能包含新歌单 id/name
        final data = body['data'] as Map<String, dynamic>?;
        final id = '${data?['id'] ?? ''}';
        if (id.isNotEmpty) {
          return Playlist(id: id, name: name);
        }
        throw const MusicSourceConnectionException('创建歌单成功但未返回歌单 ID');
      },
      errorPrefix: '创建歌单失败',
    );
    return created;
  }

  @override
  Future<void> deletePlaylist(String playlistId) {
    return _execute<void>(
      apiCall: (api, sid) =>
          api.deletePlaylist(sid: sid, id: playlistId),
      onSuccess: (body, api, sid) {},
      errorPrefix: '删除歌单失败',
    );
  }

  @override
  Future<void> addSongToPlaylist(String playlistId, String songId) {
    return _execute<void>(
      apiCall: (api, sid) => api.addSongsToPlaylist(
        sid: sid,
        playlistId: playlistId,
        songIdsCsv: songId,
      ),
      onSuccess: (body, api, sid) {},
      errorPrefix: '添加到歌单失败',
    );
  }

  @override
  Future<void> removeSongFromPlaylist(String playlistId, String songId) {
    return _execute<void>(
      apiCall: (api, sid) => api.removeSongsFromPlaylist(
        sid: sid,
        playlistId: playlistId,
        offset: 0,
        limit: 1,
      ),
      onSuccess: (body, api, sid) {},
      errorPrefix: '从歌单移除失败',
    );
  }

  // ---------- 解析工具 ----------

  List<SongItem> _parseSongs(
    Map<String, dynamic> body,
    SynologyAudioStationApi api,
    String sid,
  ) {
    final songs =
        (body['data'] as Map<String, dynamic>?)?['songs']
            as List<dynamic>? ??
            [];
    return _parseSongList(songs, api, sid);
  }

  List<SongItem> _parseSongList(
    List<dynamic> rawSongs,
    SynologyAudioStationApi api,
    String sid,
  ) {
    return rawSongs.whereType<Map<String, dynamic>>().map((map) {
      final song = SongItem.fromMap(map);
      final coverUrl = api.buildSongCoverUrl(sid: sid, songId: song.id);
      return song.copyWith(coverUrl: coverUrl);
    }).toList(growable: false);
  }

  String _mapError(Map<String, dynamic> body) {
    final code = (body['error'] as Map<String, dynamic>?)?['code'];
    return '错误码 ${code ?? 'unknown'}';
  }
}
