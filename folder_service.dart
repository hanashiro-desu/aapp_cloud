import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/folder_model.dart';
import 'storage_service.dart';

class FolderService {
  final SupabaseClient _client = Supabase.instance.client;
  final StorageService _storageService = StorageService();
  final String tableName = 'folders';

  Future<List<FolderModel>> fetchFolders({
    required String profileId,
    String? parentId,
  }) async {
    final response = await _client
        .from(tableName)
        .select()
        .eq('profile_id', profileId)
        .maybeFilter('parent_id', parentId);

    return (response as List).map((e) => FolderModel.fromMap(e)).toList();
  }

  Future<bool> createFolder({
    required String name,
    required String profileId,
    String? parentId,
  }) async {
    try {
      final path = parentId != null ? '$parentId/$name' : '$profileId/$name';
      await _client.from(tableName).insert({
        'name': name,
        'profile_id': profileId,
        'parent_id': parentId,
        'path': path,
      });
      return true;
    } catch (e) {
      print('❌ createFolder error: $e');
      return false;
    }
  }
}

extension _QueryMaybeFilter on PostgrestFilterBuilder {
  PostgrestFilterBuilder maybeFilter(String column, String? value) {
    if (value == null) return this;
    return eq(column, value);
  }
}
