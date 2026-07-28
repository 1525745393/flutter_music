# 代码质量修复 - 实施计划

## [x] Task 1: AudioPlayerService 补传 apiInfo + 合并重复监听
- **Priority**: high
- **Depends On**: None
- **Description**:
  - 在 `_getSongUrl` 方法中创建 `SynologyAudioStationApi` 时补传 `apiInfo: _authRepository?.apiInfo`
  - 合并 `initialize()` 中两个 `playerStateStream.listen` 为一个
  - 移除仅做 debugPrint 的 `_onPlayerStateChange` 监听
- **Acceptance Criteria Addressed**: AudioPlayerService API 版本自适应
- **Test Requirements**:
  - `programmatic` TR-1.1: `_getSongUrl` 创建 API 实例时传入 apiInfo
  - `programmatic` TR-1.2: `playerStateStream` 只有一个 listen 调用
  - `programmatic` TR-1.3: 播放完成仍能正确触发 `_playNext()`
- **Notes**: 1 行补传 + 合并监听，改动最小

## [x] Task 2: SongItem 补充 duration / rating / trackNumber 字段
- **Priority**: high
- **Depends On**: None
- **Description**:
  - SongItem 添加 `duration`（int, 秒）、`rating`（int, 0-5）、`trackNumber`（int?）字段
  - `fromMap` 解析 `additional.song_audio.duration`、`additional.song_rating.rating`、`additional.song_tag.track`
  - `copyWith` 和构造函数同步更新
  - FavoriteSong 同步添加 duration / rating / trackNumber 字段并更新 toMap / fromMap
- **Acceptance Criteria Addressed**: SongItem 完整字段解析
- **Test Requirements**:
  - `programmatic` TR-2.1: 包含 song_audio.duration 的数据正确解析为 duration 字段
  - `programmatic` TR-2.2: 包含 song_rating.rating 的数据正确解析为 rating 字段
  - `programmatic` TR-2.3: 包含 song_tag.track 的数据正确解析为 trackNumber 字段
  - `programmatic` TR-2.4: 缺少 additional 时 duration=0、rating=0、trackNumber=null 不报错
- **Notes**: 需同步更新 FavoriteSong 的序列化/反序列化

## [x] Task 3: Artist 补充 albumCount / songCount 解析
- **Priority**: high
- **Depends On**: None
- **Description**:
  - Artist.fromMap 解析 `album_count` 和 `song_count` 字段
- **Acceptance Criteria Addressed**: Artist 完整字段解析
- **Test Requirements**:
  - `programmatic` TR-3.1: 包含 album_count 的数据解析为 albumCount
  - `programmatic` TR-3.2: 包含 song_count 的数据解析为 songCount
  - `programmatic` TR-3.3: 缺少字段时默认为 0
- **Notes**: 改动很小，2 行代码

## [x] Task 4: LibraryRepository 抽取公共请求方法
- **Priority**: high
- **Depends On**: None
- **Description**:
  - 抽取私有泛型方法 `_execute<T>`，统一处理：session 校验、API 实例创建、success 校验、会话失效检测、DioException / SynologyApiException 捕获
  - 5 个方法（fetchSongs / fetchArtists / fetchAlbums / fetchAlbumSongs / fetchLyrics）改为调用 `_execute<T>`
  - 保持对外接口不变
- **Acceptance Criteria Addressed**: LibraryRepository 代码复用
- **Test Requirements**:
  - `programmatic` TR-4.1: 5 个方法对外行为不变（返回值类型、异常类型一致）
  - `programmatic` TR-4.2: session 为 null 时抛出 SessionExpiredException
  - `programmatic` TR-4.3: API 返回 success=false 且错误码 105 时清除 session 并抛出 SessionExpiredException
  - `programmatic` TR-4.4: DioException 被捕获并转换为 LibraryException
  - `human-judgement` TR-4.5: 代码行数显著减少，无重复的 try-catch 块
- **Notes**: 重构量最大，但纯内部重构，不改变对外接口

## [x] Task 5: 播放器状态统一 + AudioPlayerService 生命周期清理
- **Priority**: medium
- **Depends On**: Task 1
- **Description**:
  - AudioPlayerService 移除 `_currentSong` / `_playQueue` / `_currentIndex` 字段，改为只负责音频播放
  - PlayerController 作为唯一状态源，维护 playQueue / currentIndex / currentSong
  - AudioPlayerService 的 `setPlayQueue` 改为 `loadSong(String url)`，由 Controller 传入 URL
  - 移除 AudioPlayerService 的单例模式，完全由 Riverpod 管理生命周期
- **Acceptance Criteria Addressed**: 播放器状态统一
- **Test Requirements**:
  - `programmatic` TR-5.1: AudioPlayerService 不再维护 _playQueue / _currentIndex
  - `programmatic` TR-5.2: PlayerController.currentSong / playQueue / currentIndex 正确返回当前值
  - `programmatic` TR-5.3: 播放/暂停/下一首/上一首功能正常
  - `programmatic` TR-5.4: _playNext / _playPrevious 由 Controller 调用，Service 只负责播放
- **Notes**: 架构调整，影响面较大

## [x] Task 6: LibraryPage 封面改用 CachedNetworkImage + LyricsParser 多时间戳
- **Priority**: low
- **Depends On**: None
- **Description**:
  - LibraryPage 中 `Image.network` 改为 `CachedNetworkImage`
  - LyricsParser.parseLrc 支持一行多个时间戳 `[mm:ss.xx][mm:ss.xx]歌词`
- **Acceptance Criteria Addressed**: 封面图缓存, 歌词多时间戳解析
- **Test Requirements**:
  - `programmatic` TR-6.1: LibraryPage 使用 CachedNetworkImage 组件
  - `programmatic` TR-6.2: `[00:01:00][00:05:00]歌词` 解析为两条 LyricLine
  - `programmatic` TR-6.3: 单时间戳行仍正常解析
- **Notes**: 两个独立小修复，可并行

# Task Dependencies
- Task 5 depends on Task 1
- Task 1, 2, 3, 4, 6 无依赖，可并行
