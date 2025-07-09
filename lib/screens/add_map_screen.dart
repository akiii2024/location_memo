import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import '../models/map_info.dart';
import '../utils/database_helper.dart';

class AddMapScreen extends StatefulWidget {
  const AddMapScreen({Key? key}) : super(key: key);

  @override
  _AddMapScreenState createState() => _AddMapScreenState();
}

class _AddMapScreenState extends State<AddMapScreen> {
  final TextEditingController _titleController = TextEditingController();
  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isLoading = false;
  bool _isSaving = false;

  Future<void> _pickImage() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _selectedImageBytes = bytes;
          });
        } else {
          setState(() {
            _selectedImage = File(image.path);
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('画像の選択に失敗しました: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _takePhoto() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _selectedImageBytes = bytes;
          });
        } else {
          setState(() {
            _selectedImage = File(image.path);
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('写真の撮影に失敗しました: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveMap() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('地図のタイトルを入力してください')),
      );
      return;
    }

    if ((kIsWeb ? _selectedImageBytes == null : _selectedImage == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('地図画像を選択してください')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      String? imagePath;

      if (kIsWeb) {
        // Web環境: Base64エンコードされた画像データを保存
        if (_selectedImageBytes != null) {
          final base64Image = base64Encode(_selectedImageBytes!);
          imagePath = 'data:image/png;base64,$base64Image';
        }
      } else {
        // モバイル/デスクトップ環境: ファイルとして保存
        if (_selectedImage != null) {
          final directory = await getApplicationDocumentsDirectory();
          final fileName = 'map_${DateTime.now().millisecondsSinceEpoch}.png';
          final savedImage =
              await _selectedImage!.copy('${directory.path}/$fileName');
          imagePath = savedImage.path;
        }
      }

      final mapInfo = MapInfo(
        title: _titleController.text.trim(),
        imagePath: imagePath,
      );

      await DatabaseHelper.instance.createMap(mapInfo);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('カスタム地図を保存しました'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存に失敗しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('カスタム地図を追加'),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            tooltip: '保存',
            onPressed: _isSaving ? null : _saveMap,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // タイトル入力
            const Text(
              '地図情報',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '地図のタイトル *',
                border: OutlineInputBorder(),
                helperText: '例: 公園の植物分布図、海岸の地形図など',
              ),
            ),
            const SizedBox(height: 24),

            // 画像選択
            const Text(
              '地図画像',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // プレビュー表示条件の修正
            if ((kIsWeb
                ? _selectedImageBytes != null
                : _selectedImage != null)) ...[
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: kIsWeb
                      ? Image.memory(
                          _selectedImageBytes!,
                          fit: BoxFit.cover,
                        )
                      : Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _pickImage,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('ギャラリーから選択'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('カメラで撮影'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 保存ボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveMap,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: _isSaving
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('保存中...', style: TextStyle(fontSize: 16)),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save, size: 20),
                          SizedBox(width: 8),
                          Text('カスタム地図を保存', style: TextStyle(fontSize: 16)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // 説明
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade600),
                      const SizedBox(width: 8),
                      const Text(
                        'カスタム地図について',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• フィールドワーク用の地図画像をアップロードできます\n'
                    '• 保存した地図上で記録を作成できます\n'
                    '• 推奨サイズ: 1920x1080px以下\n'
                    '• 対応形式: JPG, PNG',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }
}
