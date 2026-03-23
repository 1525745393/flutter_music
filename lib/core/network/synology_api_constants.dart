/// 群晖 API 常量集中定义。
///
/// 后续新增接口时，优先在此处补充 `api 名称 / 版本 / 路径`，
/// 避免字符串散落在业务代码中。
class SynologyApiConstants {
  const SynologyApiConstants._();

  // Common
  static const sidKey = '_sid';

  // Auth API
  static const authPath = '/webapi/auth.cgi';
  static const authApiName = 'SYNO.API.Auth';
  static const authVersion = '6';
  static const authSessionAudioStation = 'AudioStation';
  static const authFormatSid = 'sid';

  // Audio Station API
  static const songPath = '/webapi/AudioStation/song.cgi';
  static const songApiName = 'SYNO.AudioStation.Song';
  static const songVersion = '3';
  static const songLibraryAll = 'all';
  static const songAdditionalTag = 'song_tag';

  static const albumPath = '/webapi/AudioStation/album.cgi';
  static const albumApiName = 'SYNO.AudioStation.Album';
  static const albumVersion = '3';

  static const artistPath = '/webapi/AudioStation/artist.cgi';
  static const artistApiName = 'SYNO.AudioStation.Artist';
  static const artistVersion = '3';

  static const playlistPath = '/webapi/AudioStation/playlist.cgi';
  static const playlistApiName = 'SYNO.AudioStation.Playlist';
  static const playlistVersion = '3';

  static const folderPath = '/webapi/AudioStation/folder.cgi';
  static const folderApiName = 'SYNO.AudioStation.Folder';
  static const folderVersion = '3';

  static const lyricsPath = '/webapi/AudioStation/lyrics.cgi';
  static const lyricsApiName = 'SYNO.AudioStation.Lyrics';
  static const lyricsVersion = '2';

  /// 封面图接口通常通过 URL 直接访问，不一定走标准 api/method 形式。
  static const coverPath = '/webapi/AudioStation/cover.cgi';
}
