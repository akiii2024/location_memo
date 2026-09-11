import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/map_info.dart';
import '../utils/database_helper.dart';
import '../utils/collaboration_sync_coordinator.dart';
import '../utils/firebase_map_service.dart';
import '../utils/firebase_availability.dart';
import '../utils/image_helper.dart';
import '../utils/theme_provider.dart';
import '../utils/sync_queue.dart';
import 'add_map_screen.dart';
import 'auth_screen.dart';
import 'map_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<MapInfo> _maps = [];
  bool _isLoading = true;
  int? _syncingMapId;
  String? _loadError;
  final Map<int, int> _memoCounts = {};
  final Map<int, SyncStatus> _syncStatuses = {};
  @override
  void initState() {
    super.initState();
    _loadMaps();
  }

  Future<void> _loadMaps() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final maps = await DatabaseHelper.instance.readAllMaps();
      final counts = <int, int>{};
      final statuses = <int, SyncStatus>{};
      await Future.wait(
        maps.where((map) => map.id != null).map((map) async {
          counts[map.id!] = (await DatabaseHelper.instance.readMemosByMapId(
            map.id,
          )).length;
          statuses[map.id!] = await CollaborationSyncCoordinator.instance
              .statusForMap(map.id!);
        }),
      );
      if (!mounted) return;
      setState(() {
        _maps = maps;
        _memoCounts
          ..clear()
          ..addAll(counts);
        _syncStatuses
          ..clear()
          ..addAll(statuses);
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = '地図を読み込めませんでした。';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _ensureLoggedIn() async {
    if (!FirebaseAvailability.isReady) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('クラウドへ接続できません。時間をおいて再試行してください。')),
        );
      }
      return false;
    }
    if (FirebaseAuth.instance.currentUser != null) {
      return true;
    }
    if (!mounted) {
      return false;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('オンライン機能を利用するにはログインしてください')));
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
    return FirebaseAvailability.isReady &&
        FirebaseAuth.instance.currentUser != null;
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
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('削除'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      try {
        await DatabaseHelper.instance.deleteMap(mapInfo.id!);
        await CollaborationSyncCoordinator.instance.unregisterCollaborativeMap(
          mapInfo.id!,
        );
        if (mapInfo.imagePath != null) {
          await ImageHelper.deleteImage(mapInfo.imagePath!);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('「${mapInfo.title}」を削除しました')));
        _loadMaps(); // 地図リストを再読み込み
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('地図を削除できませんでした。再試行してください。')),
        );
      }
    }
  }

  Future<void> _uploadMapOnline(MapInfo mapInfo) async {
    if (!await _ensureLoggedIn()) {
      return;
    }
    if (!mounted) return;
    if (mapInfo.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('クラウドへ保存する前に地図を端末へ保存してください。')),
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
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
      }
      final result = await FirebaseMapService.instance.uploadMap(mapInfo);
      if (!mounted) {
        return;
      }
      if (result.success) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await CollaborationSyncCoordinator.instance.registerCollaborativeMap(
            mapId: mapInfo.id!,
            ownerUid: user.uid,
            isOwner: true,
            ownerEmail: user.email,
            remoteMapId: result.remoteMapId,
          );
        }
      }
      if (!mounted) return;
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
    } catch (_) {
      if (mounted) {
        if (dialogShown) {
          Navigator.of(context, rootNavigator: true).pop();
          dialogShown = false;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('クラウドへ保存できませんでした。通信状況を確認してください。')),
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
    if (!mounted) return;
    if (mapInfo.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('クラウドから取得する前に地図を端末へ保存してください。')),
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
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
      }
      final metadata = await CollaborationSyncCoordinator.instance.getMetadata(
        mapInfo.id!,
      );
      final result = await FirebaseMapService.instance.downloadMap(
        mapInfo.id!,
        remoteMapId: metadata?.remoteMapId,
      );
      if (!mounted) {
        return;
      }
      if (dialogShown) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogShown = false;
      }
      if (result.success) {
        await _loadMaps();
        final currentUser = FirebaseAuth.instance.currentUser;
        final localMapId = result.localMapId ?? mapInfo.id;
        if (currentUser != null && localMapId != null) {
          await CollaborationSyncCoordinator.instance.registerCollaborativeMap(
            mapId: localMapId,
            ownerUid: metadata?.ownerUid ?? currentUser.uid,
            isOwner: metadata?.isOwner ?? true,
            ownerEmail: metadata?.ownerEmail ?? currentUser.email,
            remoteMapId: metadata?.remoteMapId,
          );
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } catch (_) {
      if (mounted) {
        if (dialogShown) {
          Navigator.of(context, rootNavigator: true).pop();
          dialogShown = false;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('クラウドから取得できませんでした。通信状況を確認してください。')),
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
    final TextEditingController controller = TextEditingController(
      text: mapInfo.title,
    );
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
        final updatedMap = mapInfo.copyWith(title: result);
        await DatabaseHelper.instance.updateMap(updatedMap);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('地図の名称を「$result」に変更しました')));
        _loadMaps(); // 地図リストを再読み込み
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('地図の名称を変更できませんでした。')));
      }
    }
  }

  Future<void> _showShareDialog(MapInfo mapInfo) async {
    if (mapInfo.id == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('共有する前に地図を保存してください。')));
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
        final users = await FirebaseMapService.instance.fetchSharedUsers(
          mapInfo.id!,
        );
        sharedUsers = users;
        loadError = null;
      } catch (_) {
        loadError = '共有情報を取得できませんでした。通信状況を確認して再試行してください。';
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
                  const SnackBar(content: Text('共有する相手のメールアドレスを入力してください。')),
                );
                return;
              }
              setState(() {
                isMutating = true;
              });
              final result = await FirebaseMapService.instance
                  .shareMapWithEmail(mapId: mapInfo.id!, email: email);
              if (!mounted) {
                return;
              }
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(result.message)));
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
              final result = await FirebaseMapService.instance.revokeSharedUser(
                mapId: mapInfo.id!,
                uid: uid,
              );
              if (!mounted) {
                return;
              }
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(result.message)));
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
                height: 400,
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
                    Expanded(
                      child: Column(
                        children: [
                          if (isLoading)
                            const Expanded(
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (loadError != null)
                            Expanded(
                              child: Column(
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
                              ),
                            )
                          else
                            Expanded(
                              child: sharedUsers.isEmpty
                                  ? const Center(child: Text('共有中のユーザーはいません。'))
                                  : ListView.builder(
                                      itemCount: sharedUsers.length,
                                      itemBuilder: (context, index) {
                                        final user = sharedUsers[index];
                                        return ListTile(
                                          leading: const Icon(
                                            Icons.person_outline,
                                          ),
                                          title: Text(user.email),
                                          subtitle:
                                              user.displayName != null &&
                                                  user.displayName!.isNotEmpty
                                              ? Text(user.displayName!)
                                              : null,
                                          trailing: IconButton(
                                            icon: const Icon(Icons.close),
                                            onPressed: isMutating
                                                ? null
                                                : () async {
                                                    await handleRevoke(
                                                      user.uid,
                                                    );
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
    if (mounted) {
      emailController.dispose();
    }
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
                            '地図を取得できませんでした。通信状況を確認して再試行してください。',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
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
                        child: Center(child: Text('オンラインに保存された地図はありません。')),
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
                          final buttonLabel = summary.isShared ? '追加' : '同期';
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
                                        await _handleRemoteDownload(summary);
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
                                          strokeWidth: 2,
                                        ),
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

  Future<void> _handleRemoteDownload(FirebaseRemoteMapSummary summary) async {
    try {
      final result = await FirebaseMapService.instance.downloadMap(
        summary.mapId,
        ownerUid: summary.ownerId,
        remoteMapId: summary.remoteMapId,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      if (result.success) {
        await _loadMaps();
        final localMapId = result.localMapId;
        if (localMapId != null) {
          final currentUser = FirebaseAuth.instance.currentUser;
          final isOwner = currentUser?.uid == summary.ownerId;
          await CollaborationSyncCoordinator.instance.registerCollaborativeMap(
            mapId: localMapId,
            ownerUid: summary.ownerId,
            isOwner: isOwner,
            ownerEmail: summary.ownerEmail,
            remoteMapId: summary.remoteMapId,
          );
        }
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ダウンロードに失敗しました。再試行してください。')));
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
                title: Text(_syncingMapId == mapInfo.id ? '同期中…' : 'クラウドへ保存'),
                enabled: _syncingMapId != mapInfo.id && mapInfo.id != null,
                onTap: () async {
                  Navigator.pop(context);
                  await _uploadMapOnline(mapInfo);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cloud_download),
                title: Text(_syncingMapId == mapInfo.id ? '同期中…' : 'クラウドから取得'),
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
        title: const Text('位置メモ'),
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
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? _buildLoadError()
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'カスタム地図で記録を作成',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '地図画像を追加して、\n記録を始めましょう。',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _addNewMap,
              icon: const Icon(Icons.add),
              label: const Text('最初の地図を追加'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(_loadError!, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: _loadMaps,
              icon: const Icon(Icons.refresh),
              label: const Text('再試行'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapsList() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 3
            : constraints.maxWidth >= 680
            ? 2
            : 1;
        return GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: columns == 1 ? 1.65 : 1.35,
          ),
          itemCount: _maps.length,
          itemBuilder: (context, index) => _buildMapCard(_maps[index]),
        );
      },
    );
  }

  Widget _buildMapCard(MapInfo map) {
    final theme = Theme.of(context);
    final count = map.id == null ? 0 : (_memoCounts[map.id!] ?? 0);
    final isSyncing = _syncingMapId == map.id;
    final syncStatus = map.id == null
        ? SyncStatus.synced
        : (_syncStatuses[map.id!] ?? SyncStatus.synced);
    final statusLabel = switch (syncStatus) {
      SyncStatus.pending => '同期保留',
      SyncStatus.syncing => '同期中',
      SyncStatus.failed => '同期失敗・再試行待ち',
      SyncStatus.synced => null,
    };
    return Card(
      child: Semantics(
        button: true,
        label: '${map.title}、メモ$count件',
        child: InkWell(
          onTap: () => _openMap(map),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (map.imagePath != null)
                Expanded(
                  child: SizedBox(
                    width: double.infinity,
                    child: _buildImageWidget(map.imagePath!),
                  ),
                )
              else
                Expanded(
                  child: ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Center(
                      child: Icon(
                        Icons.map_outlined,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            map.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isSyncing
                                ? '同期中…'
                                : statusLabel == null
                                ? 'メモ $count件'
                                : 'メモ $count件・$statusLabel',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '${map.title}の操作メニュー',
                      onPressed: () => _showMapOptions(map),
                      icon: isSyncing
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.more_vert),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
