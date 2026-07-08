import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/library/album.dart';
import '../../services/library/library_repository.dart';
import '../login/login_page.dart';
import 'library_providers.dart';
import 'album_detail_page.dart';

class AlbumsPage extends ConsumerWidget {
  const AlbumsPage({super.key, this.artistName});

  final String? artistName;

  static const routeName = 'albums';
  static const routePath = '/albums';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(albumsProvider(artistName));

    // 监听会话失效
    ref.listen<AsyncValue<List<Album>>>(
      albumsProvider(artistName),
      (previous, next) {
        next.whenOrNull(
          error: (error, stackTrace) {
            if (error is SessionExpiredException) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  context.go(LoginPage.routePath);
                }
              });
            }
          },
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(artistName ?? '专辑'),
      ),
      body: albumsAsync.when(
        data: (albums) {
          if (albums.isEmpty) {
            return const Center(child: Text('暂无专辑'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(albumsProvider(artistName).future),
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              itemCount: albums.length,
              itemBuilder: (context, index) {
                final album = albums[index];
                return _AlbumCard(
                  album: album,
                  onTap: () {
                    context.pushNamed(
                      AlbumDetailPage.routeName,
                      extra: album,
                    );
                  },
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          final isSessionExpired = error is SessionExpiredException;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                  Text(
                    '$error',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: isSessionExpired
                        ? () => context.go(LoginPage.routePath)
                        : () => ref.refresh(albumsProvider(artistName)),
                    child: Text(isSessionExpired ? '去登录' : '重试'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({required this.album, required this.onTap});

  final Album album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: album.coverUrl != null
                  ? Image.network(
                      album.coverUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildDefaultCover(context);
                      },
                    )
                  : _buildDefaultCover(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            album.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(
            album.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultCover(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.album, size: 48),
    );
  }
}
