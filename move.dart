import '../models/folder_model.dart';
import '../models/user_model.dart';
import '../models/MoveTarget.dart';
import '../services/folder_service.dart';
import '../services/file_service.dart';
import '../services/storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MoveLogic {
  static final FolderService _folderService = FolderService();
  static final FileService _fileService = FileService();
  static final StorageService _storageService = StorageService();
  static final SupabaseClient _client = Supabase.instance.client;

  /// 🔹 Lấy tất cả folder có thể move (loại trừ folder excludeId)
  static Future<List<FolderModel>> fetchMovableFolders({
    String? excludeId,
    required String profileId,
  }) async {
    final roots =
    await _folderService.fetchFolders(parentId: null, profileId: profileId);

    List<FolderModel> allFolders = [];

    Future<void> _collectFolders(List<FolderModel> folders) async {
      for (var f in folders) {
        if (f.id != excludeId) allFolders.add(f);
        final children =
        await _folderService.fetchFolders(parentId: f.id, profileId: profileId);
        if (children.isNotEmpty) {
          await _collectFolders(children);
        }
      }
    }

    await _collectFolders(roots);
    return allFolders;
  }

  /// 🔹 Di chuyển file hoặc folder
  static Future<bool> moveItem({
    required bool isFile,
    required String itemId,
    required MoveTarget target, // chứa user + folder đích
  }) async {
    final profileId = target.user.userId ?? '';
    final folderId = target.folder?.id;
    final targetFolder = target.folder;

    if (profileId.isEmpty) {
      print('⚠️ Move failed: profileId trống');
      return false;
    }

    try {
      if (isFile) {
        // ------------------ FILE ------------------
        return await _fileService.moveFile(
          fileId: itemId,
          folderId: folderId,
        );
      } else {
        // ------------------ FOLDER ------------------
        // Lấy thông tin folder cần move
        final allFolders =
        await _folderService.fetchFolders(profileId: profileId);
        final folderToMove = allFolders.firstWhere(
              (f) => f.id == itemId,
          orElse: () => FolderModel(
            id: '',
            name: '',
            profileId: profileId,
            path: '',
          ),
        );

        if (folderToMove.id.isEmpty) {
          print('⚠️ Không tìm thấy folder cần move.');
          return false;
        }

        // Tính đường dẫn mới
        final newPath = targetFolder != null
            ? '${targetFolder.path}/${folderToMove.name}'
            : '$profileId/${folderToMove.name}';

        print('📦 Move folder từ "${folderToMove.path}" → "$newPath"');

        // Di chuyển trên Storage
        await _storageService.moveItem(folderToMove.path ?? '', newPath);

        // Cập nhật lại DB
        await _client
            .from('folders')
            .update({
          'parent_id': folderId,
          'path': newPath,
          'updated_at': DateTime.now().toIso8601String(),
        })
            .eq('id', itemId);

        print('✅ Move thành công folder: ${folderToMove.name}');
        return true;
      }
    } catch (e) {
      print('⚠️ MoveLogic moveItem error: $e');
      return false;
    }
  }
}
