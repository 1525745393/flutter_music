# 群晖音乐播放器（Flutter）项目介绍与基础规划

## 1. 项目背景与目标

本项目旨在开发一款基于 Flutter 的跨平台群晖音乐播放器，主要面向以下场景：

- 使用群晖 NAS 存储音乐，希望手机/桌面端统一播放；
- 希望具备基础的本地缓存、播放控制、歌词/封面展示能力；
- 后续可拓展歌单管理、多设备同步、离线模式等功能。

### 核心目标（MVP）

第一阶段优先完成可用闭环：

1. 登录群晖 DSM（通过 WebAPI）；
2. 拉取音乐库（专辑、歌手、歌曲）；
3. 支持在线播放（播放/暂停/上一首/下一首/进度拖动）；
4. 基础播放页（封面、标题、进度条）；
5. 收藏与最近播放（本地持久化）。

---

## 2. 技术选型建议

### 客户端

- `Flutter`：跨平台 UI 框架（Android / iOS / Windows / macOS）
- `Dart`：业务开发语言

### 状态管理

- 推荐：`Riverpod`（结构清晰，便于测试和维护）

### 网络与数据

- `dio`：网络请求
- `retrofit`（可选）：接口层封装
- `json_serializable`：模型序列化
- `freezed`（可选）：不可变模型 + union 状态

### 音频播放

- `just_audio`：核心播放能力
- `audio_service`：后台播放与通知栏控制
- `audio_session`：音频焦点管理

### 本地存储

- `isar` 或 `hive`：本地缓存（推荐 Isar）
- `shared_preferences`：轻量配置（如主题、登录历史）

### 其他

- `go_router`：路由管理
- `flutter_dotenv`：环境变量
- `logger`：日志

---

## 3. 群晖接口对接思路（高层）

> 以 DSM WebAPI / Audio Station API 为主，不同 DSM 版本接口细节可能略有差异，需要在联调时按真实返回调整。

### 对接模块拆分

- 认证模块：登录、获取/刷新会话
- 音乐库模块：歌手/专辑/歌曲列表、搜索
- 播放模块：音频 URL 获取、播放记录上报（可选）
- 媒体资源模块：封面图、歌词（若可用）

### 安全建议

- 密码不明文持久化；
- 优先使用 HTTPS；
- session/token 使用安全存储（移动端可接入 secure storage）；
- 日志中避免打印敏感字段。

---

## 4. 推荐项目结构（基础搭建模板）

```text
lib/
  main.dart
  app/
    app.dart
    router.dart
    theme/
      app_theme.dart
  core/
    constants/
    error/
    network/
      dio_client.dart
      api_result.dart
    storage/
    utils/
  features/
    auth/
      data/
        datasource/
        models/
        repositories/
      domain/
      presentation/
        pages/
        providers/
        widgets/
    library/
      data/
      domain/
      presentation/
    player/
      data/
      domain/
      presentation/
  shared/
    widgets/
    providers/
```

设计原则：

- 按 feature 组织业务，降低耦合；
- data/domain/presentation 分层，便于测试与长期维护；
- `core` 放通用能力，`shared` 放跨业务可复用组件。

---

## 5. 开发阶段规划（建议 6 周）

## Phase 0：环境初始化（第 1 周）

- 安装 Flutter 与平台工具链；
- 创建项目骨架，接入路由、状态管理、网络层；
- 统一代码规范（`flutter_lints` + format + analysis options）；
- 建立基础 CI（可选：GitHub Actions）。

交付物：

- 可运行空壳 App；
- 完整目录结构；
- 环境区分（dev/prod）。

## Phase 1：认证与音乐库（第 2-3 周）

- 群晖登录流程；
- 音乐库列表（专辑/歌手/歌曲）；
- 搜索与分页（若接口支持）；
- 错误态/空态处理。

交付物：

- 用户可登录并浏览音乐资源。

## Phase 2：播放核心（第 4 周）

- 播放队列管理；
- 播放控制（暂停/续播/切歌/拖动）；
- 播放页 UI；
- 后台播放（通知栏控制）。

交付物：

- 可稳定在线播放，支持基本后台控制。

## Phase 3：体验增强（第 5-6 周）

- 收藏、最近播放、本地缓存；
- 播放进度记忆；
- 更完整的 UI 动效与主题；
- 基础埋点与性能优化。

交付物：

- 接近可发布的 Beta 版本。

---

## 6. MVP 功能清单

### 必做

- [ ] 群晖登录（含异常提示）
- [ ] 音乐库浏览（列表/搜索）
- [ ] 在线播放与控制
- [ ] 播放页面（封面 + 进度）
- [ ] 收藏与最近播放（本地）

### 可选增强

- [ ] 歌词显示（若接口/数据可得）
- [ ] 离线缓存
- [ ] 多端同步播放进度
- [ ] CarPlay / Android Auto 适配

---

## 7. 关键风险与规避策略

1. 接口差异风险（DSM 版本）  
   - 策略：先做接口探针，统一包装 API 适配层。

2. 音频播放稳定性（后台/锁屏）  
   - 策略：尽早引入 `audio_service` 做真实设备联调。

3. 网络环境复杂（内网/外网/DDNS）  
   - 策略：配置连接诊断页，明确错误码与引导。

4. 大音乐库性能问题  
   - 策略：分页 + 懒加载 + 本地缓存索引。

---

## 8. 验收标准（MVP）

- 首次安装后 3 分钟内可完成登录并播放第一首歌；
- 播放中切后台不闪退，通知栏可控制；
- 常见异常（登录失败、网络中断、资源不可用）有清晰提示；
- 基础页面帧率稳定，滚动和切页不卡顿。
