import '../../models/library/album.dart';
import '../../models/library/artist.dart';
import '../../models/library/favorite_song.dart';
import '../../models/library/playlist.dart';
import '../../models/library/song_item.dart';

/// 音乐数据源统一抽象接口
///
/// 每种播放源（群晖 AudioStation、本地音乐、后续 Navidrome/Emby 等）
/// 实现该接口，业务层（页面/播放器）只依赖抽象，不感知具体来源。
///
/// 约定：
/// - [getPlaybackUrl] / [getCoverUrl] 返回可直接使用的完整 URL，
///   供现有播放器（AudioPlayerService / cached_network_image）直接消费。
/// - 播放源可能未连接（[isConnected] == false），
///   调用数据方法前应通过 [connect] 建立会话，失败时抛出
///   [MusicSourceConnectionException]。
class MusicSourceConnectionException implements Exception {
  const MusicSourceConnectionException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class MusicSourceRepository {
  /// 数据源唯一标识（如 syno / local / navidrome）
  String get sourceId;

  /// 数据源显示名称（如 "群晖 AudioStation"）
  String get sourceName;

  /// 是否已建立会话（登录）
  bool get isConnected;

  /// 建立连接（登录/鉴权），失败抛 [MusicSourceConnectionException]
  Future<void> connect();

  /// 断开连接（登出/清理会话）
  Future<void> disconnect();

  // ---------- 音乐库浏览 ----------

  /// 获取歌曲列表
  ///
  /// [sortBy] / [sortDirection] 由实现方决定支持的取值。
  Future<List<SongItem>> fetchSongs({
    String? sortBy,
    String? sortDirection,
  });

  /// 获取专辑列表
  ///
  /// [artistName] 传入时仅返回该歌手下的专辑。
  Future<List<Album>> fetchAlbums({String? artistName});

  /// 获取歌手列表
  Future<List<Artist>> fetchArtists();

  /// 获取某张专辑下的歌曲
  Future<List<SongItem>> fetchAlbumSongs(Album album);

  // ---------- 搜索 ----------

  /// 按关键词搜索歌曲
  Future<List<SongItem>> search(String keyword);

  // ---------- 收藏 ----------

  /// 获取收藏歌曲列表
  Future<List<FavoriteSong>> fetchFavorites();

  /// 收藏歌曲
  Future<void> addFavorite(SongItem song);

  /// 取消收藏
  Future<void> removeFavorite(String songId);

  // ---------- 播放资源 ----------

  /// 获取可播放的音频流地址（现有播放器直接消费）
  Future<String> getPlaybackUrl(SongItem song);

  /// 获取封面地址（可能为 null，调用方走默认封面）
  Future<String?> getCoverUrl(SongItem song);

  // ---------- 歌单 CRUD ----------

  /// 获取歌单列表
  Future<List<Playlist>> fetchPlaylists();

  /// 获取歌单内的歌曲
  Future<List<SongItem>> fetchPlaylistSongs(String playlistId);

  /// 创建歌单，返回新建的歌单
  Future<Playlist> createPlaylist(String name);

  /// 删除歌单
  Future<void> deletePlaylist(String playlistId);

  /// 向歌单添加歌曲
  Future<void> addSongToPlaylist(String playlistId, String songId);

  /// 从歌单移除歌曲
  Future<void> removeSongFromPlaylist(String playlistId, String songId);
}
