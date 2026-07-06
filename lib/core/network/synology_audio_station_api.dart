import 'package:dio/dio.dart';

import 'synology_api_constants.dart';
import 'synology_base_api.dart';

/// 群晖 Audio Station API 模块。
///
/// 所有接口参数严格对照 AudioStation 接口文档参考.md 实现：
/// - GET 请求的接口：Album、Artist、Playlist list、Cover、Lyrics、Search、Info
/// - POST 请求的接口：Song list、Folder list、Genre list、Playlist 增删改、Song setrating
class SynologyAudioStationApi extends SynologyBaseApi {
  SynologyAudioStationApi({required super.serverUrl, super.apiInfo});

  // ========== Song 歌曲 ==========

  /// 获取歌曲列表（POST data，文档明确要求 POST）
  Future<Map<String, dynamic>> listSongs({
    required String sid,
    int offset = 0,
    int limit = 100,
    String library = SynologyApiConstants.songLibraryAll,
    String additional = SynologyApiConstants.songAdditionalAll,
    String? sortBy,
    String? sortDirection,
    String? albumArtist,
    String? album,
    String? artist,
    String? genre,
    int? ratingFilter,
  }) async {
    final extra = <String, String>{
      'library': library,
      'offset': '$offset',
      'limit': '$limit',
      'additional': additional,
    };
    if (sortBy != null) extra['sort_by'] = sortBy;
    if (sortDirection != null) extra['sort_direction'] = sortDirection;
    if (albumArtist != null) extra['album_artist'] = albumArtist;
    if (album != null) extra['album'] = album;
    if (artist != null) extra['artist'] = artist;
    if (genre != null) extra['genre'] = genre;
    if (ratingFilter != null) extra['rating_filter'] = '$ratingFilter';

    return _postBodyRequest(
      path: SynologyApiConstants.songPath,
      api: SynologyApiConstants.songApiName,
      fallbackVersion: SynologyApiConstants.songVersion,
      method: 'list',
      sid: sid,
      extra: extra,
    );
  }

  /// 根据歌曲 ID 获取详细信息
  Future<Map<String, dynamic>> getSongInfo({
    required String sid,
    required String id,
  }) async {
    return _getRequest(
      path: SynologyApiConstants.songPath,
      api: SynologyApiConstants.songApiName,
      fallbackVersion: SynologyApiConstants.songVersion,
      method: 'getinfo',
      sid: sid,
      extra: {
        'id': id,
        'additional': SynologyApiConstants.songAdditionalAll,
      },
    );
  }

  /// 歌曲评分（替代收藏功能，POST query）
  ///
  /// [rating] 0-5，0=取消评分，5=收藏
  Future<Map<String, dynamic>> setSongRating({
    required String sid,
    required String id,
    required int rating,
  }) async {
    return _postQueryRequest(
      path: SynologyApiConstants.songPath,
      api: SynologyApiConstants.songApiName,
      fallbackVersion: SynologyApiConstants.songVersion,
      method: 'setrating',
      sid: sid,
      extra: {'id': id, 'rating': '$rating'},
    );
  }

  // ========== Stream 歌曲播放 ==========

  /// 构造歌曲流媒体 URL（用于播放器 setUrl）
  ///
  /// 使用独立的 SYNO.AudioStation.Stream API，而非 Song API。
  /// 若歌曲 ID 包含 `_v_`（整轨文件），建议使用 [buildTranscodeUrl] 转码播放。
  String buildSongStreamUrl({required String songId, required String sid}) {
    return buildAbsoluteUrl(
      resolveApiPath(
        SynologyApiConstants.streamApiName,
        SynologyApiConstants.streamPath,
      ),
      {
        'api': SynologyApiConstants.streamApiName,
        'version': resolveApiVersion(
          SynologyApiConstants.streamApiName,
          SynologyApiConstants.streamVersion,
        ),
        'method': 'stream',
        'id': songId,
        SynologyApiConstants.sidKey: sid,
      },
    );
  }

