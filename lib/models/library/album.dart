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
    int? year,
    String? coverUrl,
  }) {
    return Album(
      title: title ?? this.title,
      artist: artist ?? this.artist,
      songCount: songCount ?? this.songCount,
      duration: duration ?? this.duration,
      avgRating: avgRating ?? this.avgRating,
      year: year ?? this.year,
      coverUrl: coverUrl ?? this.coverUrl,
    );
  }

  /// 从 API 响应解析
  ///
  /// 数据结构：{ name: "xxx", album_artist: "xxx", additional: { avg_rating: { rating: 5 } } }
  factory Album.fromMap(Map<String, dynamic> map) {
    final title = (map['name'] as String?)?.trim();
    final artist = (map['album_artist'] as String?)?.trim();
    final year = (map['year'] as num?)?.toInt();

    if (title == null || title.isEmpty) {
      return Album(
        title: '未知专辑',
        artist: artist ?? '未知艺术家',
        year: year,
      );
    }

    // 从 additional 中读取补充信息
    // avg_rating 是对象格式：{ "rating": 5 }，参考 AudioStation 接口文档
    final additional = map['additional'] as Map<String, dynamic>?;
    final avgRatingMap = additional?['avg_rating'] as Map<String, dynamic>?;
    final avgRating =
        ((avgRatingMap?['rating'] as num?)?.toDouble()) ?? 0.0;
    final songCount = (map['song_count'] as num?)?.toInt() ?? 0;
    final duration = (map['duration'] as num?)?.toInt() ?? 0;

    return Album(
      title: title,
      artist: artist ?? '未知艺术家',
      songCount: songCount,
      duration: duration,
      avgRating: avgRating,
      year: year,
    );
  }
}
