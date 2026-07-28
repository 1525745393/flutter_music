# 代码质量修复 Spec

## Why
全项目代码审查发现 13 个问题（3 高 / 5 中 / 5 低），涉及播放器服务缺 apiInfo、数据模型字段缺失、Repository 重复代码、播放器状态管理等。需要系统性修复以提升代码质量和功能完整性。

## What Changes
- AudioPlayerService 补传 apiInfo 参数
- SongItem 模型补充 duration / rating / trackNumber 字段
- Artist 模型补充 albumCount / songCount 解析
- LibraryRepository 抽取公共请求方法消除 6 处重复代码
- AudioPlayerService 合并重复监听、清理单例生命周期
- PlayerController 与 AudioPlayerService 状态统一
- LibraryPage 封面图改用 CachedNetworkImage
- LyricsParser 支持多时间戳行

## Impact
- Affected specs: 无
- Affected code:
  - lib/services/player/audio_player_service.dart
  - lib/models/library/song_item.dart
  - lib/models/library/artist.dart
  - lib/models/library/album.dart
  - lib/services/library/library_repository.dart
  - lib/pages/player/player_controller.dart
  - lib/pages/home/library_page.dart
  - lib/models/library/lyrics.dart

## ADDED Requirements

### Requirement: SongItem 完整字段解析
系统 SHALL 从 AudioStation API 响应中解析 song_audio（duration）、song_rating（rating）、song_tag（track_number）字段。

#### Scenario: 解析包含完整 additional 的歌曲
- **WHEN** API 返回包含 `additional.song_audio.duration`、`additional.song_rating.rating`、`additional.song_tag.track` 的歌曲数据
- **THEN** SongItem 包含对应的 duration、rating、trackNumber 字段值

#### Scenario: 解析缺少 additional 的歌曲
- **WHEN** API 返回的歌曲数据缺少 additional 字段
- **THEN** SongItem 的 duration=0、rating=0、trackNumber=null，不抛出异常

### Requirement: Artist 完整字段解析
系统 SHALL 从 API 响应中解析 album_count 和 song_count 字段。

#### Scenario: 解析包含统计数据的歌手
- **WHEN** API 返回包含 `album_count` 和 `song_count` 的歌手数据
- **THEN** Artist 的 albumCount 和 songCount 包含正确值

### Requirement: 歌词多时间戳解析
系统 SHALL 支持 LRC 格式中一行多个时间戳的解析。

#### Scenario: 多时间戳行
- **WHEN** LRC 行为 `[00:01:00][00:05:00]歌词文本`
- **THEN** 生成两条 LyricLine，时间分别为 60000ms 和 300000ms，文本相同

## MODIFIED Requirements

### Requirement: AudioPlayerService API 版本自适应
AudioPlayerService 创建 SynologyAudioStationApi 实例时 SHALL 传入 apiInfo 参数，与 LibraryRepository 保持一致。

### Requirement: LibraryRepository 代码复用
LibraryRepository SHALL 使用统一的泛型方法处理 session 校验、API 调用、错误处理，消除 6 处重复代码。

### Requirement: 播放器状态统一
PlayerController SHALL 作为唯一状态源，AudioPlayerService SHALL 不维护独立的 _currentSong / _playQueue 副本。

### Requirement: 封面图缓存
LibraryPage 中的封面图 SHALL 使用 CachedNetworkImage 组件，与 PlayerPage 保持一致。
