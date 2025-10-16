import 'package:flutter/material.dart';
import '../models/file_model.dart';
import '../views/search.dart';

class SearchScreen extends StatefulWidget {
  final String profileId;
  const SearchScreen({super.key, required this.profileId});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final SearchManager _search = SearchManager();
  List<FileModel> _results = [];
  final _controller = TextEditingController();

  Future<void> _doSearch() async {
    final text = _controller.text.trim();
    final files = await _search.searchFiles(profileId: widget.profileId, nameQuery: text);
    setState(() => _results = files);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🔍 Tìm kiếm File")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: "Nhập tên file...",
              suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _doSearch),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _results.isEmpty
                ? const Center(child: Text("Không tìm thấy file nào"))
                : ListView.builder(
              itemCount: _results.length,
              itemBuilder: (_, i) => ListTile(
                title: Text(_results[i].name),
                subtitle: Text(_results[i].type ?? 'unknown'),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
