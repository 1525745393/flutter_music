import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../login/login_page.dart';
import '../../services/auth/auth_repository.dart';
import '../player/player_page.dart';
import '../../controllers/library/library_providers.dart';
import '../../controllers/player/player_controller.dart';

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  static const routeName = 'library';
  static const routePath = '/library';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(songsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('音乐库'),
        actions: [
          IconButton(
            onPressed: () async {
              await ref.read(authRepositoryProvider).clearSession();
              if (context.mounted) {
                context.go(LoginPage.routePath);
              }
            },
            icon: const Icon(Icons.logout_rounded),
            tooltip: '退出登录',
          ),
        ],
      ),
      body: songsAsync.when(
        data: (songs) {
          if (songs.isEmpty) {
            return const Center(child: Text('音乐库为空'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(songsProvider.future),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: songs.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final song = songs[index];
                return ListTile(
                  title: Text(song.title),
                  subtitle: Text('${song.artist} · ${song.album}'),
                  trailing: const Icon(Icons.play_arrow_rounded),
                  onTap: () async {
                    // 设置当前播放的歌曲和播放队列
                    await ref.read(playerControllerProvider.notifier)
                        .setPlayQueue(songs, startIndex: index);
                    
                    // 跳转到播放页面
                    if (context.mounted) {
                      context.go(PlayerPage.routePath);
                    }
                  },
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$error', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.refresh(songsProvider),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