  /// 构造转码播放 URL（method=transcode，路径需加 /0.mp3）
  ///
  /// 适用于整轨文件（ID 含 `_v_`）或需要转码的场景
  String buildTranscodeUrl({
    required String songId,
    required String sid,
    String format = 'mp3',
  }) {
    // 文档：method=transcode 时路径后需添加 /0.mp3
    final basePath = resolveApiPath(
      SynologyApiConstants.streamApiName,
      SynologyApiConstants.streamPath,
    );
    final url = buildAbsoluteUrl('$basePath/0.mp3', {
      'api': SynologyApiConstants.streamApiName,
      'version': resolveApiVersion(
        SynologyApiConstants.streamApiName,
        SynologyApiConstants.streamVersion,
      ),
      'method': 'transcode',
      'id': songId,
      'format': format,
      SynologyApiConstants.sidKey: sid,
    });
    return url;
  }

  /// 智能选择播放 URL
  ///
  /// ID 含 `_v_` 的整轨文件强制使用转码，否则直接 stream
  String buildSmartStreamUrl({required String songId, required String sid}) {
    if (songId.contains('_v_')) {
      return buildTranscodeUrl(songId: songId, sid: sid);
    }
    return buildSongStreamUrl(songId: songId, sid: sid);
  }

  // ========== Album 专辑 ==========

  /// 获取专辑列表（GET query）
  Future<Map<String, dynamic>> listAlbums({
    required String sid,
    int offset = 0,
    int limit = 100,
    String library = SynologyApiConstants.songLibraryAll,
    String additional = 'avg_rating',
    String? sortBy,
    String? sortDirection,
    String? filter,
    String? artist,
    String? genre,
  }) async {
    final extra = <String, String>{
      'library': library,
      'offset': '$offset',
      'limit': '$limit',
      'additional': additional,
    };
    if (sortBy != null) extra['sort_by'] = sortBy;
    if (sortDirection != null) extra['sort_direction'] = sortDirection;
    if (filter != null) extra['filter'] = filter;
    if (artist != null) extra['artist'] = artist;
    if (genre != null) extra['genre'] = genre;

    return _getRequest(
      path: SynologyApiConstants.albumPath,
      api: SynologyApiConstants.albumApiName,
      fallbackVersion: SynologyApiConstants.albumVersion,
      method: 'list',
      sid: sid,
      extra: extra,
    );
  }

  // ========== Artist 歌手 ==========

  /// 获取歌手列表（GET query）
  ///
  /// 注意：此接口返回的是专辑艺术家列表，部分歌手可能无法从此接口获取
  Future<Map<String, dynamic>> listArtists({
    required String sid,
    int offset = 0,
    int limit = 100,
    String library = SynologyApiConstants.songLibraryAll,
    String additional = 'avg_rating',
    String? genre,
    String? sortBy,
    String? sortDirection,
  }) async {
    final extra = <String, String>{
      'library': library,
      'offset': '$offset',
      'limit': '$limit',
      'additional': additional,
    };
    if (genre != null) extra['genre'] = genre;
    if (sortBy != null) extra['sort_by'] = sortBy;
    if (sortDirection != null) extra['sort_direction'] = sortDirection;

    return _getRequest(
      path: SynologyApiConstants.artistPath,
      api: SynologyApiConstants.artistApiName,
      fallbackVersion: SynologyApiConstants.artistVersion,
      method: 'list',
      sid: sid,
      extra: extra,
    );
  }

  // ========== Playlist 歌单 ==========

  /// 获取歌单列表（GET query）
  Future<Map<String, dynamic>> listPlaylists({
    required String sid,
    int offset = 0,
    int limit = 100,
    String library = SynologyApiConstants.songLibraryAll,
  }) async {
    return _getRequest(
      path: SynologyApiConstants.playlistPath,
      api: SynologyApiConstants.playlistApiName,
      fallbackVersion: SynologyApiConstants.playlistVersion,
      method: 'list',
      sid: sid,
      extra: {
        'library': library,
        'offset': '$offset',
        'limit': '$limit',
      },
    );
  }

