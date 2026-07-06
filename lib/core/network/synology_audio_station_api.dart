import 'synology_api_constants.dart';
import 'synology_base_api.dart';

/// 群晖 Audio Station API 模块。
///
/// 后续歌曲详情、歌单、专辑、封面等接口建议都放在这里。
class SynologyAudioStationApi extends SynologyBaseApi {
  SynologyAudioStationApi({required super.serverUrl});

  /// 获取歌曲列表（原始响应数据）。
  ///
  /// 这是音乐库首页最核心接口。
  Future<Map<String, dynamic>> listSongs({
    required String sid,
    int limit = 100,
    String library = SynologyApiConstants.songLibraryAll,
    String additional = SynologyApiConstants.songAdditionalTag,
  }) async {
    final response = await dio.get(
      SynologyApiConstants.songPath,
      queryParameters: {
        'api': SynologyApiConstants.songApiName,
        'method': 'list',
        'version': SynologyApiConstants.songVersion,
        'library': library,
        'limit': '$limit',
        'additional': additional,
        SynologyApiConstants.sidKey: sid,
      },
    );
    return requireBody(response);
  }

  /// 搜索歌曲（关键词）。
  Future<Map<String, dynamic>> searchSongs({
    required String sid,
    required String keyword,
    int limit = 50,
  }) async {
    return _request(
      path: SynologyApiConstants.songPath,
      api: SynologyApiConstants.songApiName,
      version: SynologyApiConstants.songVersion,
      method: 'search',
      sid: sid,
      extra: {
        'keyword': keyword,
        'limit': '$limit',
        'additional': SynologyApiConstants.songAdditionalTag,
      },
    );
  }

  /// 根据歌曲 ID 获取详细信息（可用于播放页详情）。
  Future<Map<String, dynamic>> getSongInfo({
    required String sid,
    required String id,
  }) async {
    return _request(
      path: SynologyApiConstants.songPath,
      api: SynologyApiConstants.songApiName,
      version: SynologyApiConstants.songVersion,
      method: 'getinfo',
      sid: sid,
      extra: {'id': id, 'additional': SynologyApiConstants.songAdditionalTag},
    );
  }

  /// 获取专辑列表。
  Future<Map<String, dynamic>> listAlbums({
    required String sid,
    int limit = 100,
  }) async {
    return _request(
      path: SynologyApiConstants.albumPath,
      api: SynologyApiConstants.albumApiName,
      version: SynologyApiConstants.albumVersion,
      method: 'list',
      sid: sid,
      extra: {'limit': '$limit'},
    );
  }

  /// 获取专辑详情（通常包含专辑内歌曲）。
  Future<Map<String, dynamic>> getAlbumInfo({
    required String sid,
    required String id,
  }) async {
    return _request(
      path: SynologyApiConstants.albumPath,
      api: SynologyApiConstants.albumApiName,
      version: SynologyApiConstants.albumVersion,
      method: 'getinfo',
      sid: sid,
      extra: {'id': id},
    );
  }

  /// 获取歌手列表。
  Future<Map<String, dynamic>> listArtists({
    required String sid,
    int limit = 100,
  }) async {
    return _request(
      path: SynologyApiConstants.artistPath,
      api: SynologyApiConstants.artistApiName,
      version: SynologyApiConstants.artistVersion,
      method: 'list',
      sid: sid,
      extra: {'limit': '$limit'},
    );
  }

  /// 获取歌手详情（通常包含该歌手专辑/歌曲）。
  Future<Map<String, dynamic>> getArtistInfo({
    required String sid,
    required String id,
  }) async {
    return _request(
      path: SynologyApiConstants.artistPath,
      api: SynologyApiConstants.artistApiName,
      version: SynologyApiConstants.artistVersion,
      method: 'getinfo',
      sid: sid,
      extra: {'id': id},
    );
  }

  /// 获取歌单列表。
  Future<Map<String, dynamic>> listPlaylists({
    required String sid,
    int limit = 100,
  }) async {
    return _request(
      path: SynologyApiConstants.playlistPath,
      api: SynologyApiConstants.playlistApiName,
      version: SynologyApiConstants.playlistVersion,
      method: 'list',
      sid: sid,
      extra: {'limit': '$limit'},
    );
  }

  /// 获取歌单详情。
  Future<Map<String, dynamic>> getPlaylistInfo({
    required String sid,
    required String id,
  }) async {
    return _request(
      path: SynologyApiConstants.playlistPath,
      api: SynologyApiConstants.playlistApiName,
      version: SynologyApiConstants.playlistVersion,
      method: 'getinfo',
      sid: sid,
      extra: {'id': id},
    );
  }

