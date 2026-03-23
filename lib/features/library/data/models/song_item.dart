class SongItem {
  const SongItem({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
  });

  final String id;
  final String title;
  final String artist;
  final String album;

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
}