  /// 获取歌单中的歌曲（GET query）
  ///
  /// additional 参数前缀为 songs_（如 songs_song_tag）
  Future<Map<String, dynamic>> getPlaylistInfo({
    required String sid,
    required String id,
    int offset = 0,
    int limit = 100,
    String library = SynologyApiConstants.songLibraryAll,
    String sortDirection = 'ASC',
    String additional = 'songs_song_tag,songs_song_audio,songs_song_rating',
  }) async {
    return _getRequest(
      path: SynologyApiConstants.playlistPath,
      api: SynologyApiConstants.playlistApiName,
      fallbackVersion: SynologyApiConstants.playlistVersion,
      method: 'getinfo',
      sid: sid,
      extra: {
        'library': library,
        'id': id,
        'offset': '$offset',
        'limit': '$limit',
        'sort_direction': sortDirection,
        'additional': additional,
      },
    );
  }

  /// 创建歌单（POST query）
  Future<Map<String, dynamic>> createPlaylist({
    required String sid,
    required String name,
    String library = SynologyApiConstants.songLibraryAll,
  }) async {
    return _postQueryRequest(
      path: SynologyApiConstants.playlistPath,
      api: SynologyApiConstants.playlistApiName,
      fallbackVersion: SynologyApiConstants.playlistVersion,
      method: 'create',
      sid: sid,
      extra: {'library': library, 'name': name},
    );
  }

  /// 重命名歌单（POST query）
  Future<Map<String, dynamic>> renamePlaylist({
    required String sid,
    required String id,
    required String newName,
  }) async {
    return _postQueryRequest(
      path: SynologyApiConstants.playlistPath,
      api: SynologyApiConstants.playlistApiName,
      fallbackVersion: SynologyApiConstants.playlistVersion,
      method: 'rename',
      sid: sid,
      extra: {'id': id, 'new_name': newName},
    );
  }

  /// 删除歌单（POST query）
  Future<Map<String, dynamic>> deletePlaylist({
    required String sid,
    required String id,
  }) async {
    return _postQueryRequest(
      path: SynologyApiConstants.playlistPath,
      api: SynologyApiConstants.playlistApiName,
      fallbackVersion: SynologyApiConstants.playlistVersion,
      method: 'delete',
      sid: sid,
      extra: {'id': id},
    );
  }

  /// 向歌单添加歌曲（POST query）
  ///
  /// 文档：offset=-1, limit=0 表示追加到末尾
  Future<Map<String, dynamic>> addSongsToPlaylist({
    required String sid,
    required String playlistId,
    required String songIdsCsv,
  }) async {
    return _postQueryRequest(
      path: SynologyApiConstants.playlistPath,
      api: SynologyApiConstants.playlistApiName,
      fallbackVersion: SynologyApiConstants.playlistVersion,
      method: 'updatesongs',
      sid: sid,
      extra: {
        'id': playlistId,
        'offset': '-1',
        'limit': '0',
        'songs': songIdsCsv,
      },
    );
  }

  /// 从歌单移除歌曲（POST query）
  ///
  /// [offset] 待移除歌曲的起始行数
  /// [limit] 需要移除的歌曲数量
  /// [songs] 待回溯的歌曲 ID 列表（误删恢复用，可选）
  Future<Map<String, dynamic>> removeSongsFromPlaylist({
    required String sid,
    required String playlistId,
    required int offset,
    required int limit,
    String? songs,
  }) async {
    final extra = <String, String>{
      'id': playlistId,
      'offset': '$offset',
      'limit': '$limit',
    };
    if (songs != null) extra['songs'] = songs;

    return _postQueryRequest(
      path: SynologyApiConstants.playlistPath,
      api: SynologyApiConstants.playlistApiName,
      fallbackVersion: SynologyApiConstants.playlistVersion,
      method: 'updatesongs',
      sid: sid,
      extra: extra,
    );
  }

