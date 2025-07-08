import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/memo.dart';
import '../utils/database_helper.dart';

class CustomMapWidget extends StatefulWidget {
  final List<Memo> memos;
  final Function(double x, double y) onTap;
  final Function(Memo memo) onMemoTap;
  final String? customImagePath;
  final VoidCallback? onMemosUpdated; // メモ更新時のコールバックを追加

  const CustomMapWidget({
    Key? key,
    required this.memos,
    required this.onTap,
    required this.onMemoTap,
    this.customImagePath,
    this.onMemosUpdated, // コールバックを追加
  }) : super(key: key);

  @override
  CustomMapWidgetState createState() => CustomMapWidgetState();
}

class CustomMapWidgetState extends State<CustomMapWidget> {
  String? _mapImagePath;
  final TransformationController _transformationController =
      TransformationController();
  double _mapWidth = 800.0;
  double _mapHeight = 600.0;
  double _actualDisplayWidth = 800.0;
  double _actualDisplayHeight = 600.0;
  double _offsetX = 0.0;
  double _offsetY = 0.0;

  @override
  void initState() {
    super.initState();
    // customImagePathが渡されている場合はそれを使用、そうでなければ保存された画像を読み込み
    if (widget.customImagePath != null) {
      _mapImagePath = widget.customImagePath;
    } else {
      _loadSavedMapImage();
    }
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

  Future<ui.Image> _loadImageInfo() async {
    if (_mapImagePath == null) {
      throw Exception('地図画像パスが設定されていません');
    }
    final bytes = await File(_mapImagePath!).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
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
            // customImagePathが渡されている場合は地図ファイル選択ボタンを表示しない
            if (widget.customImagePath == null)
              ElevatedButton.icon(
                onPressed: _selectMapImage,
                icon: const Icon(Icons.upload_file),
                label: const Text('地図ファイルを選択'),
              ),
          ],
        ),
      );
    }

    return InteractiveViewer(
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

          // 画像のサイズに対する相対位置（0.0〜1.0）を計算（実際の表示サイズを使用）
          final double relativeX =
              (imagePosition.dx - _offsetX) / _actualDisplayWidth;
          final double relativeY =
              (imagePosition.dy - _offsetY) / _actualDisplayHeight;

          widget.onTap(relativeX, relativeY);
        },
        child: Container(
          width: _mapWidth,
          height: _mapHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return FutureBuilder<ui.Image>(
                future: _loadImageInfo(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final image = snapshot.data!;
                    // BoxFit.containの計算を行う
                    final containerAspect =
                        constraints.maxWidth / constraints.maxHeight;
                    final imageAspect = image.width / image.height;

                    if (imageAspect > containerAspect) {
                      // 画像の方が横長 - 幅に合わせる
                      _actualDisplayWidth = constraints.maxWidth;
                      _actualDisplayHeight = constraints.maxWidth / imageAspect;
                      _offsetX = 0.0;
                      _offsetY =
                          (constraints.maxHeight - _actualDisplayHeight) / 2;
                    } else {
                      // 画像の方が縦長または同じ - 高さに合わせる
                      _actualDisplayWidth = constraints.maxHeight * imageAspect;
                      _actualDisplayHeight = constraints.maxHeight;
                      _offsetX =
                          (constraints.maxWidth - _actualDisplayWidth) / 2;
                      _offsetY = 0.0;
                    }
                  }

                  return Stack(
                    children: [
                      // 地図画像を正確な位置に配置
                      Positioned(
                        left: _offsetX,
                        top: _offsetY,
                        width: _actualDisplayWidth,
                        height: _actualDisplayHeight,
                        child: Image.file(
                          File(_mapImagePath!),
                          fit: BoxFit.fill, // 正確なサイズに合わせるためfillを使用
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

                      // ピンは画像読み込み完了後のみ表示
                      if (snapshot.hasData)
                        ...widget.memos
                            .where((memo) =>
                                memo.latitude != null && memo.longitude != null)
                            .map((memo) {
                          // 地図上の相対位置からピクセル位置を計算（実際の表示サイズを使用）
                          final double pinX =
                              memo.latitude! * _actualDisplayWidth + _offsetX;
                          final double pinY =
                              memo.longitude! * _actualDisplayHeight + _offsetY;

                          return Positioned(
                            left: pinX - 20,
                            top: pinY - 40,
                            child: GestureDetector(
                              onTap: () => widget.onMemoTap(memo),
                              onLongPress: () =>
                                  _showPinNumberDialog(memo), // 長押しで番号編集
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _getCategoryColor(memo.category),
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    // カテゴリアイコン
                                    Center(
                                      child: Icon(
                                        _getCategoryIcon(memo.category),
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                    // ピン番号
                                    if (memo.pinNumber != null)
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: Container(
                                          width: 16,
                                          height: 16,
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: Colors.white, width: 1),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${memo.pinNumber}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
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

  // ピン番号編集ダイアログを表示
  void _showPinNumberDialog(Memo memo) {
    final TextEditingController controller = TextEditingController(
      text: memo.pinNumber?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ピン番号を編集'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('「${memo.title}」のピン番号を設定してください'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ピン番号',
                  hintText: '1, 2, 3...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () async {
                final newNumber = int.tryParse(controller.text);
                if (newNumber != null && newNumber > 0) {
                  // メモを更新
                  final updatedMemo = Memo(
                    id: memo.id,
                    title: memo.title,
                    content: memo.content,
                    latitude: memo.latitude,
                    longitude: memo.longitude,
                    discoveryTime: memo.discoveryTime,
                    discoverer: memo.discoverer,
                    specimenNumber: memo.specimenNumber,
                    category: memo.category,
                    notes: memo.notes,
                    pinNumber: newNumber,
                  );

                  await DatabaseHelper.instance.update(updatedMemo);

                  // 親ウィジェットに更新を通知
                  if (widget.onMemosUpdated != null) {
                    widget.onMemosUpdated!();
                  }

                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('ピン番号を $newNumber に更新しました')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('有効な番号を入力してください')),
                  );
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
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

  // 地図サイズを取得するメソッド
  double get mapWidth => _mapWidth;
  double get mapHeight => _mapHeight;
  double get actualDisplayWidth => _actualDisplayWidth;
  double get actualDisplayHeight => _actualDisplayHeight;
  double get offsetX => _offsetX;
  double get offsetY => _offsetY;
  String? get mapImagePath => _mapImagePath;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }
}
