import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/library/artist.dart';
import '../../services/library/library_repository.dart';
import '../login/login_page.dart';
import 'library_providers.dart';
import 'albums_page.dart';

class ArtistsPage extends ConsumerWidget {
  const ArtistsPage({super.key});

  static const routeName = 'artists';
  static const routePath = '/artists';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistsAsync = ref.watch(artistsProvider);

    // 监听会话失效，自动跳转到登录页
    ref.listen<AsyncValue<List<Artist>>>(
      artistsProvider,
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
        title: const Text('歌手'),
      ),
      body: artistsAsync.when(
        data: (artists) {
          if (artists.isEmpty) {
            return const Center(child: Text('暂无歌手'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(artistsProvider.future),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: artists.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final artist = artists[index];
                return ListTile(
                  title: Text(artist.name),
                  subtitle: Text('${artist.albumCount} 张专辑'),
                  leading: artist.coverUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.network(
                            artist.coverUrl!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildDefaultAvatar(context);
                            },
                          ),
                        )
                      : _buildDefaultAvatar(context),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    context.pushNamed(
                      AlbumsPage.routeName,
                      queryParameters: {'artist': artist.name},
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
                        : () => ref.refresh(artistsProvider),
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

  Widget _buildDefaultAvatar(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person),
    );
  }
}
