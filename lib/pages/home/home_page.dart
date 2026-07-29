import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth/auth_repository.dart';
import '../../services/library/library_repository.dart';
import '../../widgets/mini_player_bar.dart';
import '../login/login_page.dart';
import '../player/player_page.dart';
import '../player/player_controller.dart';
import 'library_providers.dart';
import 'library_page.dart';
import 'search_page.dart';
import 'artists_page.dart';
import 'albums_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  static const routeName = 'home';
  static const routePath = '/home';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(songsProvider);
    final currentSong = ref.watch(currentSongProvider);
    final session = ref.watch(authRepositoryProvider).cachedSession;

    // 提取服务器名称用于设备卡片显示
    final serverName = _extractServerName(session?.serverUrl ?? '');

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 搜索栏
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.push(SearchPage.routePath),
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '搜索歌曲/歌手/专辑',
                              style: TextStyle(
                                fontSize: 15,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () async {
                      await ref.read(authRepositoryProvider).clearSession();
                      if (context.mounted) {
                        context.go(LoginPage.routePath);
                      }
                    },
                    icon: const Icon(Icons.logout_rounded),
                    tooltip: '退出登录',
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),

            // 可滚动内容
            Expanded(
              child: songsAsync.when(
                data: (songs) {
                  return RefreshIndicator(
                    onRefresh: () => ref.refresh(songsProvider.future),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        // 设备/库信息卡片
                        _DeviceInfoCard(
                          serverName: serverName,
                          songCount: songs.length,
                        ),
                        const SizedBox(height: 24),

                        // 分类入口网格
                        _CategoryGrid(
                          songCount: songs.length,
                        ),
                        const SizedBox(height: 28),

                        // 歌单区域
                        _SectionHeader(title: '歌单', actionLabel: null),
                        const SizedBox(height: 12),
                        _PlaylistCard(
                          icon: Icons.shuffle_rounded,
                          title: '随机播放',
                          subtitle: '${songs.length} 首歌曲',
                          color: Colors.deepPurple,
                          onTap: () async {
                            if (songs.isNotEmpty) {
                              songs.shuffle();
                              await ref
                                  .read(playerControllerProvider.notifier)
                                  .setPlayQueue(songs, startIndex: 0);
                              if (context.mounted) {
                                context.go(PlayerPage.routePath);
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        _PlaylistCard(
                          icon: Icons.favorite_rounded,
                          title: '我的收藏',
                          subtitle: '收藏的歌曲',
                          color: Colors.pink,
                          onTap: () {
                            context.push('/favorites');
                          },
                        ),

                        // 为迷你播放栏留出空间
                        if (currentSong != null) const SizedBox(height: 72),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) {
                  final isSessionExpired = error is SessionExpiredException;
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSessionExpired
                                ? Icons.warning_amber_rounded
                                : Icons.error_outline,
                            size: 48,
                            color: isSessionExpired
                                ? Colors.orange
                                : Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: 12),
                          Text('$error', textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: isSessionExpired
                                ? () => context.go(LoginPage.routePath)
                                : () => ref.refresh(songsProvider),
                            child: Text(isSessionExpired ? '去登录' : '重试'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // 迷你播放栏
            if (currentSong != null) const MiniPlayerBar(),
          ],
        ),
      ),
    );
  }

  /// 从 serverUrl 中提取简洁的服务器名称
  String _extractServerName(String url) {
    if (url.isEmpty) return 'NAS';
    var host = url.trim();
    if (host.startsWith('https://')) host = host.substring(8);
    if (host.startsWith('http://')) host = host.substring(7);
    final slashIndex = host.indexOf('/');
    if (slashIndex > 0) host = host.substring(0, slashIndex);
    final colonIndex = host.indexOf(':');
    if (colonIndex > 0) host = host.substring(0, colonIndex);
    return host;
  }
}

/// 设备/库信息卡片
class _DeviceInfoCard extends StatelessWidget {
  const _DeviceInfoCard({
    required this.serverName,
    required this.songCount,
  });

  final String serverName;
  final int songCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.dns_outlined,
              size: 30,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  serverName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '共 $songCount 首',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 分类入口网格（3 列 x 2 行）
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.songCount});

  final int songCount;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.1,
      children: [
        _CategoryItem(
          icon: Icons.library_music_rounded,
          label: '所有歌曲',
          subtitle: '$songCount 首',
          color: Colors.blue,
          onTap: () => context.push(LibraryPage.routePath),
        ),
        _CategoryItem(
          icon: Icons.favorite_rounded,
          label: '收藏',
          subtitle: '喜欢的歌曲',
          color: Colors.pink,
          onTap: () => context.push('/favorites'),
        ),
        _CategoryItem(
          icon: Icons.album_rounded,
          label: '专辑',
          subtitle: null,
          color: Colors.orange,
          onTap: () => context.push(AlbumsPage.routePath),
        ),
        _CategoryItem(
          icon: Icons.person_rounded,
          label: '歌手',
          subtitle: null,
          color: Colors.teal,
          onTap: () => context.push(ArtistsPage.routePath),
        ),
        _CategoryItem(
          icon: Icons.folder_rounded,
          label: '文件夹',
          subtitle: null,
          color: Colors.amber,
          onTap: () => context.push('/folders'),
        ),
        _CategoryItem(
          icon: Icons.shuffle_rounded,
          label: '随机播放',
          subtitle: null,
          color: Colors.deepPurple,
          onTap: () async {
            // 需要获取歌曲列表才能随机播放
            // 这个由 HomePage builder 处理
          },
        ),
      ],
    );
  }
}

/// 单个分类入口
class _CategoryItem extends StatelessWidget {
  const _CategoryItem({
    required this.icon,
    required this.label,
    required this.color,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 11,
                  color: color.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 区域标题
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel});

  final String title;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: () {},
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

/// 歌单卡片
class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