  // ========== Folder 目录浏览 ==========

  /// 获取目录列表（POST data）
  Future<Map<String, dynamic>> listFolders({
    required String sid,
    String? id,
    int offset = 0,
    int limit = 100,
    String library = SynologyApiConstants.songLibraryAll,
    String additional = 'song_tag,song_audio,song_rating',
    String sortBy = 'song_rating',
    String sortDirection = 'ASC',
  }) async {
    final extra = <String, String>{
      'library': library,
      'offset': '$offset',
      'limit': '$limit',
      'additional': additional,
      'sort_by': sortBy,
      'sort_direction': sortDirection,
    };
    if (id != null && id.isNotEmpty) extra['id'] = id;

    return _postBodyRequest(
      path: SynologyApiConstants.folderPath,
      api: SynologyApiConstants.folderApiName,
      fallbackVersion: SynologyApiConstants.folderVersion,
      method: 'list',
      sid: sid,
      extra: extra,
    );
  }

  // ========== Genre 类型 ==========

  /// 获取类型列表（POST data）
  Future<Map<String, dynamic>> listGenres({
    required String sid,
    int offset = 0,
    int limit = 100,
    String library = SynologyApiConstants.songLibraryAll,
    String sortBy = 'name',
    String sortDirection = 'ASC',
  }) async {
    return _postBodyRequest(
      path: SynologyApiConstants.genrePath,
      api: SynologyApiConstants.genreApiName,
      fallbackVersion: SynologyApiConstants.genreVersion,
      method: 'list',
      sid: sid,
      extra: {
        'library': library,
        'offset': '$offset',
        'limit': '$limit',
        'sort_by': sortBy,
        'sort_direction': sortDirection,
      },
    );
  }

  // ========== Lyrics 歌词 ==========

  /// 获取歌词（GET query）
  ///
  /// 文档 method 名称为 getlyrics（非 get）
  Future<Map<String, dynamic>> getLyrics({
    required String sid,
    required String songId,
  }) async {
    return _getRequest(
      path: SynologyApiConstants.lyricsPath,
      api: SynologyApiConstants.lyricsApiName,
      fallbackVersion: SynologyApiConstants.lyricsVersion,
      method: 'getlyrics',
      sid: sid,
      extra: {'id': songId},
    );
  }

  /// 搜索歌词（GET query，依赖 AudioStation 歌词插件）
  Future<Map<String, dynamic>> searchLyrics({
    required String sid,
    required String title,
    required String artist,
    int limit = 10,
  }) async {
    return _getRequest(
      path: SynologyApiConstants.lyricsSearchPath,
      api: SynologyApiConstants.lyricsSearchApiName,
      fallbackVersion: SynologyApiConstants.lyricsSearchVersion,
      method: 'searchlyrics',
      sid: sid,
      extra: {
        'title': title,
        'artist': artist,
        'limit': '$limit',
        'additional': 'full_lyrics',
      },
    );
  }

  // ========== Search 搜索 ==========

  /// 搜索歌曲/专辑/歌手（GET query）
  ///
  /// 使用独立的 SYNO.AudioStation.Search API
  Future<Map<String, dynamic>> search({
    required String sid,
    required String keyword,
    int offset = 0,
    int limit = 50,
    String library = SynologyApiConstants.songLibraryAll,
    String sortBy = 'title',
    String sortDirection = 'ASC',
    String additional = 'song_tag,song_audio,song_rating',
  }) async {
    return _getRequest(
      path: SynologyApiConstants.searchPath,
      api: SynologyApiConstants.searchApiName,
      fallbackVersion: SynologyApiConstants.searchVersion,
      method: 'list',
      sid: sid,
      extra: {
        'library': library,
        'keyword': keyword,
        'offset': '$offset',
        'limit': '$limit',
        'sort_by': sortBy,
        'sort_direction': sortDirection,
        'additional': additional,
      },
    );
  }

  // ========== Info 服务器信息 ==========

