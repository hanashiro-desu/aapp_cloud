import 'package:flutter/material.dart';
import '../models/trash_model.dart';
import '../views/trash.dart';

class TrashScreen extends StatefulWidget {
  final String profileId;
  const TrashScreen({super.key, required this.profileId});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  final TrashManager _trashManager = TrashManager();
  List<Trash> _trashItems = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTrash();
  }

  Future<void> _loadTrash() async {
    final data = await _trashManager.fetchAllTrash(profileId: widget.profileId);
    setState(() {
      _trashItems = [...data['files'], ...data['folders']];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🗑️ Thùng rác")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _trashItems.isEmpty
          ? const Center(child: Text("Không có mục nào trong thùng rác"))
          : ListView.builder(
        itemCount: _trashItems.length,
        itemBuilder: (_, i) => ListTile(
          leading: Icon(
              _trashItems[i].type == 'file' ? Icons.insert_drive_file : Icons.folder),
          title: Text(_trashItems[i].originalPath),
          subtitle: Text(
              "Đã xóa: ${_trashItems[i].deletedAt?.toLocal().toString() ?? 'Không rõ'}"),
        ),
      ),
    );
  }
}
