import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/sidebar_menu.dart';
import '../widgets/file_tile.dart';
import '../widgets/folder_tile.dart';
import '../models/file_model.dart';
import '../models/folder_model.dart';
import '../services/file_service.dart';
import '../services/folder_service.dart';
import '../views/move.dart';
import '../views/preview_screen.dart';
import '../widgets/search_widgets.dart';
import '../widgets/trash_widgets.dart';
import '../services/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  final String profileId;

  const HomeScreen({super.key, required this.profileId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FileService _fileService = FileService();
  final FolderService _folderService = FolderService();

  bool _isLoading = false;
  List<FolderModel> _folders = [];
  List<FileModel> _files = [];
  String? _currentFolderId;
  String _currentFolderPath = '';

  @override
  void initState() {
    super.initState();
    SyncService().syncAllRecursive(widget.profileId);
    _loadData();
  }

  Future<void> _loadData({String? folderId, String? folderPath, String? filterType}) async {
    setState(() => _isLoading = true);
    try {
      List<FolderModel> folders = [];
      List<FileModel> files = [];

      if (filterType == null || filterType == 'dashboard') {
        folders = await _folderService.fetchFolders(
          parentId: folderId,
          profileId: widget.profileId,
        );
        files = await _fileService.fetchFiles(
          folderId: folderId,
          profileId: widget.profileId,
        ).then((list) => list.where((f) => f.name != '.keep').toList());
      } else {
        final allFiles = await _fetchAllFilesRecursive(folderId: folderId);
        switch (filterType) {
          case 'all':
            files = allFiles;
            folders = [];
            break;
          case 'documents':
            files = allFiles.where((f) => f.type == 'document').toList();
            folders = [];
            break;
          case 'images':
            files = allFiles.where((f) => f.type == 'image').toList();
            folders = [];
            break;
          case 'videos':
            files = allFiles.where((f) => f.type == 'video').toList();
            folders = [];
            break;
        }
      }

      setState(() {
        _folders = folders;
        _files = files;
        _currentFolderId = folderId;
        if (folderPath != null) _currentFolderPath = folderPath;
      });
    } catch (e) {
      print('❌ Lỗi loadData: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<List<FileModel>> _fetchAllFilesRecursive({String? folderId}) async {
    List<FileModel> allFiles = [];
    final files = await _fileService.fetchFiles(
      folderId: folderId,
      profileId: widget.profileId,
    );
    allFiles.addAll(files.where((f) => f.name != '.keep'));

    final folders = await _folderService.fetchFolders(
      parentId: folderId,
      profileId: widget.profileId,
    );
    for (var folder in folders) {
      final childFiles = await _fetchAllFilesRecursive(folderId: folder.id);
      allFiles.addAll(childFiles);
    }
    return allFiles;
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;

    final file = File(result.files.single.path!);
    final ok = await _fileService.uploadFile(
      file: file,
      folderId: _currentFolderId,
      profileId: widget.profileId,
    );

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Upload thành công')),
      );
      _loadData(folderId: _currentFolderId);
    }
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tạo thư mục mới'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Tên thư mục')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Tạo')),
        ],
      ),
    );

    if (ok != true) return;
    final folderName = controller.text.trim();
    if (folderName.isEmpty) return;

    final success = await _folderService.createFolder(
      name: folderName,
      profileId: widget.profileId,
      parentId: _currentFolderId,
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Tạo thư mục "$folderName" thành công')),
      );
      _loadData(folderId: _currentFolderId);
    }
  }

  void _onSidebarSelect(String type, {String? query}) {
    Navigator.pop(context);
    if (type == 'search') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SearchScreen(profileId: widget.profileId),
        ),
      );
    } else if (type == 'trash') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TrashScreen(profileId: widget.profileId),
        ),
      );
    } else if (type == 'logout') {
      _confirmSignOut();
    } else {
      _loadData(folderId: _currentFolderId, filterType: type);
    }
  }


  Future<void> _signOut() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Lỗi đăng xuất: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _signOut();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📁 Quản lý File'),
        actions: [
          if (_currentFolderId != null)
            IconButton(icon: const Icon(Icons.home), onPressed: () => _loadData(folderId: null)),
          IconButton(icon: const Icon(Icons.create_new_folder), onPressed: _createFolder),
          IconButton(icon: const Icon(Icons.upload_file), onPressed: _uploadFile),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _loadData(folderId: _currentFolderId)),
        ],
      ),
      drawer: SidebarMenu(onSelect: _onSidebarSelect, onTrash: () => _onSidebarSelect('trash')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_folders.isEmpty && _files.isEmpty)
          ? const Center(child: Text('Không có dữ liệu'))
          : Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.05,
          children: [
            ..._folders.map((folder) => FolderTile(
                folder: folder,
                onOpen: () => _loadData(folderId: folder.id, folderPath: folder.name))),
            ..._files.map((file) => FileTile(file: file, onTap: () {}, onAction: (action) {})),
          ],
        ),
      ),
    );
  }
}
