/// 歌手数据模型
///
/// 对应 Audio Station API 的 Artist 列表项
class Artist {
  const Artist({
    required this.name,
    this.albumCount = 0,
    this.songCount = 0,
    this.avgRating = 0.0,
    this.coverUrl,
  });

  /// 歌手名称（唯一标识，用于查询专辑）
  final String name;

  /// 专辑数量
  final int albumCount;

  /// 歌曲数量
  final int songCount;

  /// 平均评分（0-5）
  final double avgRating;

  /// 封面图 URL
  final String? coverUrl;

  /// 复制并更新部分字段
  Artist copyWith({
    String? name,
    int? albumCount,
    int? songCount,
    double? avgRating,
    String? coverUrl,
  }) {
    return Artist(
      name: name ?? this.name,
      albumCount: albumCount ?? this.albumCount,
      songCount: songCount ?? this.songCount,
      avgRating: avgRating ?? this.avgRating,
      coverUrl: coverUrl ?? this.coverUrl,
    );
  }

  /// 从 API 响应解析
  ///
  /// 数据结构：{ name: "xxx", additional: { avg_rating: ... } }
  factory Artist.fromMap(Map<String, dynamic> map) {
    final name = (map['name'] as String?)?.trim();
    if (name == null || name.isEmpty) {
      return const Artist(name: '未知歌手');
    }

    // 从 additional 中读取补充信息
    final additional = map['additional'] as Map<String, dynamic>?;
    final avgRating =
        ((additional?['avg_rating'] as num?)?.toDouble()) ?? 0.0;

    return Artist(
      name: name,
      avgRating: avgRating,
    );
  }
}
