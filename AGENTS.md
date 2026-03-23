# AGENTS.md

## 项目概述

群晖音乐播放器（Flutter）- 一款基于 Flutter 的跨平台群晖 NAS 音乐播放器应用。

### 核心功能
- 群晖 DSM 登录认证
- 音乐库浏览（专辑、歌手、歌曲）
- 在线播放与控制
- 收藏与最近播放（本地持久化）

## 技术栈

| 类别 | 技术 |
|------|------|
| 框架 | Flutter |
| 语言 | Dart 3.11.3+ |
| 状态管理 | flutter_riverpod |
| 路由 | go_router |
| 网络请求 | dio |
| 本地存储 | shared_preferences |
| 日志 | logger |

## 项目结构

```
lib/
  main.dart                 # 应用入口
  core/
    network/                # 网络层
      dio_client.dart       # Dio 客户端封装
      synology_base_api.dart    # API 基类
      synology_api.dart         # API 统一导出
      synology_api_constants.dart   # API 常量
      synology_api_exception.dart   # API 异常
      synology_auth_api.dart    # 认证 API
      synology_audio_station_api.dart  # 音频站 API
  router/
    router.dart             # 路由配置
  models/                   # 数据模型
    auth/                   # 认证相关模型
    library/                # 音乐库模型
  services/                 # 数据仓库层
    auth/
      auth_repository.dart
    library/
      library_repository.dart
  pages/                    # 页面（UI + Controller）
    login/
      login_page.dart
      login_controller.dart
    home/
      library_page.dart
      library_providers.dart
    player/
      player_page.dart
  widgets/                  # 通用组件
  utils/                    # 工具类
test/                       # 测试目录
```

## 常用命令

```bash
# 安装依赖
flutter pub get

# 代码静态分析
flutter analyze

# 运行测试
flutter test

# 运行应用（调试模式）
flutter run

# 运行应用（指定平台）
flutter run -d windows
flutter run -d chrome

# 构建发布版本
flutter build apk          # Android
flutter build ios          # iOS
flutter build windows      # Windows

# 清理构建缓存
flutter clean
```

## 代码规范

### Lint 规则
- 使用 `flutter_lints` 包的默认规则
- 配置文件：`analysis_options.yaml`
- 运行 `flutter analyze` 检查代码问题

### 命名规范
- **文件名**：snake_case（如 `login_controller.dart`）
- **类名**：PascalCase（如 `LoginController`）
- **变量/方法**：camelCase（如 `fetchSongs`）
- **常量**：camelCase 或 lowerCamelCase
- **Provider**：xxxProvider（如 `authRepositoryProvider`）

### 代码风格
- Model 类优先使用 `const` 构造函数
- 使用 `final` 声明不可变字段
- 避免在日志中打印敏感信息（密码、sessionId 等）

## 状态管理模式

### Provider 层次

| 层级 | Provider 类型 | 用途 | 示例 |
|------|---------------|------|------|
| Repository | `Provider` | 数据仓库，单例 | `authRepositoryProvider` |
| Controller | `NotifierProvider` | 业务逻辑，可变状态 | `loginControllerProvider` |
| 数据获取 | `FutureProvider` | 异步数据读取 | `songsProvider` |

### AsyncValue 使用
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

### UI 中使用
```dart
final state = ref.watch(loginControllerProvider);

state.when(
  data: (_) => /* 成功状态 */,
  loading: () => /* 加载中 */,
  error: (e, st) => /* 错误状态 */,
);
```

## API 层规范

### 基类继承
所有群晖 API 类继承 `SynologyBaseApi`：

```dart
class MyApi extends SynologyBaseApi {
  MyApi({required String serverUrl}) : super(serverUrl: serverUrl);
}
```

### 错误处理
- 网络层抛出 `SynologyApiException`
- Repository 层捕获并转换为业务异常（如 `AuthException`）
- Controller 层捕获业务异常，返回用户友好消息

### 空响应校验
使用 `requireBody()` 方法校验响应：

```dart
final body = requireBody(response.data);
```

## 错误处理规范

### 自定义异常
为每个业务模块定义专用异常类：

```dart
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
}
```

### 错误码映射
在 Repository 层将 API 错误码映射为用户友好消息：

```dart
String _mapLoginError(int? code) {
  switch (code) {
    case 401:
      return '账号或密码错误';
    // ...
    default:
      return '登录失败：未知错误';
  }
}
```

## 路由规范

### 路由定义
每个 Page 类定义静态常量：

```dart
class LoginPage extends StatelessWidget {
  static const routePath = '/login';
  static const routeName = 'login';
  // ...
}
```

### 路由配置
使用 `go_router` + Riverpod Provider：

```dart
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: LoginPage.routePath,
    routes: [
      GoRoute(
        path: LoginPage.routePath,
        name: LoginPage.routeName,
        builder: (context, state) => const LoginPage(),
      ),
      // ...
    ],
  );
});
```

### 页面跳转
```dart
context.go(LibraryPage.routePath);
context.goNamed(PlayerPage.routeName);
```

## 安全注意事项

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

## 开发工作流

1. **开始开发前**
   ```bash
   flutter pub get
   flutter analyze
   ```

2. **开发完成后**
   ```bash
   flutter analyze    # 确保无 lint 错误
   flutter test       # 运行测试
   ```

3. **提交代码前**
   - 确保通过 `flutter analyze`
   - 确保测试通过
   - 检查是否有敏感信息泄露
