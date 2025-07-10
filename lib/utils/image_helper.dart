import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';

class ImageHelper {
  static const String _imagesDirectoryName = 'memo_images';

  /// 画像保存用ディレクトリのパスを取得
  static Future<String> getImagesDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${directory.path}/$_imagesDirectoryName');

    // ディレクトリが存在しない場合は作成
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    return imagesDir.path;
  }

  /// 画像ファイルを保存（モバイル・デスクトップ環境）
  static Future<String> saveImageFile(File imageFile) async {
    final imagesDir = await getImagesDirectory();
    final fileName = 'memo_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savedFile = File('$imagesDir/$fileName');

    await imageFile.copy(savedFile.path);
    return savedFile.path;
  }

  /// 画像データを保存（Web環境）
  static Future<String> saveImageBytes(Uint8List imageBytes) async {
    if (kIsWeb) {
      // Web環境: Base64エンコードして返す
      final base64Image = base64Encode(imageBytes);
      return 'data:image/jpeg;base64,$base64Image';
    } else {
      // モバイル・デスクトップ環境: ファイルとして保存
      final imagesDir = await getImagesDirectory();
      final fileName =
          'memo_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('$imagesDir/$fileName');

      await file.writeAsBytes(imageBytes);
      return file.path;
    }
  }

  /// XFileから画像を保存
  static Future<String> saveXFile(XFile imageFile) async {
    if (kIsWeb) {
      final bytes = await imageFile.readAsBytes();
      return await saveImageBytes(bytes);
    } else {
      return await saveImageFile(File(imageFile.path));
    }
  }

  /// 画像ファイルを削除
  static Future<bool> deleteImage(String imagePath) async {
    try {
      if (kIsWeb) {
        // Web環境: Base64データなので実際のファイル削除は不要
        return true;
      } else {
        // モバイル・デスクトップ環境: ファイルを削除
        final file = File(imagePath);
        if (await file.exists()) {
          await file.delete();
          return true;
        }
      }
      return false;
    } catch (e) {
      print('画像削除エラー: $e');
      return false;
    }
  }

  /// 複数の画像ファイルを削除
  static Future<void> deleteImages(List<String> imagePaths) async {
    for (final path in imagePaths) {
      await deleteImage(path);
    }
  }

  /// 画像が存在するかチェック
  static Future<bool> imageExists(String imagePath) async {
    try {
      if (kIsWeb) {
        // Web環境: Base64データの有効性をチェック
        return imagePath.startsWith('data:image') &&
            imagePath.contains('base64,');
      } else {
        // モバイル・デスクトップ環境: ファイルの存在をチェック
        return await File(imagePath).exists();
      }
    } catch (e) {
      return false;
    }
  }

  /// 画像ウィジェットを作成
  static Widget buildImageWidget(
    String imagePath, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
  }) {
    Widget imageWidget;

    if (kIsWeb && imagePath.startsWith('data:image')) {
      // Web環境: Base64データから画像を表示
      final base64Data = imagePath.split(',')[1];
      final bytes = base64Decode(base64Data);
      imageWidget = Image.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorWidget(width, height);
        },
      );
    } else {
      // モバイル・デスクトップ環境: ファイルから画像を表示
      imageWidget = Image.file(
        File(imagePath),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorWidget(width, height);
        },
      );
    }

    // 角の丸みを適用
    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  /// エラー時の代替ウィジェット
  static Widget _buildErrorWidget(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image,
              size: 48,
              color: Colors.grey,
            ),
            SizedBox(height: 8),
            Text(
              '画像を読み込めません',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 画像選択ダイアログを表示
  static Future<String?> pickAndSaveImage(BuildContext context) async {
    try {
      final ImagePicker picker = ImagePicker();

      // 画像ソース選択ダイアログ
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('画像を追加'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('カメラで撮影'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('ギャラリーから選択'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
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

      if (source == null) return null;

      // 画像を選択
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image != null) {
        // 画像を保存
        return await saveXFile(image);
      }

      return null;
    } catch (e) {
      print('画像選択エラー: $e');
      return null;
    }
  }

  /// 画像のファイルサイズを取得（バイト単位）
  static Future<int> getImageSize(String imagePath) async {
    try {
      if (kIsWeb) {
        if (imagePath.startsWith('data:image')) {
          final base64Data = imagePath.split(',')[1];
          final bytes = base64Decode(base64Data);
          return bytes.length;
        }
        return 0;
      } else {
        final file = File(imagePath);
        if (await file.exists()) {
          return await file.length();
        }
        return 0;
      }
    } catch (e) {
      return 0;
    }
  }

  /// 画像のファイルサイズを人間が読みやすい形式で取得
  static Future<String> getImageSizeFormatted(String imagePath) async {
    final sizeInBytes = await getImageSize(imagePath);
    if (sizeInBytes == 0) return '不明';

    if (sizeInBytes < 1024) {
      return '${sizeInBytes}B';
    } else if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
  }
}
