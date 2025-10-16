import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trash_model.dart';

class TrashService {
  final SupabaseClient _client = Supabase.instance.client;
  final String _trashTable = 'trash';

  /// 🗑️ Move file/folder to trash
  Future<bool> moveToTrash({
    required String type,
    required String originalId,
    required String originalPath,
    required String trashPath,
    required String profileId, // 🔥 bắt buộc
  }) async {
    try {
      await _client.from(_trashTable).insert({
        'type': type,
        'original_id': originalId,
        'original_path': originalPath,
        'trash_path': trashPath,
        'deleted_at': DateTime.now().toIso8601String(),
        'restored': false,
        'profile_id': profileId,
      });

      final table = (type == 'file') ? 'files' : 'folders';
      await _client.from(table).update({
        'is_deleted': true,
        'deleted_at': DateTime.now().toIso8601String(),
      }).eq('id', originalId);

      // Move storage nếu là file
      if (type == 'file') {
        await _client.storage.from('files').move(originalPath, trashPath);
      }

      return true;
    } catch (e) {
      print('❌ [TrashService.moveToTrash] Lỗi: $e');
      return false;
    }
  }

  /// 📋 Fetch all trash for a profile
  Future<List<Trash>> fetchAllTrash({required String profileId}) async {
    try {
      final response = await _client
          .from(_trashTable)
          .select('*')
          .eq('restored', false)
          .eq('profile_id', profileId)
          .order('deleted_at', ascending: false);

      final List<dynamic> data = response;
      return data.map((row) => Trash.fromMap(row as Map<String, dynamic>)).toList();
    } catch (e) {
      print('❌ [TrashService.fetchAllTrash] Lỗi: $e');
      return [];
    }
  }

  /// ♻️ Restore from trash
  Future<bool> restoreTrash(Trash trash) async {
    try {
      final table = trash.type == 'file' ? 'files' : 'folders';
      await _client.from(table).update({'is_deleted': false, 'deleted_at': null}).eq('id', trash.originalId);
      await _client.from(_trashTable).delete().eq('id', trash.id);

      if (trash.type == 'file') {
        await _client.storage.from('files').move(trash.trashPath, trash.originalPath);
      }
      return true;
    } catch (e) {
      print('❌ [TrashService.restoreTrash] Lỗi: $e');
      return false;
    }
  }

  /// ❌ Delete permanently
  Future<bool> deletePermanently(Trash trash) async {
    try {
      if (trash.type == 'file') {
        await _client.storage.from('files').remove([trash.trashPath]);
      }
      await _client.from(_trashTable).delete().eq('id', trash.id);
      if (trash.type == 'folder') {
        await _client.from('folders').delete().eq('id', trash.originalId);
      }
      return true;
    } catch (e) {
      print('❌ [TrashService.deletePermanently] Lỗi: $e');
      return false;
    }
  }
}
