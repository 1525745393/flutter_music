import 'package:flutter/material.dart';

class PlayerPage extends StatelessWidget {
  const PlayerPage({super.key});

  static const routeName = 'player';
  static const routePath = '/player';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('正在播放')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.album_rounded, size: 80),
            ),
            const SizedBox(height: 24),
            const Text(
              '示例歌曲',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text('示例歌手'),
            const SizedBox(height: 24),
            const LinearProgressIndicator(value: 0.35),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.skip_previous_rounded, size: 36),
                SizedBox(width: 24),
                Icon(Icons.pause_circle_filled_rounded, size: 56),
                SizedBox(width: 24),
                Icon(Icons.skip_next_rounded, size: 36),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
