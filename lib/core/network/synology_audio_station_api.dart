import 'synology_api_constants.dart';
import 'synology_base_api.dart';

/// 群晖 Audio Station API 模块。
///
/// 后续歌曲详情、歌单、专辑、封面等接口建议都放在这里。
class SynologyAudioStationApi extends SynologyBaseApi {
  SynologyAudioStationApi({required super.serverUrl, super.apiInfo});

  /// 获取歌曲列表（原始响应数据）。
  ///
  /// 这是音乐库首页最核心接口。
  Future<Map<String, dynamic>> listSongs({
    required String sid,
    int limit = 100,
    String library = SynologyApiConstants.songLibraryAll,
    String additional = SynologyApiConstants.songAdditionalTag,
  }) async {
    return _request(
      path: SynologyApiConstants.songPath,
      api: SynologyApiConstants.songApiName,
      fallbackVersion: SynologyApiConstants.songVersion,
      method: 'list',
      sid: sid,
      extra: {
        'library': library,
        'limit': '$limit',
        'additional': additional,
      },
    );
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
      fallbackVersion: SynologyApiConstants.songVersion,
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
      fallbackVersion: SynologyApiConstants.songVersion,
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
      fallbackVersion: SynologyApiConstants.albumVersion,
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
      fallbackVersion: SynologyApiConstants.albumVersion,
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
      fallbackVersion: SynologyApiConstants.artistVersion,
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
      fallbackVersion: SynologyApiConstants.artistVersion,
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
      fallbackVersion: SynologyApiConstants.playlistVersion,
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
      fallbackVersion: SynologyApiConstants.playlistVersion,
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
      fallbackVersion: SynologyApiConstants.playlistVersion,
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
      fallbackVersion: SynologyApiConstants.playlistVersion,
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
      fallbackVersion: SynologyApiConstants.playlistVersion,
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
      fallbackVersion: SynologyApiConstants.playlistVersion,
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
      fallbackVersion: SynologyApiConstants.folderVersion,
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
      fallbackVersion: SynologyApiConstants.lyricsVersion,
      method: 'get',
      sid: sid,
      extra: {'id': songId},
    );
  }

  /// 构造歌曲流媒体 URL（用于播放器 setUrl）。
  ///
  /// 注：部分 DSM 配置会要求额外参数，可在此方法统一扩展。
  String buildSongStreamUrl({required String songId, required String sid}) {
    return buildAbsoluteUrl(
      resolveApiPath(
        SynologyApiConstants.songApiName,
        SynologyApiConstants.songPath,
      ),
      {
        'api': SynologyApiConstants.songApiName,
        'version': resolveApiVersion(
          SynologyApiConstants.songApiName,
          SynologyApiConstants.songVersion,
        ),
        'method': 'stream',
        'id': songId,
        SynologyApiConstants.sidKey: sid,
      },
    );
  }

  /// 构造封面 URL（可用于专辑封面、歌曲封面）。
  ///
  /// 封面接口不走标准 API Info 路径，直接使用常量路径。
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

  // ========== Remote Player（远程播放器） ==========

  /// 获取远程播放器列表
  Future<Map<String, dynamic>> listRemotePlayers({
    required String sid,
  }) async {
    return _request(
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
    return _request(
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
  ///
  /// [action] 取值：play / pause / stop / next / previous / seek / volume / repeat / shuffle
  /// [value] 可选参数（seek 为秒数，volume 为 0-100，repeat 为 0/1/2，shuffle 为 0/1）
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
    return _request(
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

  /// 快捷：设置循环模式
  ///
  /// [mode] 0=关闭, 1=单曲循环, 2=列表循环
  Future<Map<String, dynamic>> remoteSetRepeat({
    required String sid,
    required String playerId,
    required int mode,
  }) =>
      controlRemotePlayer(
        sid: sid,
        playerId: playerId,
        action: 'repeat',
        value: '$mode',
      );

  /// 快捷：设置随机播放
  ///
  /// [enable] true=开启, false=关闭
  Future<Map<String, dynamic>> remoteSetShuffle({
    required String sid,
    required String playerId,
    required bool enable,
  }) =>
      controlRemotePlayer(
        sid: sid,
        playerId: playerId,
        action: 'shuffle',
        value: enable ? '1' : '0',
      );

  Future<Map<String, dynamic>> _request({
    required String path,
    required String api,
    required String fallbackVersion,
    required String method,
    required String sid,
    Map<String, String>? extra,
  }) async {
    final response = await dio.get(
      resolveApiPath(api, path),
      queryParameters: {
        'api': api,
        'version': resolveApiVersion(api, fallbackVersion),
        'method': method,
        SynologyApiConstants.sidKey: sid,
        ...?extra,
      },
    );
    return requireBody(response);
  }
}
