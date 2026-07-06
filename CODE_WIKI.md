# 群晖音乐播放器 - Code Wiki

> 最后更新：2026-07-06（分支保护规则已修复）

## 1. 项目概述

### 1.1 项目简介

本项目是一款基于 Flutter 的跨平台群晖 NAS 音乐播放器应用，实现了群晖 DSM 登录认证、音乐库浏览、在线播放控制以及收藏管理等核心功能。

### 1.2 核心功能

| 功能模块 | 描述 | 状态 |
|---------|------|------|
| 登录认证 | 群晖 DSM WebAPI 登录，自动保存会话 | ✅ 完成 |
| 音乐库浏览 | 歌曲列表展示，支持封面、歌手、专辑信息 | ✅ 完成 |
| 在线播放 | 播放/暂停/上一首/下一首/进度拖动 | ✅ 完成 |
| 歌词显示 | LRC 格式歌词解析与滚动显示 | ✅ 完成 |
| 收藏管理 | 收藏/取消收藏，本地持久化 | ✅ 完成 |
| 播放队列 | 播放列表管理，切换播放 | ✅ 完成 |

### 1.3 技术栈

| 类别 | 技术 | 版本 |
|------|------|------|
| 框架 | Flutter | 3.11.3+ |
| 语言 | Dart | 3.11.3+ |
| 状态管理 | flutter_riverpod | 3.3.1 |
| 路由 | go_router | 17.1.0 |
| 网络请求 | dio | 5.9.2 |
| 音频播放 | just_audio | 0.9.40 |
| 音频会话 | audio_session | 0.1.21 |
| 本地存储 | shared_preferences | 2.5.4 |
| 日志 | logger | 2.7.0 |
| 图片缓存 | cached_network_image | 3.3.1 |

---

## 2. 项目架构

### 2.1 整体架构图

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  LoginPage   │  │ LibraryPage  │  │  PlayerPage  │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                 │                 │               │
├─────────┼─────────────────┼─────────────────┼───────────────┤
│                     Controller Layer                        │
│  ┌──────────────────────┐  ┌──────────────────────────────┐ │
│  │   LoginController    │  │   PlayerController           │ │
│  │   (NotifierProvider) │  │   (NotifierProvider)         │ │
│  └──────────┬───────────┘  └──────────────┬───────────────┘ │
│             │                             │                 │
├─────────────┼─────────────────────────────┼─────────────────┤
│                     Repository Layer                        │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │ AuthRepository  │  │LibraryRepository│  │FavoritesRepo│ │
│  │ (Provider)      │  │ (Provider)      │  │(Provider)    │ │
│  └────────┬────────┘  └────────┬────────┘  └─────────────┘ │
│           │                    │                            │
├───────────┼────────────────────┼────────────────────────────┤
│                       API Layer                             │
│  ┌─────────────────────┐  ┌───────────────────────────────┐ │
│  │ SynologyAuthApi     │  │ SynologyAudioStationApi       │ │
│  │ (extends BaseApi)   │  │ (extends BaseApi)             │ │
│  └─────────────────────┘  └───────────────────────────────┘ │
│                              │                              │
├──────────────────────────────┼──────────────────────────────┤
│                    Network Infrastructure                   │
│              ┌───────────────────────┐                      │
│              │      DioClient        │                      │
│              │    (HTTP Client)      │                      │
│              └───────────────────────┘                      │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 分层职责

| 层级 | 职责 | 技术实现 |
|------|------|---------|
| UI Layer | 展示界面、用户交互 | Flutter Widgets |
| Controller Layer | 业务逻辑、状态管理 | Riverpod Notifier |
| Repository Layer | 数据访问、业务封装 | Riverpod Provider |
| API Layer | 群晖 WebAPI 对接 | Dio + 自定义 API 类 |
| Network Layer | HTTP 客户端封装 | Dio |

---

## 3. 项目结构

