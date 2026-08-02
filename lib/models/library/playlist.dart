/// 歌单数据模型
///
/// 对应 Audio Station API 的 Playlist 列表项
class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    this.songCount = 0,
    this.coverUrl,
  });

  /// 歌单 ID
  final String id;

  /// 歌单名称
  final String name;

  /// 歌曲数量
  final int songCount;

  /// 封面图 URL
  final String? coverUrl;

  /// 复制并更新部分字段
  Playlist copyWith({
    String? id,
    String? name,
    int? songCount,
    Object? coverUrl = _sentinel,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      songCount: songCount ?? this.songCount,
      coverUrl: coverUrl is String?
          ? coverUrl
          : (coverUrl == _sentinel ? this.coverUrl : null),
    );
  }

  static const _sentinel = Object();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Playlist && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  /// 从 API 响应解析
  ///
  /// 数据结构：{ id: "xxx", name: "xxx", additional: { song_count: 3 } }
  ///
  /// 注意：coverUrl 不在此处解析，由上层注入，
  /// 因为封面 URL 需要 sid、歌单上下文等 API 参数。
  factory Playlist.fromMap(Map<String, dynamic> map) {
    final name = (map['name'] as String?)?.trim();

    // 从 additional 中读取补充信息
    final additional = map['additional'] as Map<String, dynamic>?;
    final songCount = (additional?['song_count'] as num?)?.toInt() ?? 0;

    return Playlist(
      id: '${map['id'] ?? ''}',
      name: (name != null && name.isNotEmpty) ? name : '未命名歌单',
      songCount: songCount,
    );
  }
}
