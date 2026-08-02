import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/library/song_item.dart';
import '../../services/player/audio_player_service.dart';
import '../../services/auth/auth_repository.dart';
import '../../services/library/recent_plays_repository.dart';

/// 播放速度选项（1.0 = 正常）
class PlaybackSpeedNotifier extends Notifier<double> {
  @override
  double build() => 1.0;

  void set(double speed) => state = speed;
}

final playbackSpeedProvider =
    NotifierProvider<PlaybackSpeedNotifier, double>(
  PlaybackSpeedNotifier.new,
);

/// 播放状态枚举
enum PlayerState {
  idle,      // 空闲状态
  loading,   // 加载中
  playing,   // 播放中
  paused,    // 暂停
  error,     // 错误
}

/// 播放控制器
///
/// 作为播放器状态的唯一数据源，统一维护播放队列、当前索引和当前歌曲。
/// [AudioPlayerService] 仅负责音频播放控制，所有队列状态由本类管理。
class PlayerController extends Notifier<PlayerState> {
  String? _errorMessage;

  String? get errorMessage => _errorMessage;

  @override
  PlayerState build() {
    ref.listen(playbackStateProvider, (previous, next) {
      if (next.value != null) {
        _updatePlayerState(next.value!);
      }
    });

    ref.onDispose(() {
      final service = ref.read(audioPlayerServiceProvider);
      service.onPlaybackCompleted = null;
    });

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
    // 设置播放完成回调，触发下一首
    service.onPlaybackCompleted = _onPlaybackCompleted;
    await service.initialize();
  }

  /// 播放完成回调
  ///
  /// 当 [AudioPlayerService] 检测到一首歌曲播放完成时触发，
  /// 由本方法决定是否切换到下一首。
  void _onPlaybackCompleted() {
    next();
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

  /// 播放源 URL 解析器（供自定义播放源注入）
  ///
  /// 为 null 时使用默认方式：按歌曲 ID 从群晖会话构造流地址。
  /// 非空时（如 NAS 音乐库），用解析器生成完整 URL 交给播放器。
  Future<String> Function(SongItem song)? _playbackUrlResolver;

  /// 设置播放源 URL 解析器
  void setPlaybackUrlResolver(Future<String> Function(SongItem song)? resolver) {
    _playbackUrlResolver = resolver;
  }

  /// 用自定义播放源设置播放队列并开始播放
  ///
  /// [resolver] 由播放源实现（如 NAS 音乐库）提供，
  /// 生成完整音频 URL 交给播放器。队列内歌曲的播放地址
  /// 均在 [resolver] 内部构造，与默认群晖会话解耦。
  Future<void> setPlayQueueWithResolver(
    List<SongItem> queue, {
    required Future<String> Function(SongItem song) resolver,
    int startIndex = 0,
  }) async {
    _playbackUrlResolver = resolver;
    await setPlayQueue(queue, startIndex: startIndex);
  }

  /// 按当前索引加载歌曲（统一入口，兼容默认/自定义播放源）
  Future<void> _loadCurrentSong(SongItem song) async {
    final service = ref.read(audioPlayerServiceProvider);
    final resolver = _playbackUrlResolver;
    if (resolver != null) {
      final url = await resolver(song);
      await service.loadUrl(url);
    } else {
      final authRepository = ref.read(authRepositoryProvider);
      final session = await authRepository.loadSession();
      if (session != null) {
        service.setServerUrl(session.serverUrl);
      }
      await service.loadSong(song.id);
    }
  }

  /// 设置播放队列
  Future<void> setPlayQueue(List<SongItem> queue, {int startIndex = 0}) async {
    _playQueue = queue;
    _currentIndex = startIndex;

    if (_playQueue.isNotEmpty && startIndex < _playQueue.length) {
      _currentSong = _playQueue[startIndex];
      state = PlayerState.loading;
      try {
        await _loadCurrentSong(_currentSong!);
        _errorMessage = null;
      } catch (e) {
        _errorMessage = e.toString();
        state = PlayerState.error;
      }
    }
  }

  /// 当前播放速度（1.0 为正常速度）
  double _playbackSpeed = 1.0;
  double get playbackSpeed => _playbackSpeed;

  /// 设置播放速度
  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    try {
      await ref.read(audioPlayerServiceProvider).setSpeed(speed);
    } catch (_) {
      // 设置速度失败不影响当前播放状态
    }
  }

