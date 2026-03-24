import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/library/song_item.dart';
import '../../services/player/audio_player_service.dart';

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
      if (next != null) {
        _updatePlayerState(next);
      }
    });
    
    // 监听当前歌曲
    ref.listen(currentSongProvider, (previous, next) {
      if (next != null) {
        _currentSong = next;
      }
    });
    
    // 初始化音频服务
    ref.read(audioPlayerServiceProvider).initialize();
    
    return PlayerState.idle;
  }

  /// 当前播放的歌曲
  SongItem? _currentSong;
  
  /// 当前播放进度（秒）
  double _currentPosition = 0.0;
  
  /// 歌曲总时长（秒）
  double _duration = 0.0;
  
  /// 播放队列
  List<SongItem> _playQueue = [];
  
  /// 当前播放索引
  int _currentIndex = -1;

  /// 获取当前播放的歌曲
  SongItem? get currentSong => _currentSong;

  /// 获取当前播放进度
  double get currentPosition => _currentPosition;

  /// 获取歌曲总时长
  double get duration => _duration;

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
      await ref.read(audioPlayerServiceProvider).setPlayQueue(queue, startIndex: startIndex);
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

  /// 更新播放进度
  void updatePosition(double position) {
    _currentPosition = position;
  }

  /// 更新歌曲时长
  void updateDuration(double newDuration) {
    _duration = newDuration;
  }

  /// 更新播放状态
  void _updatePlayerState(PlaybackState playbackState) {
    switch (playbackState.playing) {
      case true:
        state = PlayerState.playing;
        break;
      case false:
        if (playbackState.processingState == ProcessingState.loading) {
          state = PlayerState.loading;
        } else if (playbackState.processingState == ProcessingState.error) {
          state = PlayerState.error;
        } else {
          state = PlayerState.paused;
        }
        break;
    }
  }

  /// 清除播放状态
  void clear() {
    _currentSong = null;
    _currentPosition = 0.0;
    _duration = 0.0;
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
  return ref.watch(currentSongProviderFromAudioService);
});

/// 音频服务当前歌曲的 Provider
final currentSongProviderFromAudioService = Provider<SongItem?>((ref) {
  final service = ref.read(audioPlayerServiceProvider);
  return service.currentSong;
});

/// 播放进度的 Provider
final playbackProgressProvider = Provider<double>((ref) {
  final service = ref.read(audioPlayerServiceProvider);
  final currentPosition = service.currentPosition.inMilliseconds.toDouble();
  final duration = service.duration?.inMilliseconds.toDouble() ?? 1.0;
  return duration > 0 ? currentPosition / duration : 0.0;
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

/// 播放状态流 Provider
final playbackStateStreamProvider = StreamProvider<PlaybackState>((ref) {
  final service = ref.read(audioPlayerServiceProvider);
  return service.playbackState;
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