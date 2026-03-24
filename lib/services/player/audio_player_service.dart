import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import '../../models/library/song_item.dart';
import '../../models/auth/auth_session.dart';
import '../../core/network/synology_audio_station_api.dart';
import '../auth/auth_repository.dart';

/// 音频播放服务
class AudioPlayerService {
  static AudioPlayerService? _instance;
  
  factory AudioPlayerService() {
    _instance ??= AudioPlayerService._internal();
    return _instance!;
  }
  
  AudioPlayerService._internal();
  
  /// Just Audio 播放器
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  /// 音频会话
  AudioSession? _audioSession;
  
  /// 播放队列
  List<SongItem> _playQueue = [];
  
  /// 当前播放索引
  int _currentIndex = -1;
  
  /// 播放状态流
  Stream<PlaybackState> get playbackState => _audioPlayer.playerStateStream.map(_mapPlayerState);
  
  /// 播放位置流
  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  
  /// 缓冲位置流
  Stream<Duration> get bufferedPositionStream => _audioPlayer.bufferedPositionStream;
  
  /// 总时长流
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;
  
  /// 播放错误流
  Stream<PlayerException> get playerErrorStream => _audioPlayer.playerStateStream
      .where((state) => state.processingState == ProcessingState.error)
      .map((state) => state.error!);
  
  /// 初始化音频会话
  Future<void> initialize() async {
    try {
      _audioSession = await AudioSession.instance;
      await _audioSession!.configure(const AudioConfiguration(
        avSessionCategory: AVSessionCategory.playback,
        avSessionCategoryOptions: AVSessionCategoryOptions.defaultToSpeaker,
      ));
      
      // 监听播放状态变化
      _audioPlayer.playerStateStream.listen(_onPlayerStateChange);
      
      // 监听位置变化
      _audioPlayer.positionStream.listen((position) {
        // 可以在这里更新播放进度
      });
      
      // 监听播放完成
      _audioPlayer.sequenceStateStream.listen((sequenceState) {
        if (sequenceState?.isLast ?? false) {
          // 播放完成，自动播放下一首
          _playNext();
        }
      });
      
      // 监听播放错误
      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.error) {
          // 处理播放错误
          _handlePlaybackError(state.error);
        }
      });
      
    } catch (e) {
      debugPrint('音频会话初始化失败: $e');
    }
  }
  
  /// 设置播放队列
  Future<void> setPlayQueue(List<SongItem> queue, {int startIndex = 0}) async {
    _playQueue = queue;
    _currentIndex = startIndex;
    
    if (_playQueue.isNotEmpty && startIndex < _playQueue.length) {
      await _loadSong(_playQueue[startIndex]);
    }
  }
  
  /// 加载歌曲
  Future<void> _loadSong(SongItem song) async {
    try {
      final session = await _getAuthSession();
      if (session == null) {
        throw Exception('会话不存在，请先登录');
      }
      
      // 获取歌曲 URL
      final songInfo = await _getSongUrl(song.id, session.sessionId);
      final audioUrl = songInfo['url'] as String?;
      
      if (audioUrl == null || audioUrl.isEmpty) {
        throw Exception('无法获取歌曲 URL');
      }
      
      // 设置数据源
      await _audioPlayer.setAudioSource(
        AudioSource.uri(Uri.parse(audioUrl)),
        initialPosition: Duration.zero,
      );
      
    } catch (e) {
      debugPrint('加载歌曲失败: $e');
      rethrow;
    }
  }
  
  /// 获取歌曲 URL
  Future<Map<String, dynamic>> _getSongUrl(String songId, String sessionId) async {
    final api = SynologyAudioStationApi(serverUrl: 'placeholder'); // 需要从会话获取
    // 这里需要根据实际 API 实现
    // 返回格式: {'url': 'http://...'}
    throw UnimplementedError('需要实现获取歌曲 URL 的方法');
  }
  
  /// 获取认证会话
  Future<AuthSession?> _getAuthSession() async {
    // 这里需要实现从 AuthRepository 获取会话
    throw UnimplementedError('需要实现获取认证会话的方法');
  }
  
  /// 播放
  Future<void> play() async {
    try {
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('播放失败: $e');
      rethrow;
    }
  }
  
  /// 暂停
  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
    } catch (e) {
      debugPrint('暂停失败: $e');
      rethrow;
    }
  }
  
  /// 停止
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('停止失败: $e');
      rethrow;
    }
  }
  
  /// 下一首
  Future<void> next() async {
    _playNext();
  }
  
  /// 上一首
  Future<void> previous() async {
    _playPrevious();
  }
  
  /// 跳转到指定位置
  Future<void> seekTo(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      debugPrint('跳转失败: $e');
      rethrow;
    }
  }
  
  /// 设置播放速度
  Future<void> setSpeed(double speed) async {
    try {
      await _audioPlayer.setSpeed(speed);
    } catch (e) {
      debugPrint('设置速度失败: $e');
      rethrow;
    }
  }
  
  /// 播放下一首
  void _playNext() {
    if (_currentIndex < _playQueue.length - 1) {
      _currentIndex++;
      _loadSong(_playQueue[_currentIndex]).then((_) {
        play();
      }).catchError((e) {
        debugPrint('播放下一首失败: $e');
      });
    }
  }
  
  /// 播放上一首
  void _playPrevious() {
    if (_currentIndex > 0) {
      _currentIndex--;
      _loadSong(_playQueue[_currentIndex]).then((_) {
        play();
      }).catchError((e) {
        debugPrint('播放上一首失败: $e');
      });
    }
  }
  
  /// 处理播放错误
  void _handlePlaybackError(PlayerException? error) {
    debugPrint('播放错误: ${error?.message}');
    // 可以在这里添加错误处理逻辑，比如显示错误提示
  }
  
  /// 播放状态变化处理
  void _onPlayerStateChange(PlayerState state) {
    // 可以在这里添加状态变化处理逻辑
    debugPrint('播放状态变化: ${state.playing}');
  }
  
  /// 获取当前播放的歌曲
  SongItem? get currentSong {
    if (_currentIndex >= 0 && _currentIndex < _playQueue.length) {
      return _playQueue[_currentIndex];
    }
    return null;
  }
  
  /// 获取当前播放进度
  Duration get currentPosition => _audioPlayer.position;
  
  /// 获取总时长
  Duration? get duration => _audioPlayer.duration;
  
  /// 获取缓冲进度
  Duration get bufferedPosition => _audioPlayer.bufferedPosition;
  
  /// 是否正在播放
  bool get isPlaying => _audioPlayer.playing;
  
  /// 清理资源
  void dispose() {
    _audioPlayer.dispose();
  }
}

/// 音频播放服务 Provider
final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  return AudioPlayerService();
});

/// 播放状态 Provider
final playbackStateProvider = StreamProvider<PlaybackState>((ref) {
  final service = ref.read(audioPlayerServiceProvider);
  return service.playbackState;
});

/// 播放位置 Provider
final positionProvider = StreamProvider<Duration>((ref) {
  final service = ref.read(audioPlayerServiceProvider);
  return service.positionStream;
});

/// 总时长 Provider
final durationProvider = StreamProvider<Duration?>((ref) {
  final service = ref.read(audioPlayerServiceProvider);
  return service.durationStream;
});

/// 当前歌曲 Provider
final currentSongProvider = Provider<SongItem?>((ref) {
  final service = ref.read(audioPlayerServiceProvider);
  return service.currentSong;
});