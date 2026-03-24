import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/library/song_item.dart';
import '../../services/player/audio_player_service.dart';
import '../../services/auth/auth_repository.dart';

/// 播放状态枚举
enum PlayerState {
  idle,      // 空闲状态
  loading,   // 加载中
  playing,   // 播放中
  paused,    // 暂停
  error,     // 错误
}

/// 播放控制器
class PlayerController extends Notifier<PlayerState> {
  @override
  PlayerState build() {
    // 监听音频播放服务状态
    ref.listen(playbackStateProvider, (previous, next) {
      if (next.value != null) {
        _updatePlayerState(next.value!);
      }
    });
    
    // 初始化音频服务
    _initializeAudioService();
    
    return PlayerState.idle;
  }

  /// 初始化音频服务
  Future<void> _initializeAudioService() async {
    final service = ref.read(audioPlayerServiceProvider);
    final authRepository = ref.read(authRepositoryProvider);
    final session = await authRepository.loadSession();
    if (session != null) {
      service.setServerUrl(session.serverUrl);
    }
    await service.initialize();
  }

  /// 当前播放的歌曲
  SongItem? _currentSong;
  
  /// 播放队列
  List<SongItem> _playQueue = [];
  
  /// 当前播放索引
  int _currentIndex = -1;

  /// 获取当前播放的歌曲
  SongItem? get currentSong => _currentSong;

  /// 获取播放队列
  List<SongItem> get playQueue => List.unmodifiable(_playQueue);

  /// 获取当前播放索引
  int get currentIndex => _currentIndex;

  /// 设置播放队列
  Future<void> setPlayQueue(List<SongItem> queue, {int startIndex = 0}) async {
    _playQueue = queue;
    _currentIndex = startIndex;
    
    if (_playQueue.isNotEmpty && startIndex < _playQueue.length) {
      _currentSong = _playQueue[startIndex];
      state = PlayerState.loading;
      
      // 设置音频播放服务队列
      final service = ref.read(audioPlayerServiceProvider);
      final authRepository = ref.read(authRepositoryProvider);
      final session = await authRepository.loadSession();
      if (session != null) {
        service.setServerUrl(session.serverUrl);
      }
      await service.setPlayQueue(queue, startIndex: startIndex);
    }
  }

  /// 播放
  Future<void> play() async {
    try {
      await ref.read(audioPlayerServiceProvider).play();
      state = PlayerState.playing;
    } catch (e) {
      state = PlayerState.error;
      throw Exception('播放失败: $e');
    }
  }

  /// 暂停
  Future<void> pause() async {
    try {
      await ref.read(audioPlayerServiceProvider).pause();
      state = PlayerState.paused;
    } catch (e) {
      state = PlayerState.error;
      throw Exception('暂停失败: $e');
    }
  }

  /// 停止
  Future<void> stop() async {
    try {
      await ref.read(audioPlayerServiceProvider).stop();
      state = PlayerState.idle;
    } catch (e) {
      state = PlayerState.error;
      throw Exception('停止失败: $e');
    }
  }

  /// 下一首
  Future<void> next() async {
    await ref.read(audioPlayerServiceProvider).next();
  }

  /// 上一首
  Future<void> previous() async {
    await ref.read(audioPlayerServiceProvider).previous();
  }

  /// 跳转到指定位置
  Future<void> seekTo(double positionSeconds) async {
    try {
      await ref.read(audioPlayerServiceProvider).seekTo(Duration(seconds: positionSeconds.toInt()));
    } catch (e) {
      throw Exception('跳转失败: $e');
    }
  }

  /// 更新播放状态
  void _updatePlayerState(PlaybackStateEnum playbackState) {
    switch (playbackState) {
      case PlaybackStateEnum.playing:
        state = PlayerState.playing;
        break;
      case PlaybackStateEnum.loading:
        state = PlayerState.loading;
        break;
      case PlaybackStateEnum.paused:
        state = PlayerState.paused;
        break;
      case PlaybackStateEnum.idle:
        state = PlayerState.idle;
        break;
      case PlaybackStateEnum.error:
        state = PlayerState.error;
        break;
    }
  }

  /// 清除播放状态
  void clear() {
    _currentSong = null;
    _playQueue = [];
    _currentIndex = -1;
    state = PlayerState.idle;
  }
}

/// 播放控制器 Provider
final playerControllerProvider = NotifierProvider<PlayerController, PlayerState>(
  PlayerController.new,
);

/// 当前播放歌曲的 Provider
final currentSongProvider = Provider<SongItem?>((ref) {
  return ref.watch(currentSongProviderFromService);
});

/// 播放队列的 Provider
final playQueueProvider = Provider<List<SongItem>>((ref) {
  final service = ref.read(audioPlayerServiceProvider);
  return service.playQueue;
});

/// 当前播放索引的 Provider
final currentIndexProvider = Provider<int>((ref) {
  final service = ref.read(audioPlayerServiceProvider);
  return service.currentIndex;
});

/// 播放位置流 Provider
final positionStreamProvider = StreamProvider<Duration>((ref) {
  final service = ref.read(audioPlayerServiceProvider);
  return service.positionStream;
});

/// 总时长流 Provider
final durationStreamProvider = StreamProvider<Duration?>((ref) {
  final service = ref.read(audioPlayerServiceProvider);
  return service.durationStream;
});
