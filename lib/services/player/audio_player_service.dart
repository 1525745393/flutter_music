import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import '../../models/library/song_item.dart';
import '../../models/auth/auth_session.dart';
import '../../core/network/synology_audio_station_api.dart';
import '../auth/auth_repository.dart';

/// 播放状态（用于UI显示）
enum PlaybackStateEnum {
  idle,
  loading,
  playing,
  paused,
  error,
}

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

  /// 认证仓库引用
  AuthRepository? _authRepository;

  /// 服务器URL
  String? _serverUrl;
  
  /// 播放状态流
  Stream<PlaybackStateEnum> get playbackState => _audioPlayer.playerStateStream.map(_mapPlayerState);
  
  /// 播放位置流
  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  
  /// 缓冲位置流
  Stream<Duration> get bufferedPositionStream => _audioPlayer.bufferedPositionStream;
  
  /// 总时长流
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;

  /// 设置认证仓库
  void setAuthRepository(AuthRepository authRepository) {
    _authRepository = authRepository;
  }

  /// 设置服务器URL
  void setServerUrl(String serverUrl) {
    _serverUrl = serverUrl;
  }
  
  /// 初始化音频会话
  Future<void> initialize() async {
    try {
      _audioSession = await AudioSession.instance;
      await _audioSession!.configure(const AudioSessionConfiguration.music());
      
      // 监听播放状态变化
      _audioPlayer.playerStateStream.listen(_onPlayerStateChange);
      
      // 监听播放完成
      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          // 播放完成，自动播放下一首
          _playNext();
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
      final audioUrl = _getSongUrl(song.id, session.sessionId);
      
      // 设置数据源
      await _audioPlayer.setUrl(audioUrl);
      
    } catch (e) {
      debugPrint('加载歌曲失败: $e');
      rethrow;
    }
  }
  
  /// 获取歌曲 URL
  ///
  /// 使用智能选择：整轨文件（ID含_v_）自动转码，否则直接流播放
  String _getSongUrl(String songId, String sessionId) {
    if (_serverUrl == null) {
      throw Exception('服务器URL未设置');
    }
    final api = SynologyAudioStationApi(
      serverUrl: _serverUrl!,
      synoToken: _authRepository?.synoToken,
    );
    return api.buildSmartStreamUrl(songId: songId, sid: sessionId);
  }
  
  /// 获取认证会话
  Future<AuthSession?> _getAuthSession() async {
    if (_authRepository == null) {
      return null;
    }
    return await _authRepository!.loadSession();
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
  
  /// 播放状态变化处理
  void _onPlayerStateChange(PlayerState state) {
    debugPrint('播放状态变化: ${state.playing}, processingState: ${state.processingState}');
  }

  /// 映射播放状态
  PlaybackStateEnum _mapPlayerState(PlayerState state) {
    if (state.playing) {
      return PlaybackStateEnum.playing;
    }
    switch (state.processingState) {
      case ProcessingState.idle:
        return PlaybackStateEnum.idle;
      case ProcessingState.loading:
      case ProcessingState.buffering:
        return PlaybackStateEnum.loading;
      case ProcessingState.ready:
        return PlaybackStateEnum.paused;
      case ProcessingState.completed:
        return PlaybackStateEnum.idle;
    }
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

  /// 获取播放队列
  List<SongItem> get playQueue => List.unmodifiable(_playQueue);

  /// 获取当前播放索引
  int get currentIndex => _currentIndex;
  
  /// 清理资源
  void dispose() {
    _audioPlayer.dispose();
  }
}

/// 音频播放服务 Provider
final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final service = AudioPlayerService();
  final authRepository = ref.read(authRepositoryProvider);
  service.setAuthRepository(authRepository);
  return service;
});

/// 播放状态 Provider
final playbackStateProvider = StreamProvider<PlaybackStateEnum>((ref) {
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
final currentSongProviderFromService = Provider<SongItem?>((ref) {
  final service = ref.read(audioPlayerServiceProvider);
  return service.currentSong;
});
