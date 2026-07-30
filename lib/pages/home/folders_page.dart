import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/library/folder_item.dart';
import 'library_providers.dart';
import '../../services/library/library_repository.dart';
import '../login/login_page.dart';

class FoldersPage extends ConsumerWidget {
  const FoldersPage({super.key, this.parentId, this.title});

  final String? parentId;
  final String? title;

  static const routeName = 'folders';
  static const routePath = '/folders';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(foldersProvider(parentId));

    ref.listen<AsyncValue<List<FolderItem>>>(
      foldersProvider(parentId),
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
        title: Text(title ?? '文件夹'),
      ),
      body: foldersAsync.when(
        data: (folders) {
          if (folders.isEmpty) {
            return const Center(child: Text('暂无文件夹'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(foldersProvider(parentId).future),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final folder = folders[index];
                return _FolderRow(
                  folder: folder,
                  onTap: () {
                    context.push(
                      FoldersPage.routePath,
                      extra: <String, String?>{
                        'parentId': folder.id,
                        'title': folder.name,
                      },
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
                        : () => ref.refresh(foldersProvider(parentId)),
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

class _FolderRow extends StatelessWidget {
  const _FolderRow({required this.folder, required this.onTap});

  final FolderItem folder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        Icons.folder_rounded,
        color: Colors.amber.shade600,
        size: 36,
      ),
      title: Text(
        folder.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: folder.songCount > 0
          ? Text(
              '${folder.songCount} 首',
              style: Theme.of(context).textTheme.bodySmall,
            )
          : null,
      onTap: onTap,
    );
  }
}
