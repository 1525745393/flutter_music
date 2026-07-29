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
  ///
  /// 支持一行多个时间戳的格式，例如：
  ///   [00:01.00][00:05.00]歌词文本
  /// 会为每个时间戳生成一条 LyricLine。
  static List<LyricLine> parseLrc(String lrcText) {
    final lines = <LyricLine>[];
    final linesList = lrcText.split('\n');
    // 匹配所有 [mm:ss.xx] 或 [mm:ss.xxx] 格式的时间戳
    final timeRegExp = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\]');

    for (final line in linesList) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      // 提取所有时间戳
      final timeMatches = timeRegExp.allMatches(trimmedLine);
      if (timeMatches.isEmpty) continue;

      // 提取歌词文本（移除所有时间戳后的内容）
      final text = trimmedLine.replaceAll(timeRegExp, '').trim();
      if (text.isEmpty) continue;

      // 为每个时间戳生成一条歌词行
      for (final match in timeMatches) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final fractionalPart = match.group(3)!;

        // LRC 格式：如果小数部分是 2 位数字（如 .50），表示百分之一秒，
        // 需乘以 10 转换为毫秒；3 位数字（如 .500）已经是毫秒。
        final milliseconds = fractionalPart.length == 2
            ? int.parse(fractionalPart) * 10
            : int.parse(fractionalPart);

        final time = minutes * 60000 + seconds * 1000 + milliseconds;
        lines.add(LyricLine(time: time, text: text));
      }
    }

    // 按时间排序，确保多个时间戳生成的行顺序正确
    lines.sort((a, b) => a.time.compareTo(b.time));
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