  Future<void> play() async {
    try {
      await ref.read(audioPlayerServiceProvider).play();
      _errorMessage = null;
      state = PlayerState.playing;
    } catch (e) {
      _errorMessage = e.toString();
      state = PlayerState.error;
      rethrow;
    }
  }

  Future<void> pause() async {
    try {
      await ref.read(audioPlayerServiceProvider).pause();
      _errorMessage = null;
      state = PlayerState.paused;
    } catch (e) {
      _errorMessage = e.toString();
      state = PlayerState.error;
      rethrow;
    }
  }

  Future<void> stop() async {
    try {
      await ref.read(audioPlayerServiceProvider).stop();
      _errorMessage = null;
      state = PlayerState.idle;
    } catch (e) {
      _errorMessage = e.toString();
      state = PlayerState.error;
      rethrow;
    }
  }

  Future<void> next() async {
    if (_currentIndex < _playQueue.length - 1) {
      final oldIndex = _currentIndex;
      final oldSong = _currentSong;
      _currentIndex++;
      _currentSong = _playQueue[_currentIndex];
      state = PlayerState.loading;
      try {
        await _loadCurrentSong(_currentSong!);
        await ref.read(audioPlayerServiceProvider).play();
        _errorMessage = null;
        state = PlayerState.playing;
      } catch (e) {
        _currentIndex = oldIndex;
        _currentSong = oldSong;
        _errorMessage = e.toString();
        state = PlayerState.error;
      }
    }
  }

  Future<void> previous() async {
    if (_currentIndex > 0) {
      final oldIndex = _currentIndex;
      final oldSong = _currentSong;
      _currentIndex--;
      _currentSong = _playQueue[_currentIndex];
      state = PlayerState.loading;
      try {
        await _loadCurrentSong(_currentSong!);
        await ref.read(audioPlayerServiceProvider).play();
        _errorMessage = null;
        state = PlayerState.playing;
      } catch (e) {
        _currentIndex = oldIndex;
        _currentSong = oldSong;
        _errorMessage = e.toString();
        state = PlayerState.error;
      }
    }
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
        // 自动记录最近播放
        _tryRecordPlay();
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

  /// 记录最近播放
  void _tryRecordPlay() {
    if (_currentSong == null) return;
    try {
      ref.read(recentPlaysListProvider.notifier).recordPlay(_currentSong!);
    } catch (_) {
      // 记录失败不影响播放
    }
  }

  /// 清除播放状态
  void clear() {
    _currentSong = null;
    _playQueue = [];
    _currentIndex = -1;
    _errorMessage = null;
    state = PlayerState.idle;
  }
}

/// 播放控制器 Provider
final playerControllerProvider = NotifierProvider<PlayerController, PlayerState>(
  PlayerController.new,
);

final playerErrorMessageProvider = Provider<String?>((ref) {
  ref.watch(playerControllerProvider);
  return ref.read(playerControllerProvider.notifier).errorMessage;
});

/// 当前播放歌曲的 Provider
final currentSongProvider = Provider<SongItem?>((ref) {
  // 依赖 Controller 状态变化触发重新评估
  ref.watch(playerControllerProvider);
  return ref.read(playerControllerProvider.notifier).currentSong;
});

/// 播放队列的 Provider
final playQueueProvider = Provider<List<SongItem>>((ref) {
  ref.watch(playerControllerProvider);
  return ref.read(playerControllerProvider.notifier).playQueue;
});

/// 当前播放索引的 Provider
final currentIndexProvider = Provider<int>((ref) {
  ref.watch(playerControllerProvider);
  return ref.read(playerControllerProvider.notifier).currentIndex;
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
