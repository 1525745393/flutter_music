/// 群晖 API 常量集中定义。
///
/// 后续新增接口时，优先在此处补充 `api 名称 / 版本 / 路径`，
/// 避免字符串散落在业务代码中。
class SynologyApiConstants {
  const SynologyApiConstants._();

  // Common
  static const sidKey = '_sid';

  // API Info（用于查询所有 API 的元信息）
  // 官方文档：路径固定为 /webapi/entry.cgi
  static const apiInfoPath = '/webapi/entry.cgi';
  static const apiInfoApiName = 'SYNO.API.Info';
  static const apiInfoVersion = '1';

  // Auth API
  // 注意：DSM 7+ 的 Auth API 路径是 entry.cgi，不是 auth.cgi
  // 参考 AudioStation 接口文档：SYNO.API.Auth 的 path 为 entry.cgi
  static const authPath = '/webapi/entry.cgi';
  static const authApiName = 'SYNO.API.Auth';
  static const authVersion = '6';
  // session 值为小写 audiostation（官方文档明确）
  static const authSessionAudioStation = 'audiostation';
  static const authFormatSid = 'sid';

  // Audio Station API
  static const songPath = '/webapi/AudioStation/song.cgi';
  static const songApiName = 'SYNO.AudioStation.Song';
  static const songVersion = '3';
  static const songLibraryAll = 'all';
  // additional 参数：song_tag(标签) + song_audio(音频信息) + song_rating(评分)
  static const songAdditionalAll = 'song_tag,song_audio,song_rating';

  static const albumPath = '/webapi/AudioStation/album.cgi';
  static const albumApiName = 'SYNO.AudioStation.Album';
  static const albumVersion = '3';

  static const artistPath = '/webapi/AudioStation/artist.cgi';
  static const artistApiName = 'SYNO.AudioStation.Artist';
  // 文档 query.cgi 返回 maxVersion=4
  static const artistVersion = '4';

  static const playlistPath = '/webapi/AudioStation/playlist.cgi';
  static const playlistApiName = 'SYNO.AudioStation.Playlist';
  // 文档示例用 version=2
  static const playlistVersion = '2';

  static const folderPath = '/webapi/AudioStation/folder.cgi';
  static const folderApiName = 'SYNO.AudioStation.Folder';
  static const folderVersion = '3';

  static const lyricsPath = '/webapi/AudioStation/lyrics.cgi';
  static const lyricsApiName = 'SYNO.AudioStation.Lyrics';
  static const lyricsVersion = '2';

  // 歌词搜索（依赖 AudioStation 歌词插件）
  static const lyricsSearchPath = '/webapi/AudioStation/lyrics_search.cgi';
  static const lyricsSearchApiName = 'SYNO.AudioStation.LyricsSearch';
  static const lyricsSearchVersion = '2';

  // 搜索接口
  static const searchPath = '/webapi/AudioStation/search.cgi';
  static const searchApiName = 'SYNO.AudioStation.Search';
  static const searchVersion = '1';

  // 类型列表
  static const genrePath = '/webapi/AudioStation/genre.cgi';
  static const genreApiName = 'SYNO.AudioStation.Genre';
  static const genreVersion = '3';

  // 服务器信息
  static const infoPath = '/webapi/AudioStation/info.cgi';
  static const infoApiName = 'SYNO.AudioStation.Info';
  // query.cgi 返回 maxVersion=6
  static const infoVersion = '6';

  // 流媒体播放（独立 API，不是 Song 的子方法）
  static const streamPath = '/webapi/AudioStation/stream.cgi';
  static const streamApiName = 'SYNO.AudioStation.Stream';
  static const streamVersion = '2';

  /// 封面图接口
  static const coverPath = '/webapi/AudioStation/cover.cgi';
  static const coverApiName = 'SYNO.AudioStation.Cover';
  // query.cgi 返回 maxVersion=3
  static const coverVersion = '3';

  // Remote Player API（远程播放器控制）
  static const remotePlayerPath = '/webapi/AudioStation/remote_player.cgi';
  static const remotePlayerApiName = 'SYNO.AudioStation.RemotePlayer';
  // 文档 query.cgi 返回 maxVersion=3
  static const remotePlayerVersion = '3';
}
