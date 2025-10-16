import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/file_model.dart';
import '../models/folder_model.dart';
import 'file_service.dart';
import 'folder_service.dart';
import 'storage_service.dart';

class SyncService {
  final SupabaseClient _client = Supabase.instance.client;
  final FolderService _folderService = FolderService();
  final FileService _fileService = FileService();
  final StorageService _storageService = StorageService();

  /// 🔹 Đồng bộ toàn bộ Storage ↔ Database (2 chiều)
  Future<void> syncAllRecursive(String profileId) async {
    try {
      print('🚀 Bắt đầu đồng bộ dữ liệu cho profileId: $profileId');

      // 🔸 Lấy danh sách từ DB
      final folders =
      await _folderService.fetchFolders(parentId: null, profileId: profileId);
      final files = await _fileService.fetchFiles(profileId: profileId);

      // 🔹 DB → Storage
      for (final folder in folders) {
        final path = folder.path ?? '';
        if (!await _storageService.folderExists(path)) {
          await _storageService.createFolder(path);
          print('📁 Tạo folder mới trong Storage: $path');
        }
      }

      for (final file in files) {
        final path = file.path ?? '';
        if (!await _storageService.fileExists(path) && file.content != null) {
          await _storageService.uploadBytes(file.content!, path);
          print('📄 Upload file mới vào Storage: $path');
        }
      }

      // 🔹 Storage → DB
      await _syncStorageToDatabase(profileId);
      print('✅ Đồng bộ hoàn tất cho profileId: $profileId');
    } catch (e) {
      print('⚠️ syncAllRecursive error: $e');
    }
  }

  /// 🔹 Đệ quy đồng bộ từ Storage → Database
  Future<void> _syncStorageToDatabase(
      String profileId, {
        String? parentPath,
        String? parentId,
      }) async {
    final path = parentPath ?? profileId;

    try {
      // 🧩 Lấy danh sách file + folder từ Storage
      final items = await _storageService.listFiles(path: path);

      for (final item in items) {
        final isFolder = item['isFolder'] == true;
        final itemPath = item['path'];
        final itemName = item['name'];

        if (isFolder) {
          // 🔸 Kiểm tra folder trong DB
          final existingFolders =
          await _folderService.fetchFolders(parentId: parentId, profileId: profileId);

          if (!existingFolders.any((f) => f.path == itemPath)) {
            await _client.from('folders').insert({
              'name': itemName,
              'path': itemPath,
              'profile_id': profileId,
              'parent_id': parentId,
              'created_at': DateTime.now().toIso8601String(),
            });
            print('📁 Synced folder từ Storage → DB: $itemPath');
          }

          // 🔁 Đệ quy sync các mục con
          await _syncStorageToDatabase(
            profileId,
            parentPath: itemPath,
            parentId: parentId,
          );
        } else {
          // 🔸 Kiểm tra file trong DB
          final existingFiles = await _fileService.fetchFiles(profileId: profileId);
          if (!existingFiles.any((f) => f.path == itemPath)) {
            await _client.from('files').insert({
              'name': itemName,
              'path': itemPath,
              'profile_id': profileId,
              'created_at': DateTime.now().toIso8601String(),
            });
            print('📄 Synced file từ Storage → DB: $itemPath');
          }
        }
      }
    } catch (e) {
      print('⚠️ _syncStorageToDatabase error tại $path: $e');
    }
  }
}
