import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../models/memo.dart';
import '../models/map_info.dart';
import '../utils/database_helper.dart';
import '../utils/firebase_map_service.dart';
import '../utils/collaboration_metadata_store.dart';
import '../utils/collaboration_sync_coordinator.dart';
import '../utils/print_helper.dart';
import '../utils/ai_service.dart';
import '../widgets/custom_map_widget.dart';
import 'memo_detail_screen.dart';
import 'memo_list_screen.dart';
import 'add_memo_screen.dart';
import 'map_share_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MapScreen extends StatefulWidget {
  final MapInfo? mapInfo;

  const MapScreen({Key? key, this.mapInfo}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<Memo> _memos = [];
  String? _customMapPath;
  int _currentLayer = 0; // 現在選択されているレイヤー
  List<int> _layers = [0]; // 利用可能なレイヤー一覧
  final GlobalKey<CustomMapWidgetState> _mapWidgetKey =
      GlobalKey<CustomMapWidgetState>();
  bool _isOCRProcessing = false; // OCR処理中フラグ
  bool _isUploading = false;
  bool _isDownloading = false;
  Box? _layerNameBox; // レイヤー名ボックス
  CollaborationMetadata? _collaborationMetadata;
  StreamSubscription<List<Memo>>? _collaborationSubscription;
  bool _isCollaborationConnecting = false;
  String? _collaborationError;

  String _layerDisplayName(int layer) {
    if (_layerNameBox == null) {
      return 'レイヤー${layer + 1}';
    }
    final key = _layerKey(layer);
    final saved = _layerNameBox!.get(key);
    return saved ?? 'レイヤー${layer + 1}';
  }

  String _layerKey(int layer) {
    final mapIdPart =
        widget.mapInfo?.id?.toString() ?? (_customMapPath ?? 'custom');
    return '${mapIdPart}_$layer';
  }

  Future<void> _renameCurrentLayer() async {
    final controller =
        TextEditingController(text: _layerDisplayName(_currentLayer));
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('レイヤー名を変更'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: '新しいレイヤー名'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      if (_layerNameBox != null) {
        await _layerNameBox!.put(_layerKey(_currentLayer), newName);
      }
      setState(() {});
    }
  }

  Future<void> _uploadMapToFirebase() async {
    if (_isUploading || _isDownloading) {
      return;
    }

    MapInfo? targetMap = widget.mapInfo;
    if (targetMap == null) {
      int? mapId;
      if (_customMapPath != null) {
        mapId = await DatabaseHelper.instance.getOrCreateMapId(
          _customMapPath,
          widget.mapInfo?.title ?? 'カスタム地図',
        );
      }
      if (mapId != null) {
        try {
          final maps = await DatabaseHelper.instance.readAllMaps();
          targetMap = maps.firstWhere((map) => map.id == mapId);
        } catch (_) {
          targetMap = MapInfo(
            id: mapId,
            title: widget.mapInfo?.title ?? 'カスタム地図',
            imagePath: _customMapPath,
          );
        }
      }
    }

    if (targetMap == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Firebaseに保存できる地図が見つかりませんでした'),
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
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

      final result = await FirebaseMapService.instance.uploadMap(targetMap);

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
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _downloadMapFromFirebase() async {
    if (_isDownloading || _isUploading) {
      return;
    }

    MapInfo? targetMap = widget.mapInfo;
    int? currentMapId = targetMap?.id;
    const fallbackTitle = 'Custom Map';

    if (currentMapId == null) {
      if (_customMapPath != null) {
        currentMapId = await DatabaseHelper.instance.getOrCreateMapId(
          _customMapPath,
          widget.mapInfo?.title ?? fallbackTitle,
        );
      }
    }

    if (currentMapId == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Save the map locally before downloading it from Firebase.'),
        ),
      );
      return;
    }

    setState(() {
      _isDownloading = true;
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

      final result =
          await FirebaseMapService.instance.downloadMap(currentMapId);

      if (!mounted) {
        return;
      }

      if (dialogShown) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogShown = false;
      }

      if (result.success) {
        await _loadMemos();
        final maps = await DatabaseHelper.instance.readAllMaps();
        MapInfo? updatedMap;
        for (final map in maps) {
          if (map.id == currentMapId) {
            updatedMap = map;
            break;
          }
        }
        if (updatedMap != null) {
          setState(() {
            _customMapPath = updatedMap!.imagePath ?? _customMapPath;
          });
        }
        if (await CollaborationSyncCoordinator.instance
            .isCollaborative(currentMapId)) {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            await CollaborationSyncCoordinator.instance
                .registerCollaborativeMap(
              mapId: currentMapId,
              ownerUid: currentUser.uid,
              isOwner: true,
              ownerEmail: currentUser.email,
            );
          }
        }
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
          _isDownloading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMemos();
    _loadCustomMapPath();

    // レイヤー名保存用のBoxを初期化
    Hive.openBox('layer_names').then((box) {
      setState(() {
        _layerNameBox = box;
      });
    });

    // MapInfoに画像パスがある場合はカスタム地図を使用
    if (widget.mapInfo?.imagePath != null) {
      _customMapPath = widget.mapInfo!.imagePath;
    }

    unawaited(_setupCollaboration());
  }

  Future<void> _loadCustomMapPath() async {
    try {
      if (kIsWeb) {
        // Web版: Hiveから画像データを読み込み
        final box = await Hive.openBox('app_settings');
        final savedMapData = box.get('custom_map_image');
        if (savedMapData != null) {
          setState(() {
            _customMapPath = savedMapData; // Base64文字列
          });
        }
      } else {
        // モバイル版: ファイルシステムから読み込み
        final directory = await getApplicationDocumentsDirectory();
        final mapFile = File('${directory.path}/custom_map.png');
        if (await mapFile.exists()) {
          setState(() {
            _customMapPath = mapFile.path;
          });
        }
      }
    } catch (e) {
      print('地図ファイルの読み込み中にエラーが発生しました: $e');
    }
  }

  Future<void> _setupCollaboration() async {
    final mapId = widget.mapInfo?.id;
    if (mapId == null) {
      if (_collaborationMetadata != null || _collaborationError != null) {
        setState(() {
          _collaborationMetadata = null;
          _collaborationError = null;
        });
      }
      return;
    }
    try {
      final metadata =
          await CollaborationMetadataStore.instance.getForMap(mapId);
      if (!mounted) {
        return;
      }
      if (metadata == null) {
        setState(() {
          _collaborationMetadata = null;
          _collaborationError = null;
        });
        await _stopCollaborationListener();
        return;
      }
      await _startCollaborationListener(mapId, metadata);
    } catch (error, stackTrace) {
      debugPrint('Failed to load collaboration metadata: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _startCollaborationListener(
    int mapId,
    CollaborationMetadata metadata,
  ) async {
    await _collaborationSubscription?.cancel();
    setState(() {
      _collaborationMetadata = metadata;
      _isCollaborationConnecting = true;
      _collaborationError = null;
    });
    try {
      _collaborationSubscription = FirebaseMapService.instance
          .subscribeToMapMemos(mapId: mapId, ownerUid: metadata.ownerUid)
          .listen(
        (remoteMemos) {
          unawaited(DatabaseHelper.instance
              .replaceMemosForMap(mapId, List<Memo>.from(remoteMemos)));
          if (!mounted) {
            return;
          }
          setState(() {
            _collaborationError = null;
          });
          unawaited(_loadMemos());
        },
        onError: (error, stackTrace) {
          debugPrint('Collaboration stream error: $error');
          debugPrintStack(stackTrace: stackTrace);
          if (!mounted) {
            return;
          }
          setState(() {
            _collaborationError = 'リアルタイム同期でエラーが発生しました';
          });
        },
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to start collaboration listener: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      setState(() {
        _collaborationError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCollaborationConnecting = false;
        });
      }
    }
  }

  Future<void> _stopCollaborationListener() async {
    await _collaborationSubscription?.cancel();
    _collaborationSubscription = null;
  }

  Future<void> _enableCollaboration() async {
    if (_isCollaborationConnecting) {
      return;
    }
    final mapInfo = widget.mapInfo;
    if (mapInfo?.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Firebaseにアップロードする前に地図を保存してください')),
      );
      return;
    }
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('共同編集を利用するにはログインが必要です')),
      );
      return;
    }
    setState(() {
      _isCollaborationConnecting = true;
    });
    try {
      final result = await FirebaseMapService.instance.uploadMap(mapInfo!);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      if (!result.success) {
        return;
      }
      await CollaborationSyncCoordinator.instance.registerCollaborativeMap(
        mapId: mapInfo.id!,
        ownerUid: currentUser.uid,
        isOwner: true,
        ownerEmail: currentUser.email,
      );
      await _setupCollaboration();
    } catch (error, stackTrace) {
      debugPrint('Failed to enable collaboration: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('共同編集の有効化に失敗しました: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCollaborationConnecting = false;
        });
      }
    }
  }

  Future<void> _disableCollaboration() async {
    final mapId = widget.mapInfo?.id;
    if (mapId == null) {
      return;
    }
    await _stopCollaborationListener();
    await CollaborationSyncCoordinator.instance
        .unregisterCollaborativeMap(mapId);
    if (!mounted) {
      return;
    }
    setState(() {
      _collaborationMetadata = null;
      _collaborationError = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('共同編集を無効にしました')),
    );
    unawaited(_loadMemos());
  }

  Future<void> _showShareLinkScreen() async {
    final mapInfo = widget.mapInfo;
    if (mapInfo?.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('地図が保存されていません')),
      );
      return;
    }
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('共有するにはログインが必要です')),
      );
      return;
    }
    if (!mounted) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapShareScreen(
          mapInfo: mapInfo!,
          ownerUid: currentUser.uid,
        ),
      ),
    );
  }

  Widget _buildCollaborationBanner(BuildContext context) {
    final metadata = _collaborationMetadata;
    if (metadata == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final hasError = _collaborationError != null;
    final backgroundColor = theme.colorScheme.surfaceVariant.withOpacity(
      theme.brightness == Brightness.dark ? 0.6 : 0.4,
    );
    final statusText = _collaborationError ??
        (metadata.isOwner ? '共同編集を有効化（所有者）' : '共同編集に参加中');
    final iconData = hasError ? Icons.error_outline : Icons.groups;
    return Container(
      width: double.infinity,
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            iconData,
            color:
                hasError ? theme.colorScheme.error : theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              style: theme.textTheme.bodySmall,
            ),
          ),
          if (_isCollaborationConnecting)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Future<void> _loadMemos() async {
    List<Memo> memos;

    if (widget.mapInfo != null) {
      // MapInfoがある場合は、そのIDでメモを読み込む
      memos =
          await DatabaseHelper.instance.readMemosByMapId(widget.mapInfo!.id);
    } else {
      // MapInfoがない場合は、地図画像パスでメモを読み込む
      memos = await DatabaseHelper.instance.readMemosByMapPath(_customMapPath);
    }

    // レイヤー一覧を更新
    final layerSet = memos.map((m) => m.layer ?? 0).toSet();
    if (!layerSet.contains(0)) layerSet.add(0);

    setState(() {
      _memos = memos;
      _layers = layerSet.toList()..sort();
      if (!_layers.contains(_currentLayer)) {
        _currentLayer = _layers.first;
      }
    });
  }

  void _onMapTap(double x, double y) async {
    // 現在の地図IDを取得
    int? currentMapId;
    if (widget.mapInfo != null) {
      currentMapId = widget.mapInfo!.id;
    } else {
      // MapInfoがない場合は、地図画像パスから地図IDを取得または作成
      currentMapId = await DatabaseHelper.instance.getOrCreateMapId(
        _customMapPath,
        'カスタム地図',
      );
    }

    // カスタム地図の場合、相対座標を緯度経度として使用
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMemoScreen(
          initialLatitude: x,
          initialLongitude: y,
          mapId: currentMapId,
          layer: _currentLayer,
        ),
      ),
    );
    if (result == true) {
      _loadMemos();
    }
  }

  void _onMemoTap(Memo memo) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MemoDetailScreen(memo: memo),
      ),
    );
    if (result == true) {
      _loadMemos();
    }
  }

  // 複数地点記録OCR機能
  Future<void> _performMultipleRecordsOCR() async {
    final ImagePicker picker = ImagePicker();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📄 複数地点記録を読み取り（開発中）'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('複数の観察地点が記録された紙を写真に撮って\n一括で地図に追加します。'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'この機能は開発中です。認識精度や機能が変更される可能性があります。',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('カメラで撮影'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 85,
                );
                if (image != null) {
                  await _processMultipleRecordsOCRImage(image);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text('ギャラリーから選択'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                );
                if (image != null) {
                  await _processMultipleRecordsOCRImage(image);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );
  }

  // 複数地点OCR画像処理
  Future<void> _processMultipleRecordsOCRImage(XFile imageFile) async {
    setState(() {
      _isOCRProcessing = true;
    });

    try {
      print('Map Debug: 複数地点OCR処理開始');
      print('Map Debug: 画像パス: ${imageFile.path}');

      // 画像をバイト配列として読み込み
      final imageBytes = await imageFile.readAsBytes();
      print('Map Debug: 画像サイズ: ${imageBytes.length} bytes');

      // 複数地点OCR処理を実行
      final result =
          await AIService.recognizeMultipleRecordsFromImage(imageBytes);
      print('Map Debug: 複数地点OCR結果: $result');

      if (result['success'] == true) {
        // OCR結果をダイアログで表示し、ユーザーに適用を確認
        await _showMultipleRecordsOCRResult(result);
      } else {
        throw Exception(result['error'] ?? '複数地点OCR処理に失敗しました');
      }
    } catch (e) {
      print('Map Debug: 複数地点OCR処理エラー詳細:');
      print('Map Debug: エラータイプ: ${e.runtimeType}');
      print('Map Debug: エラーメッセージ: $e');
      print('Map Debug: エラートレース: ${StackTrace.current}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('複数地点記録の読み取りに失敗しました'),
              if (kIsWeb) ...[
                const SizedBox(height: 4),
                Text(
                  'デバッグ: ${e.runtimeType}',
                  style: const TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'エラー: ${e.toString()}',
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _isOCRProcessing = false;
      });
    }
  }

  // 複数地点OCR結果表示・適用ダイアログ
  Future<void> _showMultipleRecordsOCRResult(
      Map<String, dynamic> result) async {
    final totalRecords = result['totalRecords'] ?? 0;
    final extractedText = result['extractedText'] ?? '';
    final records = result['records'] as List<dynamic>? ?? [];
    final confidence = result['confidence'] ?? 'medium';
    final notes = result['notes'] ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('📄 読み取り結果（${totalRecords}件の記録）'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (extractedText.isNotEmpty) ...[
                  const Text('📝 抽出されたテキスト:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(extractedText,
                        style: const TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text('📋 抽出された記録:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...records.asMap().entries.map((entry) {
                  final index = entry.key;
                  final record = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('記録 ${index + 1}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue)),
                        const SizedBox(height: 4),
                        if (record['title'] != null &&
                            record['title'].toString().isNotEmpty) ...[
                          Text('タイトル: ${record['title']}'),
                          const SizedBox(height: 2),
                        ],
                        if (record['content'] != null &&
                            record['content'].toString().isNotEmpty) ...[
                          Text('内容: ${record['content']}'),
                          const SizedBox(height: 2),
                        ],
                        if (record['location'] != null &&
                            record['location'].toString().isNotEmpty) ...[
                          Text('場所: ${record['location']}'),
                          const SizedBox(height: 2),
                        ],
                        if (record['latitude'] != null &&
                            record['longitude'] != null) ...[
                          Text(
                              '座標: ${record['latitude'].toStringAsFixed(6)}, ${record['longitude'].toStringAsFixed(6)}'),
                          const SizedBox(height: 2),
                        ],
                        if (record['category'] != null &&
                            record['category'].toString().isNotEmpty) ...[
                          Text('カテゴリ: ${record['category']}'),
                          const SizedBox(height: 2),
                        ],
                        Text(
                            '認識精度: ${_getConfidenceText(record['confidence'] ?? 'medium')}',
                            style: TextStyle(
                              color: _getConfidenceColor(
                                  record['confidence'] ?? 'medium'),
                              fontSize: 12,
                            )),
                      ],
                    ),
                  );
                }).toList(),
                if (notes.isNotEmpty) ...[
                  const Divider(),
                  const Text('備考:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(notes, style: const TextStyle(fontSize: 12)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _applyMultipleRecordsResult(records);
            },
            child: Text('地図に追加（${records.length}件）'),
          ),
        ],
      ),
    );
  }

  // 複数地点OCR結果を地図に適用
  Future<void> _applyMultipleRecordsResult(List<dynamic> records) async {
    int successCount = 0;
    int failureCount = 0;

    try {
      // 現在の地図IDを取得
      final currentMapId = widget.mapInfo?.id;
      if (currentMapId == null) {
        throw Exception('地図IDが取得できません');
      }

      for (final record in records) {
        try {
          // 同じレイヤーの既存メモを取得して次のピン番号を決定
          final existingMemos =
              await DatabaseHelper.instance.readMemosByMapId(currentMapId);
          final layerMemos = existingMemos
              .where((memo) => (memo.layer ?? 0) == _currentLayer)
              .toList();
          int nextPinNumber = 1;
          if (layerMemos.isNotEmpty) {
            final maxPinNumber = layerMemos
                .where((memo) => memo.pinNumber != null)
                .map((memo) => memo.pinNumber!)
                .fold(0, (max, number) => number > max ? number : max);
            nextPinNumber = maxPinNumber + 1;
          }

          // メモオブジェクトを作成
          final memo = Memo(
            title: record['title']?.toString()?.trim() ?? '読み取り記録',
            content: record['content']?.toString()?.trim() ?? '',
            latitude: record['latitude'],
            longitude: record['longitude'],
            discoveryTime: DateTime.now(), // 現在時刻をデフォルトとして使用
            discoverer: record['discoverer']?.toString()?.trim(),
            specimenNumber: record['specimenNumber']?.toString()?.trim(),
            category: record['category']?.toString()?.trim(),
            notes: record['notes']?.toString()?.trim(),
            pinNumber: nextPinNumber + successCount, // 順番にピン番号を割り当て
            mapId: currentMapId,
            layer: _currentLayer,
          );

          // データベースに保存
          final savedMemo = await DatabaseHelper.instance.create(memo);
          try {
            await CollaborationSyncCoordinator.instance
                .onLocalMemoCreated(savedMemo);
          } catch (error, stackTrace) {
            debugPrint('Failed to sync imported memo: $error');
            debugPrintStack(stackTrace: stackTrace);
          }
          successCount++;
        } catch (e) {
          print('Map Debug: 記録の保存に失敗: ${record['title']}, エラー: $e');
          failureCount++;
        }
      }

      // メモリストを再読み込み
      await _loadMemos();

      // 結果をユーザーに通知
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '複数地点記録を地図に追加しました\n成功: ${successCount}件, 失敗: ${failureCount}件'),
          backgroundColor: failureCount == 0 ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      print('Map Debug: 複数地点記録適用エラー: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('複数地点記録の適用に失敗しました: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // 認識精度のテキストを取得
  String _getConfidenceText(String confidence) {
    switch (confidence.toLowerCase()) {
      case 'high':
        return '高い';
      case 'medium':
        return '中程度';
      case 'low':
        return '低い';
      default:
        return '不明';
    }
  }

  // 認識精度の色を取得
  Color _getConfidenceColor(String confidence) {
    switch (confidence.toLowerCase()) {
      case 'high':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.mapInfo?.title ?? 'フィールドワーク記録'),
            Text(_layerDisplayName(_currentLayer),
                style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'レイヤー名を変更',
            onPressed: _renameCurrentLayer,
          ),
          // レイヤー選択ボタン
          PopupMenuButton<int>(
            icon: const Icon(Icons.layers),
            tooltip: 'レイヤー選択',
            onSelected: (value) {
              if (value == -1) {
                // 新しいレイヤーを追加
                final newLayer = (_layers.isNotEmpty ? _layers.last + 1 : 1);
                setState(() {
                  _layers.add(newLayer);
                  _currentLayer = newLayer;
                });
              } else {
                setState(() {
                  _currentLayer = value;
                });
              }
            },
            itemBuilder: (context) => [
              ..._layers.map(
                (layer) => PopupMenuItem<int>(
                  value: layer,
                  child: Text(_layerDisplayName(layer)),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<int>(
                value: -1,
                child: Row(
                  children: [
                    Icon(Icons.add),
                    SizedBox(width: 8),
                    Text('レイヤーを追加'),
                  ],
                ),
              ),
            ],
          ),
          // OCRボタン（複数地点記録読み取り）
          IconButton(
            icon: _isOCRProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.document_scanner, color: Colors.purple),
            tooltip: '複数地点記録を読み取り',
            onPressed: _isOCRProcessing ? null : _performMultipleRecordsOCR,
          ),
          // 印刷ボタン
          PopupMenuButton<String>(
            icon: const Icon(Icons.print),
            tooltip: '印刷',
            onSelected: (value) async {
              try {
                switch (value) {
                  case 'enable_collaboration':
                    await _enableCollaboration();
                    break;
                  case 'disable_collaboration':
                    await _disableCollaboration();
                    break;
                  case 'share_link':
                    await _showShareLinkScreen();
                    break;
                  case 'upload_map':
                    await _uploadMapToFirebase();
                    break;
                  case 'download_map':
                    await _downloadMapFromFirebase();
                    break;
                  case 'print_map':
                    await PrintHelper.printMapImage(
                      _customMapPath,
                      mapName: widget.mapInfo?.title ?? 'カスタム地図',
                    );
                    break;
                  case 'print_map_with_pins':
                    final mapState = _mapWidgetKey.currentState;
                    if (mapState != null) {
                      await PrintHelper.printMapWithPins(
                        mapState.mapImagePath,
                        _memos
                            .where((m) => (m.layer ?? 0) == _currentLayer)
                            .toList(),
                        mapState.actualDisplayWidth,
                        mapState.actualDisplayHeight,
                        mapName: widget.mapInfo?.title ?? 'カスタム地図',
                      );
                    } else {
                      // フォールバック: デフォルトサイズを使用
                      await PrintHelper.printMapWithPins(
                        _customMapPath,
                        _memos
                            .where((m) => (m.layer ?? 0) == _currentLayer)
                            .toList(),
                        800.0,
                        600.0,
                        mapName: widget.mapInfo?.title ?? 'カスタム地図',
                      );
                    }
                    break;
                  case 'print_list':
                    await PrintHelper.printMemoReport(
                      _memos
                          .where((m) => (m.layer ?? 0) == _currentLayer)
                          .toList(),
                      mapName: widget.mapInfo?.title ?? 'カスタム地図',
                    );
                    break;
                  case 'save_pdf':
                    await PrintHelper.savePdfReport(
                      _memos
                          .where((m) => (m.layer ?? 0) == _currentLayer)
                          .toList(),
                      mapImagePath: _customMapPath,
                      mapName: widget.mapInfo?.title ?? 'カスタム地図',
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('PDFファイルを保存しました')),
                    );
                    break;
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('印刷に失敗しました: $e')),
                );
              }
            },
            itemBuilder: (context) => [
              if (_collaborationMetadata == null)
                PopupMenuItem(
                  value: 'enable_collaboration',
                  enabled:
                      widget.mapInfo?.id != null && !_isCollaborationConnecting,
                  child: Row(
                    children: [
                      Icon(
                        Icons.groups,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      ),
                      const SizedBox(width: 8),
                      Text(_isCollaborationConnecting
                          ? '共同編集を準備中...'
                          : '共同編集を有効化'),
                    ],
                  ),
                )
              else
                PopupMenuItem(
                  value: 'disable_collaboration',
                  enabled: !_isCollaborationConnecting,
                  child: Row(
                    children: [
                      Icon(
                        Icons.group_off,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      ),
                      const SizedBox(width: 8),
                      const Text('共同編集を停止'),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'share_link',
                enabled: widget.mapInfo?.id != null,
                child: Row(
                  children: [
                    Icon(
                      Icons.qr_code,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    ),
                    const SizedBox(width: 8),
                    const Text('リンク・QRコードで共有'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'upload_map',
                enabled: !_isUploading && !_isDownloading,
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_upload,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    ),
                    const SizedBox(width: 8),
                    Text((_isUploading || _isDownloading)
                        ? 'Syncing with Firebase...'
                        : 'Upload to Firebase'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'download_map',
                enabled: !_isUploading && !_isDownloading,
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_download,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    ),
                    const SizedBox(width: 8),
                    Text((_isUploading || _isDownloading)
                        ? 'Syncing with Firebase...'
                        : 'Download from Firebase'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'print_map',
                child: Row(
                  children: [
                    Icon(
                      Icons.map,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    ),
                    const SizedBox(width: 8),
                    const Text('地図画像を印刷'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'print_map_with_pins',
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    ),
                    const SizedBox(width: 8),
                    const Text('ピン付き地図を印刷'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'print_list',
                child: Row(
                  children: [
                    Icon(
                      Icons.list,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    ),
                    const SizedBox(width: 8),
                    const Text('記録一覧を印刷'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'save_pdf',
                child: Row(
                  children: [
                    Icon(
                      Icons.save,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    ),
                    const SizedBox(width: 8),
                    const Text('PDFで保存'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.format_list_bulleted),
            tooltip: '記録一覧',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MemoListScreen(
                    memos: _memos
                        .where((m) => (m.layer ?? 0) == _currentLayer)
                        .toList(),
                    mapTitle: widget.mapInfo?.title ?? 'カスタム地図',
                  ),
                ),
              );
              _loadMemos();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_collaborationMetadata != null)
            _buildCollaborationBanner(context),
          Expanded(
            child: CustomMapWidget(
              key: _mapWidgetKey,
              memos:
                  _memos.where((m) => (m.layer ?? 0) == _currentLayer).toList(),
              onTap: _onMapTap,
              onMemoTap: _onMemoTap,
              customImagePath: _customMapPath,
              onMemosUpdated: _loadMemos, // メモ更新時のコールバックを追加
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // 現在の地図IDを取得
          int? currentMapId;
          if (widget.mapInfo != null) {
            currentMapId = widget.mapInfo!.id;
          } else {
            // MapInfoがない場合は、地図画像パスから地図IDを取得または作成
            currentMapId = await DatabaseHelper.instance.getOrCreateMapId(
              _customMapPath,
              'カスタム地図',
            );
          }

          // 地図の中心座標で新規メモ作成画面に遷移
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddMemoScreen(
                initialLatitude: 0.5, // 地図の中心
                initialLongitude: 0.5,
                mapId: currentMapId,
                layer: _currentLayer,
              ),
            ),
          );
          if (result == true) {
            _loadMemos();
          }
        },
        child: const Icon(Icons.add),
        tooltip: '新しい記録を追加',
      ),
    );
  }

  @override
  void dispose() {
    _collaborationSubscription?.cancel();
    super.dispose();
  }
}