```
lib/
├── main.dart                          # 应用入口
├── core/
│   └── network/                       # 网络层
│       ├── dio_client.dart            # Dio 客户端封装
│       ├── synology_base_api.dart     # API 基类
│       ├── synology_api.dart          # API 统一导出
│       ├── synology_api_constants.dart # API 常量定义
│       ├── synology_api_exception.dart # API 异常类
│       ├── synology_auth_api.dart     # 认证 API
│       └── synology_audio_station_api.dart # 音频站 API
├── router/
│   └── router.dart                    # 路由配置
├── models/
│   ├── auth/                          # 认证模型
│   │   ├── auth_session.dart          # 会话信息
│   │   └── login_draft.dart           # 登录草稿
│   └── library/                       # 音乐库模型
│       ├── song_item.dart             # 歌曲项
│       ├── favorite_song.dart         # 收藏歌曲
│       └── lyrics.dart                # 歌词解析
├── services/
│   ├── auth/                          # 认证服务
│   │   └── auth_repository.dart       # 认证仓库
│   ├── library/                       # 音乐库服务
│   │   ├── library_repository.dart    # 音乐库仓库
│   │   └── favorites_repository.dart  # 收藏仓库
│   └── player/                        # 播放服务
│       └── audio_player_service.dart  # 音频播放服务
└── pages/
    ├── login/                         # 登录页面
    │   ├── login_page.dart            # 登录 UI
    │   └── login_controller.dart      # 登录控制器
    ├── home/                          # 首页/音乐库
    │   ├── library_page.dart          # 音乐库 UI
    │   └── library_providers.dart     # 音乐库 Providers
    └── player/                        # 播放页面
        ├── player_page.dart           # 播放页 UI
        └── player_controller.dart     # 播放控制器
```

---

## 4. 核心模块详解

### 4.1 网络层（core/network）

#### 4.1.1 DioClient

