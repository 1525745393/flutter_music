/// 歌词行数据模型
class LyricLine {
  const LyricLine({
    required this.time,
    required this.text,
  });

  /// 歌词时间（毫秒）
  final int time;

  /// 歌词文本
  final String text;
}

/// 歌词解析器
class LyricsParser {
  /// 解析LRC格式歌词
  static List<LyricLine> parseLrc(String lrcText) {
    final lines = <LyricLine>[];
    final linesList = lrcText.split('\n');

    for (final line in linesList) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      // LRC格式: [mm:ss.xx]歌词文本
      final match = RegExp(r'^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$').firstMatch(trimmedLine);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final milliseconds = int.parse(match.group(3)!);
        final time = minutes * 60000 + seconds * 1000 + milliseconds;
        final text = match.group(4)!.trim();

        if (text.isNotEmpty) {
          lines.add(LyricLine(time: time, text: text));
        }
      }
    }

    return lines;
  }

  /// 查找当前播放的歌词行索引
  static int findCurrentLineIndex(List<LyricLine> lyrics, int currentTimeMs) {
    if (lyrics.isEmpty) return -1;

    for (int i = 0; i < lyrics.length; i++) {
      if (lyrics[i].time > currentTimeMs) {
        return i > 0 ? i - 1 : 0;
      }
    }

    return lyrics.length - 1;
  }
}
