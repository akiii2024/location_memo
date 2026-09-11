import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import '../models/map_info.dart';
import '../utils/database_helper.dart';
import '../utils/collaboration_sync_coordinator.dart';
import 'add_map_screen.dart';
import 'map_screen.dart';

class MapListScreen extends StatefulWidget {
  const MapListScreen({super.key});

  @override
  State<MapListScreen> createState() => _MapListScreenState();
}

class _MapListScreenState extends State<MapListScreen> {
  List<MapInfo> _maps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMaps();
  }

  Future<void> _loadMaps() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final maps = await DatabaseHelper.instance.readAllMaps();
      if (!mounted) return;
      setState(() {
        _maps = maps;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('地図を読み込めませんでした。再試行してください。')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openMap(MapInfo mapInfo) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MapScreen(mapInfo: mapInfo)),
    ).then((_) {
      _loadMaps(); // 地図画面から戻ったら再読み込み
    });
  }

  void _addNewMap() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddMapScreen()),
    );
    if (!mounted) return;
    if (result == true) {
      _loadMaps(); // 新しい地図が追加されたら再読み込み
    }
  }

  Future<void> _deleteMap(MapInfo mapInfo) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('地図を削除'),
          content: Text('「${mapInfo.title}」を削除しますか？\nこの地図に関連する記録も削除されます。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('削除'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await DatabaseHelper.instance.deleteMap(mapInfo.id!);
      await CollaborationSyncCoordinator.instance.unregisterCollaborativeMap(
        mapInfo.id!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('地図を削除しました'),
          backgroundColor: Colors.green,
        ),
      );

      _loadMaps(); // リストを再読み込み
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('地図を削除できませんでした。再試行してください。'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('カスタム地図管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新しい地図を追加',
            onPressed: _addNewMap,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _maps.isEmpty
          ? _buildEmptyState()
          : _buildMapsList(),
      floatingActionButton: _maps.isNotEmpty
          ? FloatingActionButton(
              onPressed: _addNewMap,
              tooltip: '新しい地図を追加',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.map_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'カスタム地図がありません',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            '新しい地図を追加してフィールドワークを開始しましょう',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addNewMap,
            icon: const Icon(Icons.add),
            label: const Text('最初の地図を追加'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _maps.length,
      itemBuilder: (context, index) {
        final map = _maps[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          child: InkWell(
            onTap: () => _openMap(map),
            borderRadius: BorderRadius.circular(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (map.imagePath != null)
                  Container(
                    width: double.infinity,
                    height: 150,
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(8.0),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8.0),
                      ),
                      child: _buildImageWidget(map.imagePath!),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              map.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'タップして地図を開く',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteMap(map),
                        tooltip: '地図を削除',
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageWidget(String imagePath) {
    if (kIsWeb && imagePath.startsWith('data:image')) {
      // Web環境でBase64データの場合
      final base64Data = imagePath.split(',')[1];
      final bytes = base64Decode(base64Data);
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade200,
            child: const Center(
              child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
            ),
          );
        },
      );
    } else {
      // モバイル/デスクトップ環境またはWebでファイルパスの場合
      return Image.file(
        File(imagePath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade200,
            child: const Center(
              child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
            ),
          );
        },
      );
    }
  }
}
