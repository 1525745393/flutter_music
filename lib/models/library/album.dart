/// 专辑数据模型
///
/// 对应 Audio Station API 的 Album 列表项
class Album {
  const Album({
    required this.title,
    required this.artist,
    this.songCount = 0,
    this.duration = 0,
    this.avgRating = 0.0,
    this.year,
    this.coverUrl,
  });

  /// 专辑标题
  final String title;

  /// 专辑艺术家
  final String artist;

  /// 歌曲数量
  final int songCount;

  /// 总时长（秒）
  final int duration;

  /// 平均评分（0-5）
  final double avgRating;

  /// 发行年份
  final int? year;

  /// 封面图 URL
  final String? coverUrl;

  /// 复制并更新部分字段
  Album copyWith({
    String? title,
    String? artist,
    int? songCount,
    int? duration,
    double? avgRating,
    Object? year = _sentinel,
    Object? coverUrl = _sentinel,
  }) {
    return Album(
      title: title ?? this.title,
      artist: artist ?? this.artist,
      songCount: songCount ?? this.songCount,
      duration: duration ?? this.duration,
      avgRating: avgRating ?? this.avgRating,
      year: year is int ? year : (year == _sentinel ? this.year : null),
      coverUrl: coverUrl is String? ? coverUrl : (coverUrl == _sentinel ? this.coverUrl : null),
    );
  }

  static const _sentinel = Object();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Album && other.title == title && other.artist == artist;
  }

  @override
  int get hashCode => Object.hash(title, artist);

  /// 从 API 响应解析
  ///
  /// 数据结构：{ name: "xxx", album_artist: "xxx", additional: { avg_rating: { rating: 5 } } }
  ///
  /// 注意：coverUrl 不在此处解析，由 [LibraryRepository] 通过 [copyWith] 注入，
  /// 因为封面 URL 需要 sid、专辑名等 API 上下文参数。
  factory Album.fromMap(Map<String, dynamic> map) {
    final title = (map['name'] as String?)?.trim();
    final artist = (map['album_artist'] as String?)?.trim();
    final year = (map['year'] as num?)?.toInt();

    // 从 additional 中读取补充信息
    // avg_rating 是对象格式：{ "rating": 5 }，参考 AudioStation 接口文档
    final additional = map['additional'] as Map<String, dynamic>?;
    final avgRatingMap = additional?['avg_rating'] as Map<String, dynamic>?;
    final avgRating =
        ((avgRatingMap?['rating'] as num?)?.toDouble()) ?? 0.0;
    final songCount = (map['song_count'] as num?)?.toInt() ?? 0;
    final duration = (map['duration'] as num?)?.toInt() ?? 0;

    return Album(
      title: (title != null && title.isNotEmpty) ? title : '未知专辑',
      artist: (artist != null && artist.isNotEmpty) ? artist : '未知艺术家',
      songCount: songCount,
      duration: duration,
      avgRating: avgRating,
      year: year,
    );
  }
}
