# 代码质量修复 - 验证清单

## Task 1: AudioPlayerService 补传 apiInfo + 合并重复监听
- [x] `_getSongUrl` 创建 SynologyAudioStationApi 时传入 apiInfo
- [x] `playerStateStream` 只有一个 listen 调用
- [x] 播放完成时调用 onPlaybackCompleted 回调（替代原 _playNext）
- [x] 无未使用的 _onPlayerStateChange 方法残留

## Task 2: SongItem 补充 duration / rating / trackNumber 字段
- [x] SongItem 包含 duration（int）、rating（int）、trackNumber（int?）字段
- [x] fromMap 正确解析 additional.song_audio.duration
- [x] fromMap 正确解析 additional.song_rating.rating
- [x] fromMap 正确解析 additional.song_tag.track
- [x] 缺少 additional 时不抛异常，使用默认值
- [x] copyWith 支持新字段
- [x] FavoriteSong 同步更新字段、toMap、fromMap
- [x] FavoriteSong.toSongItem 正确传递新字段

## Task 3: Artist 补充 albumCount / songCount 解析
- [x] Artist.fromMap 解析 album_count 字段
- [x] Artist.fromMap 解析 song_count 字段
- [x] 缺少字段时默认为 0
- [x] ArtistsPage 显示正确的专辑/歌曲数量

## Task 4: LibraryRepository 抽取公共请求方法
- [x] 存在统一的泛型方法 _execute<T> 处理 session 校验和错误处理
- [x] fetchSongs / fetchArtists / fetchAlbums / fetchAlbumSongs / fetchLyrics 均调用统一方法
- [x] session 为 null 时抛出 SessionExpiredException
- [x] API 错误码 105/106/107/401 时清除 session 并抛出 SessionExpiredException
- [x] DioException 被捕获并转换为 LibraryException
- [x] SynologyApiException 401/403 被捕获并清除 session
- [x] 对外接口（方法签名、返回类型、异常类型）保持不变

## Task 5: 播放器状态统一 + AudioPlayerService 生命周期清理
- [x] AudioPlayerService 不再维护 _playQueue / _currentIndex / _currentSong
- [x] PlayerController 是播放队列和当前歌曲的唯一状态源
- [x] 播放/暂停/停止/下一首/上一首功能正常
- [x] 移除 AudioPlayerService 的手动单例模式
- [x] audioPlayerServiceProvider 正确管理生命周期（ref.onDispose）

## Task 6: LibraryPage 封面缓存 + LyricsParser 多时间戳
- [x] LibraryPage 封面图使用 CachedNetworkImage
- [x] `[00:01:00][00:05:00]歌词` 解析为两条 LyricLine
- [x] 单时间戳行仍正常解析
- [x] 无时间戳行被跳过

## 整体验证
- [x] 代码命名符合项目规范（snake_case 文件名、camelCase 变量）
- [x] 关键逻辑有中文注释说明
- [x] 无未使用的 import 或死代码
- [x] 向后兼容现有 SharedPreferences 数据（FavoriteSong fromMap 用 ?? 0 兜底）
- [ ] 运行 flutter analyze 无 lint 错误（环境无 Flutter SDK，已通过人工代码审查替代）
- [ ] 运行 flutter test 现有测试全部通过（环境无 Flutter SDK，已通过人工代码审查替代）
