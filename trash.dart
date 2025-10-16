import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trash_model.dart';
import '../models/file_model.dart';
import '../models/folder_model.dart';
import '../services/trash_service.dart';

class TrashManager {
  final TrashService _trashService = TrashService();
  final SupabaseClient _client = Supabase.instance.client;

  Future<Map<String, dynamic>> fetchAllTrash({required String profileId}) async {
    final trashList = await _trashService.fetchAllTrash(profileId: profileId);
    final files = trashList.where((t) => t.type == 'file').toList();
    final folders = trashList.where((t) => t.type == 'folder').toList();
    return {'files': files, 'folders': folders};
  }

  Future<bool> moveToTrashFile(FileModel file, String trashPath, String profileId) async {
    return await _trashService.moveToTrash(
      type: 'file',
      originalId: file.id,
      originalPath: file.path!,
      trashPath: trashPath,
      profileId: profileId,
    );
  }

  Future<bool> restoreFile(Trash trash) async {
    return await _trashService.restoreTrash(trash);
  }

  Future<bool> deleteFilePermanently(Trash trash) async {
    return await _trashService.deletePermanently(trash);
  }
}