  /// 获取服务器信息（GET query）
  Future<Map<String, dynamic>> getInfo({required String sid}) async {
    return _getRequest(
      path: SynologyApiConstants.infoPath,
      api: SynologyApiConstants.infoApiName,
      fallbackVersion: SynologyApiConstants.infoVersion,
      method: 'getinfo',
      sid: sid,
    );
  }

  // ========== Cover 封面 ==========

  /// 构造歌曲封面 URL
  String buildSongCoverUrl({required String sid, required String songId}) {
    return buildAbsoluteUrl(SynologyApiConstants.coverPath, {
      'api': SynologyApiConstants.coverApiName,
      'version': SynologyApiConstants.coverVersion,
      'method': 'getsongcover',
      'library': SynologyApiConstants.songLibraryAll,
      'id': songId,
      SynologyApiConstants.sidKey: sid,
    });
  }

  /// 构造专辑封面 URL
  String buildAlbumCoverUrl({
    required String sid,
    required String albumName,
    required String albumArtistName,
  }) {
    return buildAbsoluteUrl(SynologyApiConstants.coverPath, {
      'api': SynologyApiConstants.coverApiName,
      'version': SynologyApiConstants.coverVersion,
      'method': 'getcover',
      'library': SynologyApiConstants.songLibraryAll,
      'album_name': albumName,
      'album_artist_name': albumArtistName,
      SynologyApiConstants.sidKey: sid,
    });
  }

  /// 构造歌手封面 URL
  String buildArtistCoverUrl({
    required String sid,
    required String artistName,
  }) {
    return buildAbsoluteUrl(SynologyApiConstants.coverPath, {
      'api': SynologyApiConstants.coverApiName,
      'version': SynologyApiConstants.coverVersion,
      'method': 'getcover',
      'library': SynologyApiConstants.songLibraryAll,
      'artist_name': artistName,
      SynologyApiConstants.sidKey: sid,
    });
  }

  // ========== Remote Player（远程播放器） ==========

  /// 获取远程播放器列表
  Future<Map<String, dynamic>> listRemotePlayers({
    required String sid,
  }) async {
    return _getRequest(
      path: SynologyApiConstants.remotePlayerPath,
      api: SynologyApiConstants.remotePlayerApiName,
      fallbackVersion: SynologyApiConstants.remotePlayerVersion,
      method: 'list',
      sid: sid,
      extra: {'additional': 'player_status,song'},
    );
  }

  /// 获取指定远程播放器状态
  Future<Map<String, dynamic>> getRemotePlayerStatus({
    required String sid,
    required String playerId,
  }) async {
    return _getRequest(
      path: SynologyApiConstants.remotePlayerPath,
      api: SynologyApiConstants.remotePlayerApiName,
      fallbackVersion: SynologyApiConstants.remotePlayerVersion,
      method: 'getstatus',
      sid: sid,
      extra: {
        'id': playerId,
        'additional': 'player_status,song',
      },
    );
  }

  /// 控制远程播放器（播放/暂停/上一首/下一首等）
  Future<Map<String, dynamic>> controlRemotePlayer({
    required String sid,
    required String playerId,
    required String action,
    String? value,
  }) async {
    final extra = <String, String>{
      'id': playerId,
      'action': action,
    };
    if (value != null && value.isNotEmpty) {
      extra['value'] = value;
    }
    return _getRequest(
      path: SynologyApiConstants.remotePlayerPath,
      api: SynologyApiConstants.remotePlayerApiName,
      fallbackVersion: SynologyApiConstants.remotePlayerVersion,
      method: 'control',
      sid: sid,
      extra: extra,
    );
  }

  /// 快捷：播放
  Future<Map<String, dynamic>> remotePlay({
    required String sid,
    required String playerId,
  }) =>
      controlRemotePlayer(sid: sid, playerId: playerId, action: 'play');

  /// 快捷：暂停
  Future<Map<String, dynamic>> remotePause({
    required String sid,
    required String playerId,
  }) =>
      controlRemotePlayer(sid: sid, playerId: playerId, action: 'pause');

