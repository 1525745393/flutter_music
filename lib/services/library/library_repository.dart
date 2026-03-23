import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../synology_api.dart';
import '../auth/auth_repository.dart';
import '../../models/library/song_item.dart';

class LibraryException implements Exception {
  const LibraryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LibraryRepository {
  LibraryRepository(this._authRepository);

  final AuthRepository _authRepository;

  Future<List<SongItem>> fetchSongs({int limit = 100}) async {
    final session = await _authRepository.loadSession();
    if (session == null) {
      throw const LibraryException('会话不存在，请先登录');
    }

    final api = SynologyAudioStationApi(serverUrl: session.serverUrl);
    try {
      final body = await api.listSongs(sid: session.sessionId, limit: limit);

      if (body['success'] != true) {
        final code = (body['error'] as Map<String, dynamic>?)?['code'] as int?;
        throw LibraryException('音乐库请求失败：错误码 ${code ?? 'unknown'}');
      }

      final songs =
          (body['data'] as Map<String, dynamic>?)?['songs'] as List<dynamic>? ??
          [];
      return songs
          .whereType<Map<String, dynamic>>()
          .map(SongItem.fromMap)
          .toList(growable: false);
    } on DioException catch (e) {
      throw LibraryException('网络异常：${e.message}');
    } on SynologyApiException catch (e) {
      throw LibraryException('音乐库请求失败：${e.message}');
    }
  }
}

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return LibraryRepository(ref.read(authRepositoryProvider));
});
