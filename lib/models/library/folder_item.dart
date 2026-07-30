/// 文件夹数据模型
///
/// 对应 Audio Station API 的 Folder 列表项
class FolderItem {
  const FolderItem({
    required this.name,
    this.id = '',
    this.songCount = 0,
  });

  /// 文件夹名称
  final String name;

  /// 文件夹 ID（用于进入子目录）
  final String id;

  /// 歌曲数量
  final int songCount;

  /// 复制并更新部分字段
  FolderItem copyWith({
    String? name,
    String? id,
    int? songCount,
  }) {
    return FolderItem(
      name: name ?? this.name,
      id: id ?? this.id,
      songCount: songCount ?? this.songCount,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FolderItem && other.id == id && other.name == name;
  }

  @override
  int get hashCode => Object.hash(id, name);

  /// 从 API 响应解析
  ///
  /// 数据结构：{ "name": "folder_name", "id": "folder_123", "song_count": 5 }
  factory FolderItem.fromMap(Map<String, dynamic> map) {
    final name = (map['name'] as String?)?.trim();
    final id = (map['id'] as String?) ?? '';
    final songCount = (map['song_count'] as num?)?.toInt() ?? 0;

    return FolderItem(
      name: (name != null && name.isNotEmpty) ? name : '/',
      id: id,
      songCount: songCount,
    );
  }
}
