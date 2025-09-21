import 'dart:io';
import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:hive/hive.dart';
import '../models/memo.dart';
import '../utils/database_helper.dart';
import '../utils/collaboration_sync_coordinator.dart';

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
  double _currentScale = 1.0; // 現在のスケール値を追跡

  @override
  void initState() {
    super.initState();
    // customImagePathが渡されている場合はそれを使用、そうでなければ保存された画像を読み込み
    if (widget.customImagePath != null) {
      _mapImagePath = widget.customImagePath;
    } else {
      _loadSavedMapImage();
    }

    // TransformationControllerのリスナーを追加してスケール変更を監視
    _transformationController.addListener(_onTransformChanged);
  }

  // スケール変更時のコールバック
  void _onTransformChanged() {
    final Matrix4 matrix = _transformationController.value;
    final double newScale = matrix.getMaxScaleOnAxis();
    print('スケール変更: $_currentScale -> $newScale'); // デバッグ用
    if ((newScale - _currentScale).abs() > 0.01) {
      // より小さな変化も検知
      setState(() {
        _currentScale = newScale;
      });
      print('ピンサイズ: ${_getPinSize()}'); // デバッグ用
    }
  }

  // ズーム倍率に応じたピンサイズを計算
  double _getPinSize() {
    // ベースサイズ40px、最小20px、最大80px
    const double baseSize = 40.0;
    const double minSize = 20.0;
    const double maxSize = 80.0;

    // スケールが小さいほど（ズームアウト）ピンを大きく表示
    // スケールが大きいほど（ズームイン）ピンを小さく表示
    // スケール値を逆数として使用して、よりダイナミックな変化を実現
    final double scaleFactor = 1.0 / _currentScale;
    final double adjustedSize = baseSize * scaleFactor;
    final double clampedSize = adjustedSize.clamp(minSize, maxSize);

    print(
        'ピンサイズ計算: スケール=$_currentScale, 係数=$scaleFactor, 調整サイズ=$adjustedSize, 最終サイズ=$clampedSize'); // デバッグ用

    return clampedSize;
  }

  // ズーム倍率に応じたアイコンサイズを計算
  double _getIconSize() {
    final double pinSize = _getPinSize();
    return (pinSize * 0.4).clamp(12.0, 24.0);
  }

  // ズーム倍率に応じたピン番号コンテナサイズを計算
  double _getPinNumberSize() {
    final double pinSize = _getPinSize();
    return (pinSize * 0.4).clamp(12.0, 20.0);
  }

  // ズーム倍率に応じたピン番号フォントサイズを計算
  double _getPinNumberFontSize() {
    final double pinNumberSize = _getPinNumberSize();
    return (pinNumberSize * 0.6).clamp(8.0, 12.0);
  }

  Future<void> _loadSavedMapImage() async {
    try {
      if (kIsWeb) {
        // Web版: Hiveから画像データを読み込み
        final box = await Hive.openBox('app_settings');
        final savedMapData = box.get('custom_map_image');
        if (savedMapData != null) {
          setState(() {
            _mapImagePath = savedMapData; // Base64文字列
          });
        }
      } else {
        // モバイル版: ファイルシステムから読み込み
        final directory = await getApplicationDocumentsDirectory();
        final mapFile = File('${directory.path}/custom_map.png');
        if (await mapFile.exists()) {
          setState(() {
            _mapImagePath = mapFile.path;
          });
        }
      }
    } catch (e) {
      print('地図ファイルの読み込み中にエラーが発生しました: $e');
    }
  }

  Future<ui.Image> _loadImageInfo() async {
    if (_mapImagePath == null) {
      throw Exception('地図画像パスが設定されていません');
    }

    Uint8List bytes;
    if (kIsWeb) {
      // Web版: Base64文字列をデコード
      if (_mapImagePath!.startsWith('data:image')) {
        // Base64データURL形式の場合
        final base64Data = _mapImagePath!.split(',')[1];
        bytes = base64Decode(base64Data);
      } else {
        // 直接Base64文字列の場合
        bytes = base64Decode(_mapImagePath!);
      }
    } else {
      // モバイル版: ファイルから読み込み
      bytes = await File(_mapImagePath!).readAsBytes();
    }

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
        if (kIsWeb) {
          // Web版: ファイルをBase64エンコードしてHiveに保存
          final fileBytes = result.files.single.bytes!;
          final base64Image = base64Encode(fileBytes);
          final dataUrl = 'data:image/png;base64,$base64Image';

          // Hiveに保存
          final box = await Hive.openBox('app_settings');
          await box.put('custom_map_image', dataUrl);

          setState(() {
            _mapImagePath = dataUrl;
          });
        } else {
          // モバイル版: ファイルシステムに保存
          File selectedFile = File(result.files.single.path!);

          // アプリのドキュメントディレクトリにファイルをコピー
          final directory = await getApplicationDocumentsDirectory();
          final fileName = 'custom_map${path.extension(selectedFile.path)}';
          final savedFile = File('${directory.path}/$fileName');

          await selectedFile.copy(savedFile.path);

          setState(() {
            _mapImagePath = savedFile.path;
          });
        }

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
      if (kIsWeb) {
        // Web版: Hiveからデータを削除
        final box = await Hive.openBox('app_settings');
        await box.delete('custom_map_image');
      } else {
        // モバイル版: ファイルを削除
        final directory = await getApplicationDocumentsDirectory();
        final mapFile = File('${directory.path}/custom_map.png');
        if (await mapFile.exists()) {
          await mapFile.delete();
        }
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
      onInteractionUpdate: (ScaleUpdateDetails details) {
        // スケール値の更新を直接監視
        final Matrix4 matrix = _transformationController.value;
        final double newScale = matrix.getMaxScaleOnAxis();
        print('インタラクション更新: スケール = $newScale'); // デバッグ用
        if ((newScale - _currentScale).abs() > 0.01) {
          setState(() {
            _currentScale = newScale;
          });
          print('ピンサイズ更新: ${_getPinSize()}'); // デバッグ用
        }
      },
      child: GestureDetector(
        // iOS PWA タッチ反応問題を解決するため、タッチ動作を最適化
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          // タップ位置を地図座標に変換
          final RenderBox renderBox = context.findRenderObject() as RenderBox;
          final localPosition = renderBox.globalToLocal(details.globalPosition);

          // まず、タップ位置が画像表示領域内かどうかを確認
          if (localPosition.dx < _offsetX ||
              localPosition.dx > _offsetX + _actualDisplayWidth ||
              localPosition.dy < _offsetY ||
              localPosition.dy > _offsetY + _actualDisplayHeight) {
            return; // 画像外のタップは無視
          }

          // 画像表示領域内の相対座標を計算（ズーム・パン変換前）
          final Offset imageLocalPosition = Offset(
            localPosition.dx - _offsetX,
            localPosition.dy - _offsetY,
          );

          // InteractiveViewerの変換を適用
          final Matrix4 matrix = _transformationController.value;
          final Matrix4? invertedMatrix = Matrix4.tryInvert(matrix);
          if (invertedMatrix == null) return;

          // 画像表示領域を基準とした座標で変換
          final Offset transformedPosition = MatrixUtils.transformPoint(
            invertedMatrix,
            imageLocalPosition,
          );

          // 相対座標（0.0〜1.0）に変換
          final double relativeX = transformedPosition.dx / _actualDisplayWidth;
          final double relativeY =
              transformedPosition.dy / _actualDisplayHeight;

          // 範囲チェック - 正規化座標が有効範囲内かを確認
          if (relativeX >= 0.0 &&
              relativeX <= 1.0 &&
              relativeY >= 0.0 &&
              relativeY <= 1.0) {
            widget.onTap(relativeX, relativeY);
          }
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
                        child: kIsWeb
                            ?
                            // Web版: Base64データから画像を表示
                            _buildWebImage(_mapImagePath!)
                            :
                            // モバイル版: ファイルから画像を表示
                            Image.file(
                                File(_mapImagePath!),
                                fit: BoxFit.fill,
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

                          // ズーム倍率に応じたサイズを計算
                          final double pinSize = _getPinSize();
                          final double iconSize = _getIconSize();
                          final double pinNumberSize = _getPinNumberSize();
                          final double pinNumberFontSize =
                              _getPinNumberFontSize();

                          return Positioned(
                            left: pinX - pinSize / 2,
                            top: pinY - pinSize,
                            child: GestureDetector(
                              // iOS PWA タッチ反応問題を解決するため、タッチ動作を最適化
                              behavior: HitTestBehavior.opaque,
                              onTap: () => widget.onMemoTap(memo),
                              onLongPress: () =>
                                  _showPinNumberDialog(memo), // 長押しで番号編集
                              child: Container(
                                width: pinSize,
                                height: pinSize,
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
                                        size: iconSize,
                                      ),
                                    ),
                                    // ピン番号
                                    if (memo.pinNumber != null)
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: Container(
                                          width: pinNumberSize,
                                          height: pinNumberSize,
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: Colors.white, width: 1),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${memo.pinNumber}',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: pinNumberFontSize,
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

  // Web版での画像表示メソッド
  Widget _buildWebImage(String imagePath) {
    try {
      Uint8List bytes;
      if (imagePath.startsWith('data:image')) {
        // Base64データURL形式の場合
        final base64Data = imagePath.split(',')[1];
        bytes = base64Decode(base64Data);
      } else {
        // 直接Base64文字列の場合
        bytes = base64Decode(imagePath);
      }

      return Image.memory(
        bytes,
        fit: BoxFit.fill,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: const Center(
              child: Text('地図画像を読み込めませんでした'),
            ),
          );
        },
      );
    } catch (e) {
      return Container(
        color: Colors.grey[300],
        child: const Center(
          child: Text('地図画像の形式が正しくありません'),
        ),
      );
    }
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
                  try {
                    await CollaborationSyncCoordinator.instance
                        .onLocalMemoUpdated(updatedMemo);
                  } catch (error, stackTrace) {
                    debugPrint('Failed to sync pin update: $error');
                    debugPrintStack(stackTrace: stackTrace);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('共同編集への同期に失敗しました: $error'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }

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

  // ズームイン機能
  void _zoomIn() {
    final newScale = (_currentScale * 1.2).clamp(0.1, 5.0);
    _setScale(newScale);
  }

  // ズームアウト機能
  void _zoomOut() {
    final newScale = (_currentScale / 1.2).clamp(0.1, 5.0);
    _setScale(newScale);
  }

  // スケールを設定する機能（中央基準でズーム）
  void _setScale(double scale) {
    final double scaleChange = scale / _currentScale;

    // ビューポートのサイズを取得
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Size viewportSize = renderBox.size;
    final double viewportCenterX = viewportSize.width / 2;
    final double viewportCenterY = viewportSize.height / 2;

    // 現在の変換行列を取得
    final Matrix4 currentMatrix = _transformationController.value;

    // ビューポート中央を基準にスケール変更を適用
    final Matrix4 newMatrix = Matrix4.identity()
      ..translate(viewportCenterX, viewportCenterY)
      ..scale(scaleChange)
      ..translate(-viewportCenterX, -viewportCenterY)
      ..multiply(currentMatrix);

    _transformationController.value = newMatrix;

    // スケール値を更新してピンサイズを再計算
    setState(() {
      _currentScale = scale;
    });
    print('手動スケール設定: $scale, ピンサイズ: ${_getPinSize()}'); // デバッグ用
  }

  // リセット機能
  void _resetTransform() {
    _transformationController.value = Matrix4.identity();
    setState(() {
      _currentScale = 1.0;
    });
    print('変換リセット: スケール = 1.0, ピンサイズ: ${_getPinSize()}'); // デバッグ用
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // 地図操作パネル
        Container(
          padding: const EdgeInsets.all(8.0),
          color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _mapImagePath != null
                      ? 'カスタム地図: ${path.basename(_mapImagePath!)}'
                      : 'デフォルト地図',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.zoom_in,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                onPressed: _zoomIn,
                tooltip: '拡大',
              ),
              IconButton(
                icon: Icon(
                  Icons.zoom_out,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                onPressed: _zoomOut,
                tooltip: '縮小',
              ),
              IconButton(
                icon: Icon(
                  Icons.center_focus_strong,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                onPressed: _resetTransform,
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
    _transformationController.removeListener(_onTransformChanged);
    _transformationController.dispose();
    super.dispose();
  }
}
