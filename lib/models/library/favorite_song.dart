import 'song_item.dart';

class FavoriteSong {
  const FavoriteSong({
    required this.songId,
    required this.title,
    required this.artist,
    required this.album,
    this.coverUrl,
    required this.createdAt,
  });

  final String songId;
  final String title;
  final String artist;
  final String album;
  final String? coverUrl;
  final DateTime createdAt;

  factory FavoriteSong.fromSongItem(SongItem song) {
    return FavoriteSong(
      songId: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      coverUrl: song.coverUrl,
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
    );
  }
}
