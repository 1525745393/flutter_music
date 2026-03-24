class SongItem {
  const SongItem({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.coverUrl,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final String? coverUrl;

  /// 复制并更新部分字段
  SongItem copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? coverUrl,
  }) {
    return SongItem(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      coverUrl: coverUrl ?? this.coverUrl,
    );
  }

  factory SongItem.fromMap(Map<String, dynamic> map) {
    return SongItem(
      id: '${map['id'] ?? ''}',
      title: (map['title'] as String?)?.trim().isNotEmpty == true
          ? map['title'] as String
          : '未知歌曲',
      artist: _readName(
        map['additional'],
        'song_tag',
        'artist',
        fallback: '未知歌手',
      ),
      album: _readName(
        map['additional'],
        'song_tag',
        'album',
        fallback: '未知专辑',
      ),
      coverUrl: _readCoverUrl(map['additional']),
    );
  }

  static String _readName(
    dynamic root,
    String first,
    String second, {
    required String fallback,
  }) {
    final firstMap = root is Map<String, dynamic> ? root[first] : null;
    final secondMap = firstMap is Map<String, dynamic>
        ? firstMap[second]
        : null;
    final name = secondMap is String ? secondMap.trim() : null;
    if (name == null || name.isEmpty) {
      return fallback;
    }
    return name;
  }

  /// 读取封面图URL
  static String? _readCoverUrl(dynamic additional) {
    // 尝试从additional中读取封面图路径
    final additionalMap = additional is Map<String, dynamic> ? additional : null;
    if (additionalMap == null) return null;
    
    // 尝试获取专辑封面路径
    final songTag = additionalMap['song_tag'] as Map<String, dynamic>?;
    if (songTag != null) {
      final coverPath = songTag['cover_path'] as String?;
      if (coverPath != null && coverPath.isNotEmpty) {
        return coverPath;
      }
    }
    
    // 尝试获取其他封面路径
    final songCover = additionalMap['song_cover'] as Map<String, dynamic>?;
    if (songCover != null) {
      final coverPath = songCover['path'] as String?;
      if (coverPath != null && coverPath.isNotEmpty) {
        return coverPath;
      }
    }
    
    return null;
  }
}