  /// 创建歌单。
  Future<Map<String, dynamic>> createPlaylist({
    required String sid,
    required String name,
  }) async {
    return _request(
      path: SynologyApiConstants.playlistPath,
      api: SynologyApiConstants.playlistApiName,
      version: SynologyApiConstants.playlistVersion,
      method: 'create',
      sid: sid,
      extra: {'name': name},
    );
  }

  /// 更新歌单（名称）。
  Future<Map<String, dynamic>> updatePlaylist({
    required String sid,
    required String id,
    required String name,
  }) async {
    return _request(
      path: SynologyApiConstants.playlistPath,
      api: SynologyApiConstants.playlistApiName,
      version: SynologyApiConstants.playlistVersion,
      method: 'update',
      sid: sid,
      extra: {'id': id, 'name': name},
    );
  }

  /// 删除歌单。
  Future<Map<String, dynamic>> deletePlaylist({
    required String sid,
    required String id,
  }) async {
    return _request(
      path: SynologyApiConstants.playlistPath,
      api: SynologyApiConstants.playlistApiName,
      version: SynologyApiConstants.playlistVersion,
      method: 'delete',
      sid: sid,
      extra: {'id': id},
    );
  }

  /// 向歌单添加歌曲（ids 用逗号分隔）。
  Future<Map<String, dynamic>> addSongsToPlaylist({
    required String sid,
    required String playlistId,
    required String songIdsCsv,
  }) async {
    return _request(
      path: SynologyApiConstants.playlistPath,
      api: SynologyApiConstants.playlistApiName,
      version: SynologyApiConstants.playlistVersion,
      method: 'updatesongs',
      sid: sid,
      extra: {'id': playlistId, 'offset': 'end', 'songs': songIdsCsv},
    );
  }

  /// 获取文件夹树（本地音乐目录浏览）。
  Future<Map<String, dynamic>> listFolders({
    required String sid,
    String? id,
  }) async {
    return _request(
      path: SynologyApiConstants.folderPath,
      api: SynologyApiConstants.folderApiName,
      version: SynologyApiConstants.folderVersion,
      method: 'list',
      sid: sid,
      extra: {if (id != null && id.isNotEmpty) 'id': id},
    );
  }

  /// 获取歌词信息。
  ///
  /// 不同 DSM 版本返回字段可能不同，建议业务层做兜底解析。
  Future<Map<String, dynamic>> getLyrics({
    required String sid,
    required String songId,
  }) async {
    return _request(
      path: SynologyApiConstants.lyricsPath,
      api: SynologyApiConstants.lyricsApiName,
      version: SynologyApiConstants.lyricsVersion,
      method: 'get',
      sid: sid,
      extra: {'id': songId},
    );
  }

  /// 构造歌曲流媒体 URL（用于播放器 setUrl）。
  ///
  /// 注：部分 DSM 配置会要求额外参数，可在此方法统一扩展。
  String buildSongStreamUrl({required String songId, required String sid}) {
    return buildAbsoluteUrl(SynologyApiConstants.songPath, {
      'api': SynologyApiConstants.songApiName,
      'version': SynologyApiConstants.songVersion,
      'method': 'stream',
      'id': songId,
      SynologyApiConstants.sidKey: sid,
    });
  }

  /// 构造封面 URL（可用于专辑封面、歌曲封面）。
  String buildCoverUrl({
    required String sid,
    String? songId,
    String? albumId,
    String? artistName,
    int size = 300,
  }) {
    return buildAbsoluteUrl(SynologyApiConstants.coverPath, {
      if (songId != null && songId.isNotEmpty) 'id': songId,
      if (albumId != null && albumId.isNotEmpty) 'album_id': albumId,
      if (artistName != null && artistName.isNotEmpty)
        'artist_name': artistName,
      'size': '$size',
      SynologyApiConstants.sidKey: sid,
    });
  }

  Future<Map<String, dynamic>> _request({
    required String path,
    required String api,
    required String version,
    required String method,
    required String sid,
    Map<String, String>? extra,
  }) async {
    final response = await dio.get(
      path,
      queryParameters: {
        'api': api,
        'version': version,
        'method': method,
        SynologyApiConstants.sidKey: sid,
        ...?extra,
      },
    );
    return requireBody(response);
  }
}
