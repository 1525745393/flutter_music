import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
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
///
/// 仅负责音频播放控制，不维护播放队列状态。
/// 队列管理由上层 [PlayerController] 统一负责，
/// 通过 [onPlaybackCompleted] 回调通知播放完成事件。
class AudioPlayerService {
  AudioPlayerService();

  /// Just Audio 播放器
  final AudioPlayer _audioPlayer = AudioPlayer();

  /// 音频会话
  AudioSession? _audioSession;

  /// 认证仓库引用
  AuthRepository? _authRepository;

  /// 服务器URL
  String? _serverUrl;

  /// 播放完成回调
  ///
  /// 当一首歌曲播放完成时触发，由上层 Controller 决定是否播放下一首。
  void Function()? onPlaybackCompleted;

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

      // 监听播放完成，通过回调通知上层
      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          onPlaybackCompleted?.call();
        }
      });
    } catch (e) {
      debugPrint('音频会话初始化失败: $e');
    }
  }

  /// 加载指定歌曲并准备播放
  Future<void> loadSong(String songId) async {
    try {
      final session = await _getAuthSession();
      if (session == null) {
        throw Exception('会话不存在，请先登录');
      }
      final audioUrl = _getSongUrl(songId, session.sessionId);
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
      apiInfo: _authRepository?.apiInfo,
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
  final service = AudioPlayerService();
  final authRepository = ref.read(authRepositoryProvider);
  service.setAuthRepository(authRepository);
  // 在 Provider 销毁时清理音频资源
  ref.onDispose(service.dispose);
  return service;
});

/// 播放状态 Provider
final playbackStateProvider = StreamProvider<PlaybackStateEnum>((ref) {
  final service = ref.read(audioPlayerServiceProvider);
  return service.playbackState;
});

/// 总时长 Provider
final durationProvider = StreamProvider<Duration?>((ref) {
  final service = ref.read(audioPlayerServiceProvider);
  return service.durationStream;
});
