import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/library/playlist.dart';
import '../../models/library/song_item.dart';
import '../../syno/syno_providers.dart';
import '../player/player_page.dart';
import 'nas_artist_albums_page.dart';
import 'nas_config_page.dart';
import 'nas_providers.dart';
import 'nas_widgets.dart';

/// NAS 音乐库页面
///
/// Tab 切换：专辑 / 歌手 / 收藏 / 歌单。
class NasLibraryPage extends ConsumerStatefulWidget {
  const NasLibraryPage({super.key});

  static const routeName = 'nas_library';
  static const routePath = '/nas/library';

  @override
  ConsumerState<NasLibraryPage> createState() => _NasLibraryPageState();
}

class _NasLibraryPageState extends ConsumerState<NasLibraryPage> {
  @override
  void initState() {
    super.initState();
    // 未连接时自动引导到配置页
    Future<void>(() async {
      final repo = ref.read(synoMusicRepositoryProvider);
      if (repo.isConnected) return;
      try {
        await repo.connect().timeout(const Duration(seconds: 15));
      } catch (_) {
        // 未登录或会话失效，引导到配置页
      }
      if (!mounted || !context.mounted) return;
      if (!repo.isConnected) {
        context.go(NasConfigPage.routePath);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('NAS 音乐库'),
          actions: [
            IconButton(
              icon: const Icon(Icons.search_rounded),
              tooltip: '搜索',
              onPressed: () => context.push(NasSearchPage.routePath),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: '专辑'),
              Tab(text: '歌手'),
              Tab(text: '收藏'),
              Tab(text: '歌单'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AlbumsTab(),
            _ArtistsTab(),
            _FavoritesTab(),
            _PlaylistsTab(),
          ],
        ),
      ),
    );
  }
}

class _AlbumsTab extends ConsumerWidget {
  const _AlbumsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(nasAlbumsProvider);
    return albums.when(
      data: (items) => ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final album = items[index];
          return ListTile(
            leading: nasCoverBox(
              url: album.coverUrl,
              icon: Icons.album,
            ),
            title: Text(album.title),
            subtitle: Text('${album.artist} · ${album.songCount} 首'),
            onTap: () async {
              final repo = ref.read(synoMusicRepositoryProvider);
              final songs = await repo.fetchAlbumSongs(album);
                  if (songs.isEmpty) return;
              await playNasQueue(ref, songs);
              if (context.mounted) {
                context.go(PlayerPage.routePath);
              }
            },
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败：$e')),
    );
  }
}

class _ArtistsTab extends ConsumerWidget {
  const _ArtistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artists = ref.watch(nasArtistsProvider);
    return artists.when(
      data: (items) => ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final artist = items[index];
          return ListTile(
            leading: artist.coverUrl != null
                ? CircleAvatar(
                    backgroundImage: NetworkImage(artist.coverUrl!),
                  )
                : const CircleAvatar(child: Icon(Icons.person)),
            title: Text(artist.name),
            subtitle: Text('${artist.songCount} 首 · ${artist.albumCount} 张专辑'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(
              NasArtistAlbumsPage.routePath,
              extra: artist.name,
            ),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败：$e')),
    );
  }
}

class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(nasFavoritesProvider);
    return favorites.when(
      data: (items) => ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final song = items[index];
          return ListTile(
            leading: nasCoverBox(
              url: song.coverUrl,
              icon: Icons.music_note,
            ),
            title: Text(song.title),
            subtitle: Text('${song.artist} · ${song.album}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                NasAddToPlaylistButton(song: song.toSongItem()),
                NasFavoriteButton(song: song.toSongItem()),
              ],
            ),
            onTap: () async {
              final queue = items.map((f) => f.toSongItem()).toList();
              await playNasQueue(ref, queue, startIndex: index);
              if (context.mounted) {
                context.go(PlayerPage.routePath);
              }
            },
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败：$e')),
    );
  }
}

class _PlaylistsTab extends ConsumerWidget {
  const _PlaylistsTab();

