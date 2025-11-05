import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import '../models/map_info.dart';
import '../utils/database_helper.dart';
import '../utils/collaboration_sync_coordinator.dart';
import 'add_map_screen.dart';
import 'map_screen.dart';

/// カスタム地図一覧を表示する画面
class MapListScreen extends StatefulWidget {
  const MapListScreen({super.key});

  @override
  _MapListScreenState createState() => _MapListScreenState();
}

class _MapListScreenState extends State<MapListScreen> {
  // 定数定義
  static const String _appBarTitle = 'カスタム地図管理';
  static const String _emptyStateTitle = 'カスタム地図がありません';
  static const String _emptyStateSubtitle = '新しい地図を追加してフィールドワークを始めましょう';
  static const String _emptyStateButtonLabel = '最初の地図を追加';
  static const String _deleteDialogTitle = '地図を削除';
  static const String _deleteDialogMessageSuffix =
      'を削除しますか？\n\nこの地図に関連する記録もすべて削除されます。';
  static const String _deleteConfirmButton = '削除';
  static const String _deleteCancelButton = 'キャンセル';
  static const String _deleteSuccessMessageSuffix = 'を削除しました';
  static const String _deleteErrorMessage = '削除に失敗しました';
  static const String _loadErrorMessage = '地図の読み込みに失敗しました';
  static const String _deleteFileErrorMessage = '地図ファイルの削除に失敗しました';
  static const String _mapCardHintText = 'タップして地図を開く';
  static const double _mapImageHeight = 150.0;
  static const double _cardMargin = 12.0;
  static const double _cardPadding = 16.0;

  List<MapInfo> _maps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMaps();
  }

  /// 地図一覧をデータベースから読み込む
  Future<void> _loadMaps() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final maps = await DatabaseHelper.instance.readAllMaps();
      if (!mounted) return;

      setState(() {
        _maps = maps;
      });
    } catch (e) {
      if (!mounted) return;

      _showErrorSnackBar(_loadErrorMessage, error: e);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 地図を開く
  void _openMap(MapInfo mapInfo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(mapInfo: mapInfo),
      ),
    ).then((_) {
      if (mounted) {
        _loadMaps(); // 地図画面から戻ったら再読み込み
      }
    });
  }

  /// 新しい地図を追加する画面に遷移
  Future<void> _addNewMap() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddMapScreen()),
    );
    if (result == true && mounted) {
      _loadMaps(); // 新しい地図が追加されたら再読み込み
    }
  }

  /// 地図を削除する
  Future<void> _deleteMap(MapInfo mapInfo) async {
    final shouldDelete = await _showDeleteConfirmationDialog(mapInfo.title);
    if (shouldDelete != true || !mounted) {
      return;
    }

    try {
      await _performMapDeletion(mapInfo);
      if (!mounted) return;

      _showSuccessSnackBar('${mapInfo.title}$_deleteSuccessMessageSuffix');
      _loadMaps(); // リストを再読み込み
    } catch (e) {
      if (!mounted) return;

      _showErrorSnackBar(_deleteErrorMessage, error: e, isError: true);
    }
  }

  /// 削除確認ダイアログを表示
  Future<bool?> _showDeleteConfirmationDialog(String mapTitle) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(_deleteDialogTitle),
          content: Text('「$mapTitle」$_deleteDialogMessageSuffix'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(_deleteCancelButton),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text(_deleteConfirmButton),
            ),
          ],
        );
      },
    );
  }

  /// 地図の削除処理を実行（データベース、コラボレーション、ファイル）
  Future<void> _performMapDeletion(MapInfo mapInfo) async {
    await DatabaseHelper.instance.deleteMap(mapInfo.id!);
    await CollaborationSyncCoordinator.instance
        .unregisterCollaborativeMap(mapInfo.id!);

    // 地図ファイルも削除
    await _deleteMapFile(mapInfo.imagePath);
  }

  /// 地図ファイルを削除（Web環境ではスキップ）
  Future<void> _deleteMapFile(String? imagePath) async {
    if (imagePath == null || kIsWeb) {
      return;
    }

    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // ファイル削除のエラーは無視（ログ出力のみ）
      debugPrint('$_deleteFileErrorMessage: $e');
    }
  }

  /// エラー用のSnackBarを表示
  void _showErrorSnackBar(String message,
      {Object? error, bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error != null ? '$message: $error' : message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  /// 成功用のSnackBarを表示
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  /// AppBarを構築
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(_appBarTitle),
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: '新しい地図を追加',
          onPressed: _addNewMap,
        ),
      ],
    );
  }

  /// ボディを構築（ローディング、空状態、リストのいずれか）
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_maps.isEmpty) {
      return _buildEmptyState();
    }

    return _buildMapsList();
  }

  /// フローティングアクションボタンを構築（地図がある場合のみ）
  Widget? _buildFloatingActionButton() {
    if (_maps.isEmpty) {
      return null;
    }

    return FloatingActionButton(
      onPressed: _addNewMap,
      tooltip: '新しい地図を追加',
      child: const Icon(Icons.add),
    );
  }

  /// 空状態を表示するウィジェット
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.map_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            _emptyStateTitle,
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            _emptyStateSubtitle,
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addNewMap,
            icon: const Icon(Icons.add),
            label: const Text(_emptyStateButtonLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// 地図一覧を表示するウィジェット
  Widget _buildMapsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(_cardPadding),
      itemCount: _maps.length,
      itemBuilder: (context, index) {
        return _buildMapCard(_maps[index]);
      },
    );
  }

  /// 個別の地図カードを構築
  Widget _buildMapCard(MapInfo map) {
    return Card(
      margin: const EdgeInsets.only(bottom: _cardMargin),
      child: InkWell(
        onTap: () => _openMap(map),
        borderRadius: BorderRadius.circular(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (map.imagePath != null) _buildMapImage(map.imagePath!),
            _buildMapCardContent(map),
          ],
        ),
      ),
    );
  }

  /// 地図画像を構築
  Widget _buildMapImage(String imagePath) {
    return Container(
      width: double.infinity,
      height: _mapImageHeight,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(8.0),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(8.0),
        ),
        child: _buildImageWidget(imagePath),
      ),
    );
  }

  /// 地図カードのコンテンツ部分を構築
  Widget _buildMapCardContent(MapInfo map) {
    return Padding(
      padding: const EdgeInsets.all(_cardPadding),
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
                  _mapCardHintText,
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
          const Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Colors.grey,
          ),
        ],
      ),
    );
  }

  /// 画像ウィジェットを構築（Web/モバイル対応）
  Widget _buildImageWidget(String imagePath) {
    if (kIsWeb && imagePath.startsWith('data:image')) {
      return _buildWebImage(imagePath);
    } else {
      return _buildFileImage(imagePath);
    }
  }

  /// Web環境でのBase64画像を構築
  Widget _buildWebImage(String imagePath) {
    try {
      final base64Data = imagePath.split(',')[1];
      final bytes = base64Decode(base64Data);
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildErrorImage(),
      );
    } catch (e) {
      return _buildErrorImage();
    }
  }

  /// ファイルパスから画像を構築
  Widget _buildFileImage(String imagePath) {
    return Image.file(
      File(imagePath),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildErrorImage(),
    );
  }

  /// エラー時の画像プレースホルダー
  Widget _buildErrorImage() {
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
  }
}
