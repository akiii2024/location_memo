import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:location_memo/utils/offline_mode_provider.dart';
import '../models/map_info.dart';
import '../utils/database_helper.dart';
import '../utils/firebase_map_service.dart';
import 'add_map_screen.dart';
import 'auth_screen.dart';
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

  Future<bool> _ensureLoggedIn() async {
    if (FirebaseAuth.instance.currentUser != null) {
      return true;
    }
    if (!mounted) {
      return false;
    }
    final offlineModeProvider = context.read<OfflineModeProvider>();
    if (offlineModeProvider.isOfflineMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('オフラインモードでは利用できません。設定からオンラインモードに切り替えてください'),
        ),
      );
      return false;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('オンライン機能を利用するにはログインしてください'),
      ),
    );
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
    return FirebaseAuth.instance.currentUser != null;
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
    if (!await _ensureLoggedIn()) {
      return;
    }
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
    if (!await _ensureLoggedIn()) {
      return;
    }
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

  Future<void> _showShareDialog(MapInfo mapInfo) async {
    if (mapInfo.id == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('共有する前に地図を保存してください。'),
        ),
      );
      return;
    }
    if (!await _ensureLoggedIn()) {
      return;
    }
    final emailController = TextEditingController();
    var isLoading = true;
    var isMutating = false;
    List<FirebaseSharedUser> sharedUsers = const [];
    String? loadError;
    Future<void> loadSharedUsers() async {
      try {
        final users =
            await FirebaseMapService.instance.fetchSharedUsers(mapInfo.id!);
        sharedUsers = users;
        loadError = null;
      } catch (error) {
        loadError = '共有情報の取得に失敗しました: $error';
      }
      isLoading = false;
    }

    await loadSharedUsers();
    if (!mounted) {
      emailController.dispose();
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            Future<void> refreshSharedUsers() async {
              setState(() {
                isLoading = true;
              });
              await loadSharedUsers();
              if (mounted) {
                setState(() {
                  isLoading = false;
                });
              }
            }

            Future<void> handleShare() async {
              final email = emailController.text.trim();
              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('共有する相手のメールアドレスを入力してください。'),
                  ),
                );
                return;
              }
              setState(() {
                isMutating = true;
              });
              final result =
                  await FirebaseMapService.instance.shareMapWithEmail(
                mapId: mapInfo.id!,
                email: email,
              );
              if (!mounted) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(result.message)),
              );
              if (result.success) {
                emailController.clear();
                await refreshSharedUsers();
              }
              if (mounted) {
                setState(() {
                  isMutating = false;
                });
              }
            }

            Future<void> handleRevoke(String uid) async {
              setState(() {
                isMutating = true;
              });
              final result = await FirebaseMapService.instance
                  .revokeSharedUser(mapId: mapInfo.id!, uid: uid);
              if (!mounted) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(result.message)),
              );
              if (result.success) {
                await refreshSharedUsers();
              }
              if (mounted) {
                setState(() {
                  isMutating = false;
                });
              }
            }

            return AlertDialog(
              title: Text('共有設定 (${mapInfo.title})'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'メールアドレス',
                        hintText: 'example@example.com',
                      ),
                      enabled: !isMutating,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: isMutating ? null : handleShare,
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('共有ユーザーを追加'),
                    ),
                    const SizedBox(height: 16),
                    if (isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (loadError != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            loadError!,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () async {
                                await refreshSharedUsers();
                              },
                              child: const Text('再試行'),
                            ),
                          ),
                        ],
                      )
                    else
                      SizedBox(
                        height: 220,
                        child: sharedUsers.isEmpty
                            ? const Center(
                                child: Text('共有中のユーザーはいません。'),
                              )
                            : ListView.builder(
                                itemCount: sharedUsers.length,
                                itemBuilder: (context, index) {
                                  final user = sharedUsers[index];
                                  return ListTile(
                                    leading: const Icon(Icons.person_outline),
                                    title: Text(user.email),
                                    subtitle: user.displayName != null &&
                                            user.displayName!.isNotEmpty
                                        ? Text(user.displayName!)
                                        : null,
                                    trailing: IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: isMutating
                                          ? null
                                          : () async {
                                              await handleRevoke(user.uid);
                                            },
                                      tooltip: '共有を解除',
                                    ),
                                  );
                                },
                              ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('閉じる'),
                ),
              ],
            );
          },
        );
      },
    );
    emailController.dispose();
  }

  Future<void> _showRemoteMapsDialog() async {
    if (!await _ensureLoggedIn()) {
      return;
    }
    if (!mounted) {
      return;
    }
    var future = FirebaseMapService.instance.fetchRemoteMaps();
    String? activeKey;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: const Text('オンライン地図'),
              content: SizedBox(
                width: 420,
                child: FutureBuilder<List<FirebaseRemoteMapSummary>>(
                  future: future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '地図の取得に失敗しました: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                future = FirebaseMapService.instance
                                    .fetchRemoteMaps();
                              });
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('再試行'),
                          ),
                        ],
                      );
                    }
                    final summaries =
                        snapshot.data ?? const <FirebaseRemoteMapSummary>[];
                    if (summaries.isEmpty) {
                      return const SizedBox(
                        height: 200,
                        child: Center(
                          child: Text('オンラインに保存された地図はありません。'),
                        ),
                      );
                    }
                    return SizedBox(
                      height: 320,
                      child: ListView.builder(
                        itemCount: summaries.length,
                        itemBuilder: (context, index) {
                          final summary = summaries[index];
                          final ownerLabel = summary.isShared
                              ? '共有元: ${summary.ownerEmail ?? summary.ownerId}'
                              : '所有者: ${summary.ownerEmail ?? '自分'}';
                          final updatedLabel =
                              '最終更新: ${_formatDateTime(summary.updatedAt)}';
                          final memoLabel = 'メモ数: ${summary.memoCount}';
                          final key =
                              '${summary.ownerId}_${summary.mapId}_${summary.isShared}';
                          final isProcessing = activeKey == key;
                          final buttonLabel =
                              summary.isShared ? 'インポート' : 'ダウンロード';
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              title: Text(summary.title),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(ownerLabel),
                                  Text(memoLabel),
                                  Text(updatedLabel),
                                ],
                              ),
                              trailing: TextButton(
                                onPressed: isProcessing
                                    ? null
                                    : () async {
                                        setState(() {
                                          activeKey = key;
                                        });
                                        await _handleRemoteDownload(
                                          summary,
                                          asImport: summary.isShared,
                                        );
                                        if (mounted) {
                                          setState(() {
                                            activeKey = null;
                                          });
                                        }
                                      },
                                child: isProcessing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : Text(buttonLabel),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      future = FirebaseMapService.instance.fetchRemoteMaps();
                    });
                  },
                  child: const Text('再読み込み'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('閉じる'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleRemoteDownload(
    FirebaseRemoteMapSummary summary, {
    required bool asImport,
  }) async {
    try {
      final result = await FirebaseMapService.instance.downloadMap(
        summary.mapId,
        ownerUid: summary.ownerId,
        importAsCopy: asImport,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      if (result.success) {
        await _loadMaps();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ダウンロードに失敗しました: $error')),
      );
    }
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '不明';
    }
    final local = value.toLocal();
    String twoDigits(int v) => v.toString().padLeft(2, '0');
    final date =
        '${local.year}/${twoDigits(local.month)}/${twoDigits(local.day)}';
    final time = '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
    return '$date $time';
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
                leading: const Icon(Icons.share),
                title: const Text('共有設定'),
                enabled: mapInfo.id != null,
                onTap: () async {
                  Navigator.pop(context);
                  await _showShareDialog(mapInfo);
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
            icon: const Icon(Icons.cloud),
            tooltip: 'オンライン地図',
            onPressed: _showRemoteMapsDialog,
          ),
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
