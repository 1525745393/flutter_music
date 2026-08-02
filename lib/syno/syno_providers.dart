import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repository/syno_music_repository.dart';
import 'auth/nas_auth_api.dart';
import 'config/nas_config_store.dart';

/// NAS 配置安全存储
final nasConfigStoreProvider = Provider<NasConfigStore>((ref) {
  return NasConfigStore();
});

/// NAS 认证封装（内存会话 + 安全持久化）
final nasAuthApiProvider = Provider<NasAuthApi>((ref) {
  return NasAuthApi(ref.read(nasConfigStoreProvider));
});

/// 群晖 AudioStation 数据源实现
final synoMusicRepositoryProvider = Provider<SynoMusicRepository>((ref) {
  return SynoMusicRepository(
    configStore: ref.read(nasConfigStoreProvider),
    authApi: ref.read(nasAuthApiProvider),
  );
});

/// 统一抽象接口暴露（供业务层依赖）
final activeMusicSourceProvider = Provider<dynamic>((ref) {
  return ref.read(synoMusicRepositoryProvider);
});