  /// 快捷：停止
  Future<Map<String, dynamic>> remoteStop({
    required String sid,
    required String playerId,
  }) =>
      controlRemotePlayer(sid: sid, playerId: playerId, action: 'stop');

  /// 快捷：下一首
  Future<Map<String, dynamic>> remoteNext({
    required String sid,
    required String playerId,
  }) =>
      controlRemotePlayer(sid: sid, playerId: playerId, action: 'next');

  /// 快捷：上一首
  Future<Map<String, dynamic>> remotePrevious({
    required String sid,
    required String playerId,
  }) =>
      controlRemotePlayer(sid: sid, playerId: playerId, action: 'previous');

  /// 快捷：跳转到指定位置（秒）
  Future<Map<String, dynamic>> remoteSeek({
    required String sid,
    required String playerId,
    required int seconds,
  }) =>
      controlRemotePlayer(
        sid: sid,
        playerId: playerId,
        action: 'seek',
        value: '$seconds',
      );

  /// 快捷：设置音量（0-100）
  Future<Map<String, dynamic>> remoteSetVolume({
    required String sid,
    required String playerId,
    required int volume,
  }) =>
      controlRemotePlayer(
        sid: sid,
        playerId: playerId,
        action: 'volume',
        value: '$volume',
      );

  // ========== 内部请求方法 ==========

  /// GET 请求（用于 Album、Artist、Playlist list/getinfo、Cover、Lyrics、Search、Info、RemotePlayer）
  Future<Map<String, dynamic>> _getRequest({
    required String path,
    required String api,
    required String fallbackVersion,
    required String method,
    required String sid,
    Map<String, String>? extra,
  }) async {
    final params = <String, String>{
      'api': api,
      'version': resolveApiVersion(api, fallbackVersion),
      'method': method,
      SynologyApiConstants.sidKey: sid,
      ...?extra,
    };
    // 携带 SynoToken（CSRF 防护）
    if (synoToken != null && synoToken!.isNotEmpty) {
      params['SynoToken'] = synoToken!;
    }
    final response = await dio.get(
      resolveApiPath(api, path),
      queryParameters: params,
    );
    return requireBody(response);
  }

  /// POST data 请求（参数放请求体，用于 Song list、Folder list、Genre list）
  ///
  /// 文档标注 "POST data" 的接口，参数应通过 form-urlencoded body 发送
  Future<Map<String, dynamic>> _postBodyRequest({
    required String path,
    required String api,
    required String fallbackVersion,
    required String method,
    required String sid,
    Map<String, String>? extra,
  }) async {
    final body = <String, String>{
      'api': api,
      'version': resolveApiVersion(api, fallbackVersion),
      'method': method,
      SynologyApiConstants.sidKey: sid,
      ...?extra,
    };
    // 携带 SynoToken（CSRF 防护）
    if (synoToken != null && synoToken!.isNotEmpty) {
      body['SynoToken'] = synoToken!;
    }
    final response = await dio.post(
      resolveApiPath(api, path),
      data: body,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
      ),
    );
    return requireBody(response);
  }

  /// POST query 请求（参数放 URL query，用于 Playlist 增删改、Song setrating）
  ///
  /// 文档标注 "POST query" 的接口，参数通过 URL query string 发送
  Future<Map<String, dynamic>> _postQueryRequest({
    required String path,
    required String api,
    required String fallbackVersion,
    required String method,
    required String sid,
    Map<String, String>? extra,
  }) async {
    final params = <String, String>{
      'api': api,
      'version': resolveApiVersion(api, fallbackVersion),
      'method': method,
      SynologyApiConstants.sidKey: sid,
      ...?extra,
    };
    // 携带 SynoToken（CSRF 防护）
    if (synoToken != null && synoToken!.isNotEmpty) {
      params['SynoToken'] = synoToken!;
    }
    final response = await dio.post(
      resolveApiPath(api, path),
      queryParameters: params,
    );
    return requireBody(response);
  }
}
