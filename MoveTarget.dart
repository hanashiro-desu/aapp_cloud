import '../models/folder_model.dart';
import '../models/user_model.dart';

class MoveTarget {
  final Profile user;           // User nhận
  final FolderModel? folder;    // Folder đích, null = root

  MoveTarget({
    required this.user,
    this.folder,
  });
}
