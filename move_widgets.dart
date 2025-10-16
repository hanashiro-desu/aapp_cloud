import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/folder_model.dart';
import '../services/profile_service.dart';
import '../models/MoveTarget.dart';
import '../views/move.dart';

class MoveFolderList extends StatefulWidget {
  final String itemId;
  final bool isFile;
  final String? excludeId;

  const MoveFolderList({
    super.key,
    required this.itemId,
    required this.isFile,
    this.excludeId,
  });

  @override
  State<MoveFolderList> createState() => _MoveFolderListState();
}

class _MoveFolderListState extends State<MoveFolderList> {
  List<Profile> _users = [];
  Profile? _selectedUser;
  List<FolderModel> _folders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    _users = await ProfileService().getAllProfiles();
    setState(() => _isLoading = false);
  }

  Future<void> _loadFoldersForUser(Profile user) async {
    setState(() => _isLoading = true);

    // ⚠️ Sử dụng userId làm profileId
    final profileId = user.userId ?? '';
    if (profileId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    _folders = await MoveLogic.fetchMovableFolders(
      excludeId: widget.excludeId,
      profileId: profileId,
    );

    setState(() => _isLoading = false);
  }

  Future<void> _moveItem(FolderModel? folder) async {
    if (_selectedUser == null || _selectedUser!.userId == null) return;

    setState(() => _isLoading = true);

    final success = await MoveLogic.moveItem(
      isFile: widget.isFile,
      itemId: widget.itemId,
      target: MoveTarget(
        user: _selectedUser!,
        folder: folder,
      ),
    );

    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Di chuyển thành công')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Di chuyển thất bại')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn người nhận & thư mục đích')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButton<Profile>(
              hint: const Text('Chọn người nhận'),
              value: _selectedUser,
              isExpanded: true,
              items: _users.map((u) {
                return DropdownMenuItem(
                  value: u,
                  child: Text(u.fullName ?? u.email ?? 'Unknown'),
                );
              }).toList(),
              onChanged: (user) {
                if (user == null) return;
                setState(() {
                  _selectedUser = user;
                  _folders = [];
                });
                _loadFoldersForUser(user);
              },
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.home),
                  title: const Text('Thư mục gốc'),
                  onTap: () => _moveItem(null),
                ),
                ..._folders.map((f) => ListTile(
                  leading: const Icon(Icons.folder),
                  title: Text(f.name),
                  subtitle: Text('👤 ${f.profileId ?? "Không rõ"}'),
                  onTap: () => _moveItem(f),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