**文件路径**: [lib/core/network/dio_client.dart](file:///workspace/lib/core/network/dio_client.dart)

**职责**: 封装 Dio HTTP 客户端，配置统一的超时时间和基础 URL。

**关键实现**:

```dart
class DioClient {
  DioClient({required String baseUrl})
    : dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
  final Dio dio;
}
```

#### 4.1.2 SynologyBaseApi

**文件路径**: [lib/core/network/synology_base_api.dart](file:///workspace/lib/core/network/synology_base_api.dart)

**职责**: 群晖 API 基类，提供统一的空响应校验、URL 构建和 Dio 实例复用。

**关键方法**:

| 方法名 | 功能 | 参数 | 返回值 |
|--------|------|------|--------|
| `requireBody` | 校验响应体非空 | `Map<String, dynamic>? body` | `Map<String, dynamic>` |
| `buildAbsoluteUrl` | 构建完整 URL | `String path, Map<String, String> queryParameters` | `String` |
| `_normalizeServerUrl` | 规范化服务器地址 | `String value` | `String` |

#### 4.1.3 SynologyApiConstants

**文件路径**: [lib/core/network/synology_api_constants.dart](file:///workspace/lib/core/network/synology_api_constants.dart)

**职责**: 集中管理群晖 API 的路径、API 名称、版本号等常量，避免字符串散落在业务代码中。

**主要常量**:

| 常量组 | 说明 | 关键字段 |
|--------|------|----------|
| Auth API | 认证接口常量 | `authPath`, `authApiName`, `authVersion` |
| Song API | 歌曲接口常量 | `songPath`, `songApiName`, `songVersion` |
| Album API | 专辑接口常量 | `albumPath`, `albumApiName`, `albumVersion` |
| Artist API | 歌手接口常量 | `artistPath`, `artistApiName`, `artistVersion` |
| Playlist API | 歌单接口常量 | `playlistPath`, `playlistApiName`, `playlistVersion` |
| Lyrics API | 歌词接口常量 | `lyricsPath`, `lyricsApiName`, `lyricsVersion` |

#### 4.1.4 SynologyAuthApi

**文件路径**: [lib/core/network/synology_auth_api.dart](file:///workspace/lib/core/network/synology_auth_api.dart)

**职责**: 群晖认证 API 模块，封装登录和登出接口。

**关键方法**:

| 方法名 | 功能 | 参数 |
|--------|------|------|
| `login` | DSM 登录 | `username`, `password`, `session` |
| `logout` | 退出会话 | `sid`, `session` |

#### 4.1.5 SynologyAudioStationApi

**文件路径**: [lib/core/network/synology_audio_station_api.dart](file:///workspace/lib/core/network/synology_audio_station_api.dart)

**职责**: 群晖 Audio Station API 模块，封装音乐库相关接口。

**关键方法**:

| 方法名 | 功能 | 参数 |
|--------|------|------|
| `listSongs` | 获取歌曲列表 | `sid`, `limit`, `library`, `additional` |
| `searchSongs` | 搜索歌曲 | `sid`, `keyword`, `limit` |
| `getSongInfo` | 获取歌曲详情 | `sid`, `id` |
| `listAlbums` | 获取专辑列表 | `sid`, `limit` |
| `getAlbumInfo` | 获取专辑详情 | `sid`, `id` |
| `listArtists` | 获取歌手列表 | `sid`, `limit` |
| `getArtistInfo` | 获取歌手详情 | `sid`, `id` |
| `listPlaylists` | 获取歌单列表 | `sid`, `limit` |
| `getPlaylistInfo` | 获取歌单详情 | `sid`, `id` |
| `createPlaylist` | 创建歌单 | `sid`, `name` |
| `updatePlaylist` | 更新歌单 | `sid`, `id`, `name` |
| `deletePlaylist` | 删除歌单 | `sid`, `id` |
| `addSongsToPlaylist` | 向歌单添加歌曲 | `sid`, `playlistId`, `songIdsCsv` |
| `listFolders` | 获取文件夹树 | `sid`, `id` |
| `getLyrics` | 获取歌词 | `sid`, `songId` |
| `buildSongStreamUrl` | 构造歌曲流媒体 URL | `songId`, `sid` |
| `buildCoverUrl` | 构造封面 URL | `sid`, `songId`, `albumId`, `artistName`, `size` |

---

### 4.2 数据模型层（models）

#### 4.2.1 AuthSession

**文件路径**: [lib/models/auth/auth_session.dart](file:///workspace/lib/models/auth/auth_session.dart)

**职责**: 封装认证会话信息，包含服务器地址和会话 ID。

**字段**:

| 字段名 | 类型 | 说明 |
|--------|------|------|
| `serverUrl` | `String` | 群晖服务器地址 |
| `sessionId` | `String` | 会话 ID（SID） |

#### 4.2.2 LoginDraft

**文件路径**: [lib/models/auth/login_draft.dart](file:///workspace/lib/models/auth/login_draft.dart)

**职责**: 封装上次登录的草稿信息，用于自动填充登录表单。

**字段**:

| 字段名 | 类型 | 说明 |
|--------|------|------|
| `serverUrl` | `String` | 上次登录的服务器地址 |
| `username` | `String` | 上次登录的用户名 |

#### 4.2.3 SongItem

**文件路径**: [lib/models/library/song_item.dart](file:///workspace/lib/models/library/song_item.dart)

**职责**: 封装歌曲基本信息，支持从 API 响应映射和字段更新。

**字段**:

| 字段名 | 类型 | 说明 |
|--------|------|------|
| `id` | `String` | 歌曲 ID |
| `title` | `String` | 歌曲标题 |
| `artist` | `String` | 歌手名 |
| `album` | `String` | 专辑名 |
| `coverUrl` | `String?` | 封面图 URL |

**关键方法**:

| 方法名 | 功能 |
|--------|------|
| `copyWith` | 复制并更新部分字段 |
| `fromMap` | 从 API 响应映射创建实例 |
| `_readName` | 读取嵌套字段中的名称 |
| `_readCoverUrl` | 读取封面图 URL |

#### 4.2.4 FavoriteSong

**文件路径**: [lib/models/library/favorite_song.dart](file:///workspace/lib/models/library/favorite_song.dart)

**职责**: 封装收藏歌曲信息，包含收藏时间戳，支持序列化和反序列化。

**字段**:

| 字段名 | 类型 | 说明 |
|--------|------|------|
| `songId` | `String` | 歌曲 ID |
| `title` | `String` | 歌曲标题 |
| `artist` | `String` | 歌手名 |
| `album` | `String` | 专辑名 |
| `coverUrl` | `String?` | 封面图 URL |
| `createdAt` | `DateTime` | 收藏时间 |

**关键方法**:

| 方法名 | 功能 |
|--------|------|
| `fromSongItem` | 从 SongItem 创建 FavoriteSong |
| `fromMap` | 从 Map 创建实例（反序列化） |
| `toMap` | 转换为 Map（序列化） |
| `toSongItem` | 转换为 SongItem |

#### 4.2.5 Lyrics 相关

**文件路径**: [lib/models/library/lyrics.dart](file:///workspace/lib/models/library/lyrics.dart)

**职责**: 歌词数据模型和解析工具。

**LyricLine 字段**:

| 字段名 | 类型 | 说明 |
|--------|------|------|
| `time` | `int` | 歌词时间（毫秒） |
| `text` | `String` | 歌词文本 |

**LyricsParser 方法**:

| 方法名 | 功能 | 参数 |
|--------|------|------|
| `parseLrc` | 解析 LRC 格式歌词 | `String lrcText` |
| `findCurrentLineIndex` | 查找当前播放的歌词行索引 | `List<LyricLine> lyrics`, `int currentTimeMs` |

---

### 4.3 服务层（services）

#### 4.3.1 AuthRepository

**文件路径**: [lib/services/auth/auth_repository.dart](file:///workspace/lib/services/auth/auth_repository.dart)

**职责**: 认证业务逻辑封装，处理登录、会话管理和错误映射。

**关键方法**:

| 方法名 | 功能 | 参数 | 返回值 |
|--------|------|------|--------|
| `login` | 登录并保存会话 | `serverUrl`, `username`, `password` | `Future<void>` |
| `loadLastLoginDraft` | 加载上次登录草稿 | 无 | `Future<LoginDraft?>` |
| `loadSession` | 加载会话信息 | 无 | `Future<AuthSession?>` |
| `clearSession` | 清除会话 | 无 | `Future<void>` |
| `_mapLoginError` | 映射 API 错误码为用户友好消息 | `int? code` | `String` |

**错误码映射**:

| 错误码 | 消息 |
|--------|------|
| 400 | 请求参数错误 |
| 401 | 账号或密码错误 |
| 402 | 权限不足 |
| 403 | 需要二次验证 |
| 404 | 二次验证码错误 |
| 407 | IP 已被封禁 |
| 其他 | 未知错误 |

**Provider 定义**:

```dart
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});
```

#### 4.3.2 LibraryRepository

**文件路径**: [lib/services/library/library_repository.dart](file:///workspace/lib/services/library/library_repository.dart)

**职责**: 音乐库业务逻辑封装，处理歌曲列表获取和歌词获取。

**关键方法**:

| 方法名 | 功能 | 参数 | 返回值 |
|--------|------|------|--------|
| `fetchSongs` | 获取歌曲列表 | `int limit` | `Future<List<SongItem>>` |
| `fetchLyrics` | 获取歌曲歌词 | `String songId` | `Future<List<LyricLine>>` |

**Provider 定义**:

```dart
final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return LibraryRepository(ref.read(authRepositoryProvider));
});
```

#### 4.3.3 FavoritesRepository

**文件路径**: [lib/services/library/favorites_repository.dart](file:///workspace/lib/services/library/favorites_repository.dart)

**职责**: 收藏管理业务逻辑，使用 shared_preferences 持久化存储。

**关键方法**:

| 方法名 | 功能 | 参数 | 返回值 |
|--------|------|------|--------|
| `getAllFavorites` | 获取所有收藏歌曲 | 无 | `Future<List<FavoriteSong>>` |
| `addFavorite` | 添加收藏 | `SongItem song` | `Future<void>` |
| `removeFavorite` | 移除收藏 | `String songId` | `Future<void>` |
| `isFavorite` | 检查是否已收藏 | `String songId` | `Future<bool>` |
| `clearAll` | 清空所有收藏 | 无 | `Future<void>` |

**Provider 定义**:

```dart
final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return FavoritesRepository();
});

final favoritesListProvider = FutureProvider<List<FavoriteSong>>((ref) async {
  final repository = ref.read(favoritesRepositoryProvider);
  return repository.getAllFavorites();
});

final isFavoriteProvider = FutureProvider.family<bool, String>((ref, songId) async {
  final repository = ref.read(favoritesRepositoryProvider);
  return repository.isFavorite(songId);
});
```

#### 4.3.4 AudioPlayerService

**文件路径**: [lib/services/player/audio_player_service.dart](file:///workspace/lib/services/player/audio_player_service.dart)

**职责**: 音频播放服务，封装 just_audio 和 audio_session，管理播放队列和播放状态。

**设计模式**: 单例模式（Singleton）

**播放状态枚举（PlaybackStateEnum）**:

| 状态 | 说明 |
|------|------|
| `idle` | 空闲状态 |
| `loading` | 加载中 |
| `playing` | 播放中 |
| `paused` | 暂停 |
| `error` | 错误 |

**关键方法**:

| 方法名 | 功能 | 参数 |
|--------|------|------|
| `initialize` | 初始化音频会话 | 无 |
| `setPlayQueue` | 设置播放队列 | `List<SongItem> queue`, `int startIndex` |
| `play` | 播放 | 无 |
| `pause` | 暂停 | 无 |
| `stop` | 停止 | 无 |
| `next` | 下一首 | 无 |
| `previous` | 上一首 | 无 |
| `seekTo` | 跳转到指定位置 | `Duration position` |
| `setSpeed` | 设置播放速度 | `double speed` |
| `dispose` | 清理资源 | 无 |

**流属性**:

| 属性名 | 类型 | 说明 |
|--------|------|------|
| `playbackState` | `Stream<PlaybackStateEnum>` | 播放状态流 |
| `positionStream` | `Stream<Duration>` | 播放位置流 |
| `bufferedPositionStream` | `Stream<Duration>` | 缓冲位置流 |
| `durationStream` | `Stream<Duration?>` | 总时长流 |

**Provider 定义**:

```dart
final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final service = AudioPlayerService();
  final authRepository = ref.read(authRepositoryProvider);
  service.setAuthRepository(authRepository);
  return service;
});

final playbackStateProvider = StreamProvider<PlaybackStateEnum>((ref) {
  final service = ref.read(audioPlayerServiceProvider);
  return service.playbackState;
});

final positionProvider = StreamProvider<Duration>((ref) {
  final service = ref.read(audioPlayerServiceProvider);
  return service.positionStream;
});

final durationProvider = StreamProvider<Duration?>((ref) {
  final service = ref.read(audioPlayerServiceProvider);
  return service.durationStream;
});

final currentSongProviderFromService = Provider<SongItem?>((ref) {
  final service = ref.read(audioPlayerServiceProvider);
  return service.currentSong;
});
```

---

### 4.4 页面层（pages）

#### 4.4.1 LoginPage

**文件路径**: [lib/pages/login/login_page.dart](file:///workspace/lib/pages/login/login_page.dart)

**职责**: 登录页面 UI，包含服务器地址、账号、密码输入表单。

**路由配置**:

| 常量 | 值 |
|------|-----|
| `routeName` | `'login'` |
| `routePath` | `'/login'` |

**关键功能**:
- 表单验证（服务器地址格式、账号密码非空）
- 自动填充上次登录信息
- 登录状态显示（加载中禁用按钮）
- 错误提示（SnackBar）

#### 4.4.2 LoginController

**文件路径**: [lib/pages/login/login_controller.dart](file:///workspace/lib/pages/login/login_controller.dart)

**职责**: 登录页面状态控制器，管理登录流程和状态。

**状态类型**: `AsyncValue<void>`

**关键方法**:

| 方法名 | 功能 | 参数 | 返回值 |
|--------|------|------|--------|
| `login` | 执行登录 | `serverUrl`, `username`, `password` | `Future<String?>` |

**Provider 定义**:

```dart
final loginControllerProvider = NotifierProvider<LoginController, AsyncValue<void>>(LoginController.new);

final lastLoginDraftProvider = FutureProvider<LoginDraft?>((ref) {
  return ref.read(authRepositoryProvider).loadLastLoginDraft();
});
```

#### 4.4.3 LibraryPage

**文件路径**: [lib/pages/home/library_page.dart](file:///workspace/lib/pages/home/library_page.dart)

**职责**: 音乐库首页，展示歌曲列表，支持收藏和点击播放。

**路由配置**:

| 常量 | 值 |
|------|-----|
| `routeName` | `'library'` |
| `routePath` | `'/library'` |

**关键功能**:
- 歌曲列表展示（封面、标题、歌手、专辑）
- 下拉刷新
- 收藏/取消收藏切换
- 点击跳转到播放页
- 退出登录

#### 4.4.4 LibraryProviders

**文件路径**: [lib/pages/home/library_providers.dart](file:///workspace/lib/pages/home/library_providers.dart)

**职责**: 音乐库页面相关 Provider 定义。

**Provider 定义**:

```dart
final songsProvider = FutureProvider<List<SongItem>>((ref) {
  return ref.read(libraryRepositoryProvider).fetchSongs();
});
```

#### 4.4.5 PlayerPage

**文件路径**: [lib/pages/player/player_page.dart](file:///workspace/lib/pages/player/player_page.dart)

**职责**: 播放页面，展示当前播放歌曲信息、歌词、进度条和播放控制。

**路由配置**:

| 常量 | 值 |
|------|-----|
| `routeName` | `'player'` |
| `routePath` | `'/player'` |

**关键功能**:
- 专辑封面展示（缓存加载）
- 歌曲信息显示（标题、歌手、专辑）
- 歌词滚动显示（高亮当前行）
- 播放进度条（支持拖动）
- 播放控制按钮（上一首/播放/暂停/下一首）
- 播放队列弹窗

#### 4.4.6 PlayerController

**文件路径**: [lib/pages/player/player_controller.dart](file:///workspace/lib/pages/player/player_controller.dart)

**职责**: 播放页面状态控制器，管理播放状态和操作。

**播放状态枚举（PlayerState）**:

| 状态 | 说明 |
|------|------|
| `idle` | 空闲状态 |
| `loading` | 加载中 |
| `playing` | 播放中 |
| `paused` | 暂停 |
| `error` | 错误 |

**关键方法**:

| 方法名 | 功能 | 参数 |
|--------|------|------|
| `setPlayQueue` | 设置播放队列 | `List<SongItem> queue`, `int startIndex` |
| `play` | 播放 | 无 |
| `pause` | 暂停 | 无 |
| `stop` | 停止 | 无 |
| `next` | 下一首 | 无 |
| `previous` | 上一首 | 无 |
| `seekTo` | 跳转到指定位置 | `double positionSeconds` |
| `clear` | 清除播放状态 | 无 |

**Provider 定义**:

```dart
final playerControllerProvider = NotifierProvider<PlayerController, PlayerState>(PlayerController.new);

final currentSongProvider = Provider<SongItem?>((ref) {
  return ref.watch(currentSongProviderFromService);
});

final playQueueProvider = Provider<List<SongItem>>((ref) {
  final service = ref.read(audioPlayerServiceProvider);
  return service.playQueue;
});

final currentIndexProvider = Provider<int>((ref) {
  final service = ref.read(audioPlayerServiceProvider);
  return service.currentIndex;
});

final positionStreamProvider = StreamProvider<Duration>((ref) {
  final service = ref.read(audioPlayerServiceProvider);
  return service.positionStream;
});

final durationStreamProvider = StreamProvider<Duration?>((ref) {
  final service = ref.read(audioPlayerServiceProvider);
  return service.durationStream;
});
```

---

### 4.5 路由层（router）

#### 4.5.1 Router

**文件路径**: [lib/router/router.dart](file:///workspace/lib/router/router.dart)

**职责**: 使用 go_router 配置应用路由。

**路由表**:

| 路径 | 名称 | 页面 |
|------|------|------|
| `/login` | `login` | `LoginPage` |
| `/library` | `library` | `LibraryPage` |
| `/player` | `player` | `PlayerPage` |

**初始化配置**:

```dart
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: LoginPage.routePath,  // 默认跳转登录页
    routes: [...],
  );
});
```

---

## 5. 依赖关系

### 5.1 包依赖

| 包名 | 用途 | 依赖层级 |
|------|------|----------|
| `flutter_riverpod` | 状态管理 | 全局依赖 |
| `go_router` | 路由管理 | 全局依赖 |
| `dio` | 网络请求 | API层依赖 |
| `logger` | 日志记录 | 全局依赖 |
| `shared_preferences` | 本地存储 | Repository层依赖 |
| `just_audio` | 音频播放 | 播放服务依赖 |
| `audio_service` | 后台播放 | 播放服务依赖 |
| `audio_session` | 音频会话 | 播放服务依赖 |
| `cached_network_image` | 图片缓存 | UI层依赖 |

### 5.2 模块依赖关系

```
main.dart
  └── router/router.dart
        ├── pages/login/login_page.dart
        │     └── pages/login/login_controller.dart
        │           └── services/auth/auth_repository.dart
        │                 └── core/network/synology_auth_api.dart
        │                       └── core/network/synology_base_api.dart
        │                             └── core/network/dio_client.dart
        ├── pages/home/library_page.dart
        │     ├── pages/home/library_providers.dart
        │     │     └── services/library/library_repository.dart
        │     │           ├── services/auth/auth_repository.dart
        │     │           └── core/network/synology_audio_station_api.dart
        │     └── services/library/favorites_repository.dart
        └── pages/player/player_page.dart
              ├── pages/player/player_controller.dart
              │     ├── services/player/audio_player_service.dart
              │     │     └── core/network/synology_audio_station_api.dart
              │     └── services/auth/auth_repository.dart
              └── services/library/library_repository.dart
                    └── models/library/lyrics.dart
```

---

## 6. 项目运行

### 6.1 环境要求

- Flutter SDK: 3.11.3+
- Dart SDK: 3.11.3+
- 群晖 NAS: DSM 7.0+（已安装 Audio Station 套件）

### 6.2 安装依赖

```bash
flutter pub get
```

### 6.3 代码静态分析

```bash
flutter analyze
```

### 6.4 运行测试

```bash
flutter test
```

### 6.5 运行应用

```bash
# 默认设备
flutter run

# 指定平台
flutter run -d windows
flutter run -d chrome
flutter run -d android
```

### 6.6 构建发布版本

```bash
# Android
flutter build apk

# iOS
flutter build ios

# Windows
flutter build windows

# Web
flutter build web
```

---

## 7. 状态管理模式

### 7.1 Provider 层次

| 层级 | Provider 类型 | 用途 | 示例 |
|------|---------------|------|------|
| Repository | `Provider` | 数据仓库，单例 | `authRepositoryProvider` |
| Controller | `NotifierProvider` | 业务逻辑，可变状态 | `loginControllerProvider` |
| 数据获取 | `FutureProvider` | 异步数据读取 | `songsProvider` |
| 流式数据 | `StreamProvider` | 流式数据监听 | `positionStreamProvider` |
| 带参数 | `FutureProvider.family` | 带参数的异步数据 | `isFavoriteProvider` |

### 7.2 AsyncValue 使用

Controller 状态使用 `AsyncValue` 包装，处理加载/成功/错误状态：

```dart
class LoginController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncData(null);
  }

  Future<String?> login({...}) async {
    state = const AsyncLoading();
    try {
      // 业务逻辑
      state = const AsyncData(null);
      return null;
    } catch (e, st) {
      state = AsyncError(e, st);
      return '错误消息';
    }
  }
}
```

### 7.3 UI 中使用

```dart
final state = ref.watch(loginControllerProvider);

state.when(
  data: (_) => /* 成功状态 */,
  loading: () => /* 加载中 */,
  error: (e, st) => /* 错误状态 */,
);
```

---

## 8. API 层规范

### 8.1 基类继承

所有群晖 API 类继承 `SynologyBaseApi`：

```dart
class MyApi extends SynologyBaseApi {
  MyApi({required String serverUrl}) : super(serverUrl: serverUrl);
}
```

### 8.2 错误处理

- 网络层抛出 `SynologyApiException`
- Repository 层捕获并转换为业务异常（如 `AuthException`）
- Controller 层捕获业务异常，返回用户友好消息

### 8.3 空响应校验

使用 `requireBody()` 方法校验响应：

```dart
final body = requireBody(response.data);
```

---

## 9. 错误处理规范

### 9.1 自定义异常

为每个业务模块定义专用异常类：

```dart
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
}

class LibraryException implements Exception {
  const LibraryException(this.message);
  final String message;
}

class FavoritesException implements Exception {
  const FavoritesException(this.message);
  final String message;
}
```

### 9.2 错误码映射

在 Repository 层将 API 错误码映射为用户友好消息（见 AuthRepository._mapLoginError）。

---

## 10. 安全注意事项

1. **密码处理**
   - 密码不明文持久化到本地存储
   - 登录请求使用 HTTPS

2. **会话管理**
   - Session ID 使用 `shared_preferences` 存储
   - 支持会话过期清理

3. **日志安全**
   - 生产环境禁用敏感日志
   - 日志中避免打印密码、sessionId 等敏感字段

4. **网络配置**
   - 支持 DDNS 地址
   - 配置合理的超时时间（连接 10s，读取 20s）

---

## 11. 代码规范

### 11.1 Lint 规则

- 使用 `flutter_lints` 包的默认规则
- 配置文件：[analysis_options.yaml](file:///workspace/analysis_options.yaml)
- 运行 `flutter analyze` 检查代码问题

### 11.2 命名规范

| 类型 | 规范 | 示例 |
|------|------|------|
| 文件名 | snake_case | `login_controller.dart` |
| 类名 | PascalCase | `LoginController` |
| 变量/方法 | camelCase | `fetchSongs` |
| Provider | xxxProvider | `authRepositoryProvider` |

### 11.3 代码风格

- Model 类优先使用 `const` 构造函数
- 使用 `final` 声明不可变字段
- 避免在日志中打印敏感信息（密码、sessionId 等）

---

## 12. 版本管理

### 12.1 版本命名规则

- 格式：主版本号.次版本号.修订号+构建号（例如 1.0.7+73）
- 主版本号（MAJOR）：重大变更或破坏性更新
- 次版本号（MINOR）：向后兼容的功能性新增
- 修订号（PATCH）：向后兼容的问题修复
- 构建号（BUILD_NUMBER）：每次构建递增的唯一整数

### 12.2 当前版本

- 版本号：1.0.0+1
- 配置文件：[pubspec.yaml](file:///workspace/pubspec.yaml)

---

## 13. 扩展开发指南

### 13.1 新增 API 接口

1. 在 `SynologyApiConstants` 中添加常量定义
2. 在对应的 API 类中添加方法实现
3. 在 Repository 层封装业务逻辑
4. 在 Controller 层调用并处理状态

### 13.2 新增页面

1. 创建页面 Widget（xxx_page.dart）
2. 创建控制器（xxx_controller.dart）
3. 在 `router.dart` 中注册路由
4. 使用 `GoRoute` 配置路径和名称

### 13.3 新增 Provider

根据数据类型选择合适的 Provider：

| 场景 | Provider 类型 |
|------|---------------|
| 单例服务 | `Provider` |
| 可变状态 | `NotifierProvider` |
| 异步数据 | `FutureProvider` |
| 流式数据 | `StreamProvider` |
| 带参数 | `FutureProvider.family` / `StreamProvider.family` |

---

## 14. 已知限制与待优化项

### 14.1 已知限制

- 不支持后台播放通知栏控制（audio_service 已引入但未完全实现）
- 不支持离线缓存
- 不支持多歌单管理界面
- 不支持搜索功能（API 已实现，UI 未接入）

### 14.2 待优化项

- 分页加载（当前只支持固定 limit）
- 图片缓存策略优化
- 错误重试机制
- 播放进度记忆
- 性能监控和埋点