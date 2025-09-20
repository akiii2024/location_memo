import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import '../models/map_info.dart';
import '../utils/database_helper.dart';
import '../utils/firebase_map_service.dart';
import 'add_map_screen.dart';
import 'map_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<MapInfo> _maps = [];
  bool _isLoading = true;
  int? _syncingMapId;

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
      setState(() {
        _maps = maps;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('地図の読み込みに失敗しました: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _openMap(MapInfo mapInfo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(mapInfo: mapInfo),
      ),
    ).then((_) {
      _loadMaps(); // 地図画面から戻ったら再読み込み
    });
  }

  void _addNewMap() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddMapScreen()),
    );
    if (result == true) {
      _loadMaps(); // 新しい地図が追加されたら再読み込み
    }
  }

  Future<void> _deleteMap(MapInfo mapInfo) async {
    // 削除確認ダイアログを表示
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('地図を削除'),
          content: Text('「${mapInfo.title}」を削除しますか？\n\nこの地図に関連するメモもすべて削除されます。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('削除'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await DatabaseHelper.instance.deleteMap(mapInfo.id!);

        // 地図ファイルも削除
        if (mapInfo.imagePath != null) {
          final file = File(mapInfo.imagePath!);
          if (await file.exists()) {
            await file.delete();
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「${mapInfo.title}」を削除しました')),
        );

        _loadMaps(); // 地図リストを再読み込み
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('地図の削除に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _uploadMapOnline(MapInfo mapInfo) async {
    if (mapInfo.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Save the map locally before uploading to Firebase.'),
        ),
      );
      return;
    }

    if (_syncingMapId == mapInfo.id) {
      return;
    }

    setState(() {
      _syncingMapId = mapInfo.id;
    });

    var dialogShown = false;

    try {
      if (mounted) {
        dialogShown = true;
        showDialog<Widget>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      final result = await FirebaseMapService.instance.uploadMap(mapInfo);

      if (!mounted) {
        return;
      }

      if (dialogShown) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogShown = false;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.success
                ? 'Firebaseに地図を保存しました'
                : 'Firebaseへの保存に失敗しました: ${result.message}',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        if (dialogShown) {
          Navigator.of(context, rootNavigator: true).pop();
          dialogShown = false;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Firebaseアップロード中にエラーが発生しました: $error'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _syncingMapId = null;
        });
      }
    }
  }

  Future<void> _downloadMapOnline(MapInfo mapInfo) async {
    if (mapInfo.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Save the map locally before downloading it from Firebase.'),
        ),
      );
      return;
    }

    if (_syncingMapId == mapInfo.id) {
      return;
    }

    setState(() {
      _syncingMapId = mapInfo.id;
    });

    var dialogShown = false;

    try {
      if (mounted) {
        dialogShown = true;
        showDialog<Widget>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      final result = await FirebaseMapService.instance.downloadMap(mapInfo.id!);

      if (!mounted) {
        return;
      }

      if (dialogShown) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogShown = false;
      }

      if (result.success) {
        await _loadMaps();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    } catch (error) {
      if (mounted) {
        if (dialogShown) {
          Navigator.of(context, rootNavigator: true).pop();
          dialogShown = false;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download map from Firebase: $error'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _syncingMapId = null;
        });
      }
    }
  }

  Future<void> _renameMap(MapInfo mapInfo) async {
    final TextEditingController controller =
        TextEditingController(text: mapInfo.title);

    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('地図の名称を変更'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: '地図の名称',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                Navigator.of(context).pop(value.trim());
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                final newTitle = controller.text.trim();
                if (newTitle.isNotEmpty) {
                  Navigator.of(context).pop(newTitle);
                }
              },
              child: const Text('変更'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty && result != mapInfo.title) {
      try {
        final updatedMap = MapInfo(
          id: mapInfo.id,
          title: result,
          imagePath: mapInfo.imagePath,
        );

        await DatabaseHelper.instance.updateMap(updatedMap);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('地図の名称を「$result」に変更しました')),
        );

        _loadMaps(); // 地図リストを再読み込み
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('地図の名称変更に失敗しました: $e')),
        );
      }
    }
  }

  void _showMapOptions(MapInfo mapInfo) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.map),
                title: const Text('地図を開く'),
                onTap: () {
                  Navigator.pop(context);
                  _openMap(mapInfo);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cloud_upload),
                title: Text(_syncingMapId == mapInfo.id
                    ? 'Syncing with Firebase...'
                    : 'Upload to Firebase'),
                enabled: _syncingMapId != mapInfo.id && mapInfo.id != null,
                onTap: () async {
                  Navigator.pop(context);
                  await _uploadMapOnline(mapInfo);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cloud_download),
                title: Text(_syncingMapId == mapInfo.id
                    ? 'Syncing with Firebase...'
                    : 'Download from Firebase'),
                enabled: _syncingMapId != mapInfo.id && mapInfo.id != null,
                onTap: () async {
                  Navigator.pop(context);
                  await _downloadMapOnline(mapInfo);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('名称を変更'),
                onTap: () async {
                  Navigator.pop(context);
                  await _renameMap(mapInfo);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('地図を削除', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  await _deleteMap(mapInfo);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('フィールドワーク記録'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新しい地図を追加',
            onPressed: _addNewMap,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _maps.isEmpty
              ? _buildEmptyState()
              : _buildMapsList(),
      floatingActionButton: _maps.isNotEmpty
          ? FloatingActionButton(
              onPressed: _addNewMap,
              child: const Icon(Icons.add),
              tooltip: '新しい地図を追加',
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'カスタム地図でフィールドワーク記録を作成',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            '地図画像をアップロードして記録を開始してください',
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
            onLongPress: () => _showMapOptions(map),
            borderRadius: BorderRadius.circular(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (map.imagePath != null)
                  Container(
                    width: double.infinity,
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
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
              child: Icon(
                Icons.broken_image,
                size: 48,
                color: Colors.grey,
              ),
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
              child: Icon(
                Icons.broken_image,
                size: 48,
                color: Colors.grey,
              ),
            ),
          );
        },
      );
    }
  }
}