  Future<void> _createPlaylist(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('新建歌单'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '歌单名称',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(nameController.text.trim()),
              child: const Text('创建'),
            ),
          ],
        );
      },
    );
    nameController.dispose();

    if (name == null || name.isEmpty) return;
    try {
      final repo = ref.read(synoMusicRepositoryProvider);
      await repo.createPlaylist(name);
      ref.invalidate(nasPlaylistsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败：$e')),
        );
      }
    }
  }

  Future<void> _deletePlaylist(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('删除歌单'),
          content: Text('确定删除歌单「${playlist.name}」吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    try {
      final repo = ref.read(synoMusicRepositoryProvider);
      await repo.deletePlaylist(playlist.id);
      ref.invalidate(nasPlaylistsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(nasPlaylistsProvider);
    return playlists.when(
      data: (items) => Stack(
        children: [
          ListView.builder(
            itemCount: items.length,
            padding: const EdgeInsets.only(bottom: 80),
            itemBuilder: (context, index) {
              final playlist = items[index];
              return ListTile(
                leading: const Icon(Icons.queue_music),
                title: Text(playlist.name),
                subtitle: Text('${playlist.songCount} 首'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '删除歌单',
                  onPressed: () =>
                      _deletePlaylist(context, ref, playlist),
                ),
                onTap: () => context.push(
                  NasPlaylistDetailPage.routePath,
                  extra: playlist,
                ),
              );
            },
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.small(
              heroTag: 'nas_create_playlist',
              onPressed: () => _createPlaylist(context, ref),
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败：$e')),
    );
  }
}

/// NAS 歌单详情页
class NasPlaylistDetailPage extends ConsumerWidget {
  const NasPlaylistDetailPage({super.key, required this.playlist});

  static const routeName = 'nas_playlist_detail';
  static const routePath = '/nas/playlist';

  final Playlist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(nasPlaylistSongsProvider(playlist.id));
    return Scaffold(
      appBar: AppBar(title: Text(playlist.name)),
      body: songs.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('歌单为空'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final song = items[index];
              return ListTile(
                leading: nasCoverBox(
                  url: song.coverUrl,
                  icon: Icons.music_note,
                ),
                title: Text(song.title),
                subtitle: Text('${song.artist} · ${song.album}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NasAddToPlaylistButton(song: song),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      tooltip: '从歌单移除',
                      onPressed: () async {
                        try {
                          final repo = ref.read(synoMusicRepositoryProvider);
                          await repo.removeSongFromPlaylist(
                            playlist.id,
                            song.id,
                          );
                          ref.invalidate(nasPlaylistSongsProvider(playlist.id));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已从歌单移除')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('移除失败：$e')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
                onTap: () async {
                  await playNasQueue(ref, items, startIndex: index);
                  if (context.mounted) {
                    context.go(PlayerPage.routePath);
                  }
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
      ),
    );
  }
}

/// NAS 搜索页
class NasSearchPage extends ConsumerStatefulWidget {
  const NasSearchPage({super.key});

  static const routeName = 'nas_search';
  static const routePath = '/nas/search';

  @override
  ConsumerState<NasSearchPage> createState() => _NasSearchPageState();
}

class _NasSearchPageState extends ConsumerState<NasSearchPage> {
  final _searchController = TextEditingController();
  List<SongItem>? _results;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String keyword) async {
    final query = keyword.trim();
    if (query.isEmpty) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(synoMusicRepositoryProvider);
      final results = await repo.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: '搜索歌曲',
            border: InputBorder.none,
          ),
          onSubmitted: _search,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _results == null
                  ? const Center(child: Text('输入关键词搜索 NAS 音乐'))
                  : _results!.isEmpty
                      ? const Center(child: Text('未找到相关歌曲'))
                      : ListView.builder(
                          itemCount: _results!.length,
                          itemBuilder: (context, index) {
                            final song = _results![index];
                            return ListTile(
                              leading: nasCoverBox(
                                url: song.coverUrl,
                                icon: Icons.music_note,
                              ),
                              title: Text(song.title),
                              subtitle: Text(
                                '${song.artist} · ${song.album}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  NasAddToPlaylistButton(song: song),
                                  NasFavoriteButton(song: song),
                                ],
                              ),
                              onTap: () async {
                                await playNasQueue(
                                  ref,
                                  _results!,
                                  startIndex: index,
                                );
                                if (context.mounted) {
                                  context.go(PlayerPage.routePath);
                                }
                              },
                            );
                          },
                        ),
    );
  }
}
