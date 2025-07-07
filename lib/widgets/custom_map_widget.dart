import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/memo.dart';

class CustomMapWidget extends StatefulWidget {
  final List<Memo> memos;
  final Function(double x, double y) onTap;
  final Function(Memo memo) onMemoTap;

  const CustomMapWidget({
    Key? key,
    required this.memos,
    required this.onTap,
    required this.onMemoTap,
  }) : super(key: key);

  @override
  _CustomMapWidgetState createState() => _CustomMapWidgetState();
}

class _CustomMapWidgetState extends State<CustomMapWidget> {
  String? _mapImagePath;
  final TransformationController _transformationController = TransformationController();
  double _mapWidth = 800.0;
  double _mapHeight = 600.0;

  @override
  void initState() {
    super.initState();
    _loadSavedMapImage();
  }

  Future<void> _loadSavedMapImage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final mapFile = File('${directory.path}/custom_map.png');
      if (await mapFile.exists()) {
        setState(() {
          _mapImagePath = mapFile.path;
        });
      }
    } catch (e) {
      print('地図ファイルの読み込み中にエラーが発生しました: $e');
    }
  }

  Future<void> _selectMapImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (result != null) {
        File selectedFile = File(result.files.single.path!);
        
        // アプリのドキュメントディレクトリにファイルをコピー
        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'custom_map${path.extension(selectedFile.path)}';
        final savedFile = File('${directory.path}/$fileName');
        
        await selectedFile.copy(savedFile.path);
        
        setState(() {
          _mapImagePath = savedFile.path;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('地図画像を設定しました')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ファイル選択中にエラーが発生しました: $e')),
      );
    }
  }

  Future<void> _clearMapImage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final mapFile = File('${directory.path}/custom_map.png');
      if (await mapFile.exists()) {
        await mapFile.delete();
      }
      
      setState(() {
        _mapImagePath = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('地図画像をクリアしました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ファイル削除中にエラーが発生しました: $e')),
      );
    }
  }

  Widget _buildMapContent() {
    if (_mapImagePath == null) {
      return Container(
        width: double.infinity,
        height: 400,
        color: Colors.grey[200],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.map_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'カスタム地図が設定されていません',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'フィールドワーク用の地図画像（PNG、JPG）またはPDFファイルを選択してください',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _selectMapImage,
              icon: const Icon(Icons.upload_file),
              label: const Text('地図ファイルを選択'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // 地図画像
        InteractiveViewer(
          transformationController: _transformationController,
          boundaryMargin: const EdgeInsets.all(20.0),
          minScale: 0.1,
          maxScale: 5.0,
          child: GestureDetector(
            onTapDown: (details) {
              // タップ位置を地図座標に変換
              final RenderBox renderBox = context.findRenderObject() as RenderBox;
              final localPosition = renderBox.globalToLocal(details.globalPosition);
              
                             // 変換行列を考慮して実際の画像上での位置を計算
               final Matrix4 matrix = _transformationController.value;
               final Matrix4? invertedMatrix = Matrix4.tryInvert(matrix);
               if (invertedMatrix == null) return;
               final Offset imagePosition = MatrixUtils.transformPoint(
                 invertedMatrix,
                 localPosition,
               );
              
              // 画像のサイズに対する相対位置（0.0〜1.0）を計算
              final double relativeX = imagePosition.dx / _mapWidth;
              final double relativeY = imagePosition.dy / _mapHeight;
              
              widget.onTap(relativeX, relativeY);
            },
            child: Container(
              width: _mapWidth,
              height: _mapHeight,
              child: Image.file(
                File(_mapImagePath!),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: Text('地図画像を読み込めませんでした'),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        
        // メモのピン
        ...widget.memos.where((memo) => memo.latitude != null && memo.longitude != null).map((memo) {
          // 地図上の相対位置からピクセル位置を計算
          final double pinX = memo.latitude! * _mapWidth;
          final double pinY = memo.longitude! * _mapHeight;
          
          return Positioned(
            left: pinX - 20,
            top: pinY - 40,
            child: GestureDetector(
              onTap: () => widget.onMemoTap(memo),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getCategoryColor(memo.category),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  _getCategoryIcon(memo.category),
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case '植物':
        return Colors.green;
      case '動物':
        return Colors.brown;
      case '昆虫':
        return Colors.orange;
      case '鉱物':
        return Colors.grey;
      case '化石':
        return Colors.purple;
      case '地形':
        return Colors.blue;
      default:
        return Colors.blue;
    }
  }

  IconData _getCategoryIcon(String? category) {
    switch (category) {
      case '植物':
        return Icons.local_florist;
      case '動物':
        return Icons.pets;
      case '昆虫':
        return Icons.bug_report;
      case '鉱物':
        return Icons.diamond;
             case '化石':
         return Icons.history;
      case '地形':
        return Icons.terrain;
      default:
        return Icons.sticky_note_2;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 地図操作パネル
        Container(
          padding: const EdgeInsets.all(8.0),
          color: Colors.grey[100],
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _mapImagePath != null 
                    ? 'カスタム地図: ${path.basename(_mapImagePath!)}'
                    : 'デフォルト地図',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.upload_file),
                onPressed: _selectMapImage,
                tooltip: '地図ファイルを選択',
              ),
              if (_mapImagePath != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: _clearMapImage,
                  tooltip: '地図をクリア',
                ),
              IconButton(
                icon: const Icon(Icons.zoom_in),
                onPressed: () {
                  final Matrix4 matrix = _transformationController.value;
                  _transformationController.value = matrix..scale(1.2);
                },
                tooltip: '拡大',
              ),
              IconButton(
                icon: const Icon(Icons.zoom_out),
                onPressed: () {
                  final Matrix4 matrix = _transformationController.value;
                  _transformationController.value = matrix..scale(0.8);
                },
                tooltip: '縮小',
              ),
              IconButton(
                icon: const Icon(Icons.center_focus_strong),
                onPressed: () {
                  _transformationController.value = Matrix4.identity();
                },
                tooltip: 'リセット',
              ),
            ],
          ),
        ),
        
        // 地図表示エリア
        Expanded(
          child: Container(
            width: double.infinity,
            child: _buildMapContent(),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }
} 