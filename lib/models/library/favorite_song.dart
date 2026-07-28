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
      songId: map['songId'] as String,
      title: map['title'] as String,
      artist: map['artist'] as String,
      album: map['album'] as String,
      coverUrl: map['coverUrl'] as String?,
      // 使用 ?? 0 兜底，兼容旧版本持久化数据；as num 再 toInt 防止 double 类型
      duration: ((map['duration'] ?? 0) as num).toInt(),
      rating: ((map['rating'] ?? 0) as num).toInt(),
      trackNumber: map['trackNumber'] as int?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
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
