import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/synology_audio_station_api.dart';
import '../../models/library/song_item.dart';
import '../../services/auth/auth_repository.dart';
import '../../services/library/library_repository.dart';
import '../login/login_page.dart';
import '../player/player_page.dart';
import '../player/player_controller.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  static const routeName = 'search';
  static const routePath = '/search';

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<List<SongItem>> _search(String keyword) async {
    try {
      final session = await ref.read(authRepositoryProvider).loadSession();
      if (session == null) {
        throw const SessionExpiredException('会话不存在');
      }
      final api = SynologyAudioStationApi(
        serverUrl: session.serverUrl,
        apiInfo: ref.read(authRepositoryProvider).apiInfo,
        synoToken: ref.read(authRepositoryProvider).synoToken,
      );
      final body = await api.search(
        sid: session.sessionId,
        keyword: keyword,
      );
      if (body['success'] != true) return [];
      final songs =
          (body['data'] as Map<String, dynamic>?)?['songs'] as List<dynamic>? ??
              [];
      return songs
          .whereType<Map<String, dynamic>>()
          .map((map) {
            final song = SongItem.fromMap(map);
            final coverUrl = api.buildSongCoverUrl(
              sid: session.sessionId,
              songId: song.id,
            );
            return song.copyWith(coverUrl: coverUrl);
          })
          .toList();
    } on SessionExpiredException {
      rethrow;
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 搜索栏
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: '搜索歌曲/歌手/专辑',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 16,
                        ),
                        filled: true,
                        fillColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.5),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/home');
                      }
                    },
                    child: const Text('取消'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // 搜索结果
            Expanded(
              child: _searchController.text.trim().isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.music_note_rounded,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            '搜索你的音乐库',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : FutureBuilder<List<SongItem>>(
                      future: _search(_searchController.text.trim()),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          if (snapshot.error is SessionExpiredException) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (context.mounted) {
                                context.go(LoginPage.routePath);
                              }
                            });
                          }
                          return Center(child: Text('搜索失败：${snapshot.error}'));
                        }
                        final songs = snapshot.data ?? [];
                        if (songs.isEmpty) {
                          return const Center(child: Text('未找到相关歌曲'));
                        }
                        return ListView.separated(
                          itemCount: songs.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final song = songs[index];
                            return ListTile(
                              leading: song.coverUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: CachedNetworkImage(
                                        imageUrl: song.coverUrl!,
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                        placeholder: (_, _) => Container(
                                          width: 44,
                                          height: 44,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          child: const Icon(Icons.music_note, size: 20),
                                        ),
                                        errorWidget: (_, _, _) => Container(
                                          width: 44,
                                          height: 44,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          child: const Icon(Icons.music_note, size: 20),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: 44,
                                      height: 44,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      child: const Icon(Icons.music_note, size: 20),
                                    ),
                              title: Text(song.title),
                              subtitle: Text('${song.artist} . ${song.album}'),
                              onTap: () async {
                                await ref
                                    .read(playerControllerProvider.notifier)
                                    .setPlayQueue(songs, startIndex: index);
                                if (context.mounted) {
                                  context.go(PlayerPage.routePath);
                                }
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
