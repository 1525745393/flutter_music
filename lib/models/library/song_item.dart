class SongItem {
  const SongItem({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.coverUrl,
    this.duration = 0,
    this.rating = 0,
    this.trackNumber,
  });

  final String id;
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

  /// 复制并更新部分字段
  ///
  /// 使用 sentinel 模式支持将 nullable 字段设置为 null，
  /// 传 null 表示保持原值，传 [sentinel] 表示清空该字段。
  SongItem copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    Object? coverUrl = sentinel,
    int? duration,
    int? rating,
    Object? trackNumber = sentinel,
  }) {
    return SongItem(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      coverUrl: coverUrl is String? ? coverUrl : (coverUrl == sentinel ? this.coverUrl : null),
      duration: duration ?? this.duration,
      rating: rating ?? this.rating,
      trackNumber: trackNumber is int? ? trackNumber : (trackNumber == sentinel ? this.trackNumber : null),
    );
  }

  static const sentinel = Object();

  factory SongItem.fromMap(Map<String, dynamic> map) {
    final additional = map['additional'];
    return SongItem(
      id: '${map['id'] ?? ''}',
      title: (map['title'] as String?)?.trim().isNotEmpty == true
          ? map['title'] as String
          : '未知歌曲',
      artist: _readName(
        additional,
        'song_tag',
        'artist',
        fallback: '未知歌手',
      ),
      album: _readName(
        additional,
        'song_tag',
        'album',
        fallback: '未知专辑',
      ),
      coverUrl: _readCoverUrl(additional),
      // 歌曲时长（秒），来自 song_audio.duration
      duration: _readInt(
        additional,
        'song_audio',
        'duration',
        fallback: 0,
      ),
      // 用户评分（0-5），song_rating 为对象格式 {rating: value}
      rating: _readInt(
        additional,
        'song_rating',
        'rating',
        fallback: 0,
      ),
      // 曲目号，来自 song_tag.track
      trackNumber: _readIntOrNull(additional, 'song_tag', 'track'),
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

  /// 读取嵌套结构中的 int 字段，缺失或类型不符时返回 fallback
  /// 兼容 int 与 num（如 duration 可能是 double）
  static int _readInt(
    dynamic root,
    String first,
    String second, {
    required int fallback,
  }) {
    final firstMap = root is Map<String, dynamic> ? root[first] : null;
    final value = firstMap is Map<String, dynamic> ? firstMap[second] : null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
  }

  /// 读取嵌套结构中的可空 int 字段，缺失时返回 null
  static int? _readIntOrNull(
    dynamic root,
    String first,
    String second,
  ) {
    final firstMap = root is Map<String, dynamic> ? root[first] : null;
    final value = firstMap is Map<String, dynamic> ? firstMap[second] : null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
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
