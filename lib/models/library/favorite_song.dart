import 'song_item.dart';

class FavoriteSong {
  const FavoriteSong({
    required this.songId,
    required this.title,
    required this.artist,
    required this.album,
    this.coverUrl,
    this.duration = 0,
    this.rating = 0,
    this.trackNumber,
    required this.createdAt,
  });

  final String songId;
  final String title;
  final String artist;
  final String album;
  final String? coverUrl;

  /// 歌曲时长（秒）
  final int duration;

  /// 用户评分（0-5）
  final int rating;

  /// 曲目号
  final int? trackNumber;

  final DateTime createdAt;

  factory FavoriteSong.fromSongItem(SongItem song) {
    return FavoriteSong(
      songId: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      coverUrl: song.coverUrl,
      duration: song.duration,
      rating: song.rating,
      trackNumber: song.trackNumber,
      createdAt: DateTime.now(),
    );
  }

  factory FavoriteSong.fromMap(Map<String, dynamic> map) {
    return FavoriteSong(
      songId: (map['songId'] as String?) ?? '',
      title: (map['title'] as String?) ?? '未知歌曲',
      artist: (map['artist'] as String?) ?? '未知歌手',
      album: (map['album'] as String?) ?? '未知专辑',
      coverUrl: map['coverUrl'] as String?,
      duration: _toInt(map['duration'], 0),
      rating: _toInt(map['rating'], 0),
      trackNumber: map['trackNumber'] as int?,
      createdAt: _parseDateTime(map['createdAt']),
    );
  }

  static int _toInt(dynamic value, int defaultValue) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    return defaultValue;
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    if (value is num) {
      var ms = value.toInt();
      // 启发式检测：如果时间戳小于 ~10^12（约 2001 年），
      // 说明可能是秒级时间戳（如 Unix timestamp），转换为毫秒。
      if (ms < 10000000000) {
        ms = ms * 1000;
      }
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'songId': songId,
      'title': title,
      'artist': artist,
      'album': album,
      'coverUrl': coverUrl,
      'duration': duration,
      'rating': rating,
      'trackNumber': trackNumber,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  SongItem toSongItem() {
    return SongItem(
      id: songId,
      title: title,
      artist: artist,
      album: album,
      coverUrl: coverUrl,
      duration: duration,
      rating: rating,
      trackNumber: trackNumber,
    );
  }
}
