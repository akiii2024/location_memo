import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/memo.dart';
import '../models/map_info.dart';
import 'database_helper.dart';

// Web環境でのファイルダウンロード用の条件付きインポート
import 'web_backup_service_stub.dart'
    if (dart.library.html) 'web_backup_service.dart';

class BackupService {
  static const String _backupFileName = 'location_memo_backup.json';
  static const String _mapBackupFilePrefix = 'location_memo_map_backup';

  /// 全データをバックアップファイルとしてエクスポート（画像を含む）
  static Future<String?> exportData() async {
    try {
      // データベースから全てのデータを取得
      final memos = await DatabaseHelper.instance.readAllMemos();
      final maps = await DatabaseHelper.instance.readAllMaps();

      // 地図の画像をBase64エンコード
      final List<Map<String, dynamic>> mapsWithImages = [];
      for (final map in maps) {
        final mapData = map.toMap();
        if (map.imagePath != null && map.imagePath!.isNotEmpty) {
          try {
            final imageData = await _encodeImageToBase64(map.imagePath!);
            mapData['imageData'] = imageData;
          } catch (e) {
            print('画像エンコードエラー (${map.imagePath}): $e');
          }
        }
        mapsWithImages.add(mapData);
      }

      // メモの画像をBase64エンコード
      final List<Map<String, dynamic>> memosWithImages = [];
      for (final memo in memos) {
        final memoData = memo.toMap();

        // メモに添付された画像をエンコード
        if (memo.imagePaths != null && memo.imagePaths!.isNotEmpty) {
          final List<String> encodedImages = [];
          for (final imagePath in memo.imagePaths!) {
            try {
              final imageData = await _encodeImageToBase64(imagePath);
              encodedImages.add(imageData);
            } catch (e) {
              print('メモ画像エンコードエラー ($imagePath): $e');
            }
          }
          if (encodedImages.isNotEmpty) {
            memoData['imageDataList'] = encodedImages;
          }
        }
        memosWithImages.add(memoData);
      }

      // バックアップデータを作成
      final backupData = {
        'version': '1.0.0',
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'full_backup',
        'data': {
          'memos': memosWithImages,
          'maps': mapsWithImages,
        }
      };

      // JSONに変換
      final jsonString = jsonEncode(backupData);

      if (kIsWeb) {
        // Web環境では一時ファイルの代わりにJSON文字列を返す
        return jsonString;
      } else {
        // ネイティブ環境では一時ファイルに保存
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/$_backupFileName');
        await file.writeAsString(jsonString);
        return file.path;
      }
    } catch (e) {
      print('バックアップエクスポートエラー: $e');
      return null;
    }
  }

  /// 特定の地図のデータをバックアップファイルとしてエクスポート
  static Future<String?> exportMapData(int mapId) async {
    try {
      // 指定された地図の情報を取得
      final maps = await DatabaseHelper.instance.readAllMaps();
      final targetMap = maps.firstWhere(
        (map) => map.id == mapId,
        orElse: () => throw Exception('指定された地図が見つかりません'),
      );

      // 指定された地図に関連するメモを取得
      final memos = await DatabaseHelper.instance.readMemosByMapId(mapId);

      // 地図の画像をBase64エンコード
      final mapData = targetMap.toMap();
      if (targetMap.imagePath != null && targetMap.imagePath!.isNotEmpty) {
        try {
          final imageData = await _encodeImageToBase64(targetMap.imagePath!);
          mapData['imageData'] = imageData;
        } catch (e) {
          print('画像エンコードエラー (${targetMap.imagePath}): $e');
        }
      }

      // メモの画像をBase64エンコード
      final List<Map<String, dynamic>> memosWithImages = [];
      for (final memo in memos) {
        final memoData = memo.toMap();

        // メモに添付された画像をエンコード
        if (memo.imagePaths != null && memo.imagePaths!.isNotEmpty) {
          final List<String> encodedImages = [];
          for (final imagePath in memo.imagePaths!) {
            try {
              final imageData = await _encodeImageToBase64(imagePath);
              encodedImages.add(imageData);
            } catch (e) {
              print('メモ画像エンコードエラー ($imagePath): $e');
            }
          }
          if (encodedImages.isNotEmpty) {
            memoData['imageDataList'] = encodedImages;
          }
        }
        memosWithImages.add(memoData);
      }

      // バックアップデータを作成
      final backupData = {
        'version': '1.0.0',
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'map_backup',
        'data': {
          'map': mapData,
          'memos': memosWithImages,
        }
      };

      // JSONに変換
      final jsonString = jsonEncode(backupData);

      if (kIsWeb) {
        // Web環境では一時ファイルの代わりにJSON文字列を返す
        return jsonString;
      } else {
        // ネイティブ環境では一時ファイルに保存
        final directory = await getTemporaryDirectory();
        final fileName =
            '${_mapBackupFilePrefix}_${targetMap.title.replaceAll(RegExp(r'[^\w\d]'), '_')}.json';
        final file = File('${directory.path}/$fileName');
        await file.writeAsString(jsonString);
        return file.path;
      }
    } catch (e) {
      print('地図バックアップエクスポートエラー: $e');
      return null;
    }
  }

  /// バックアップファイルを共有
  static Future<bool> shareBackupFile() async {
    try {
      final result = await exportData();
      if (result != null) {
        if (kIsWeb) {
          // Web環境では直接ダウンロード
          _downloadJsonInWeb(result, _backupFileName);
          print('バックアップファイル「$_backupFileName」のダウンロードを開始しました');
          return true;
        } else {
          // ネイティブ環境では従来通り共有
          await Share.shareXFiles(
            [XFile(result)],
            text: 'ロケーションメモのバックアップファイル',
            subject: 'バックアップデータ',
          );
          return true;
        }
      }
      return false;
    } catch (e) {
      print('バックアップ共有エラー: $e');
      return false;
    }
  }

  /// 地図のバックアップファイルを共有
  static Future<bool> shareMapBackupFile(int mapId) async {
    try {
      final result = await exportMapData(mapId);
      if (result != null) {
        final maps = await DatabaseHelper.instance.readAllMaps();
        final targetMap = maps.firstWhere((map) => map.id == mapId);

        if (kIsWeb) {
          // Web環境では直接ダウンロード
          final fileName =
              '${_mapBackupFilePrefix}_${targetMap.title.replaceAll(RegExp(r'[^\w\d]'), '_')}.json';
          _downloadJsonInWeb(result, fileName);
          print('地図「${targetMap.title}」のバックアップファイル「$fileName」のダウンロードを開始しました');
          return true;
        } else {
          // ネイティブ環境では従来通り共有
          await Share.shareXFiles(
            [XFile(result)],
            text: '地図「${targetMap.title}」のバックアップファイル',
            subject: '地図バックアップデータ',
          );
          return true;
        }
      }
      return false;
    } catch (e) {
      print('地図バックアップ共有エラー: $e');
      return false;
    }
  }

  /// バックアップファイルからデータをインポート
  static Future<ImportResult> importData(BuildContext context) async {
    try {
      // ファイル選択
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        final jsonString = utf8.decode(bytes);

        return await _processImportData(jsonString, context);
      } else {
        return ImportResult(
          success: false,
          message: 'ファイルが選択されませんでした',
        );
      }
    } catch (e) {
      print('インポートエラー: $e');
      return ImportResult(
        success: false,
        message: 'インポート中にエラーが発生しました: $e',
      );
    }
  }

  /// 地図のバックアップファイルからデータをインポート
  static Future<ImportResult> importMapData(BuildContext context) async {
    try {
      // ファイル選択
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        final jsonString = utf8.decode(bytes);

        return await _processMapImportData(jsonString, context);
      } else {
        return ImportResult(
          success: false,
          message: 'ファイルが選択されませんでした',
        );
      }
    } catch (e) {
      print('地図インポートエラー: $e');
      return ImportResult(
        success: false,
        message: '地図インポート中にエラーが発生しました: $e',
      );
    }
  }

  /// 画像ファイルをBase64エンコード
  static Future<String> _encodeImageToBase64(String imagePath) async {
    if (kIsWeb) {
      // Web環境では画像パスが既にBase64データ形式の場合がある
      if (imagePath.startsWith('data:image')) {
        // Base64データURL形式の場合、Base64部分を抽出
        final base64Data = imagePath.split(',')[1];
        return base64Data;
      } else {
        throw Exception('Web環境で無効な画像パス形式です: $imagePath');
      }
    } else {
      // ネイティブ環境では従来通りファイルから読み込み
      final file = File(imagePath);
      if (!await file.exists()) {
        throw Exception('画像ファイルが見つかりません: $imagePath');
      }

      final bytes = await file.readAsBytes();
      return base64Encode(bytes);
    }
  }

  /// Base64データを画像ファイルとしてデコード
  static Future<String> _decodeBase64ToImage(
      String base64Data, String fileName) async {
    final bytes = base64Decode(base64Data);

    // アプリケーションドキュメントディレクトリを取得
    final directory = await getApplicationDocumentsDirectory();
    final mapsDir = Directory('${directory.path}/maps');

    // マップディレクトリが存在しない場合は作成
    if (!await mapsDir.exists()) {
      await mapsDir.create(recursive: true);
    }

    // ファイルを保存
    final file = File('${mapsDir.path}/$fileName');
    await file.writeAsBytes(bytes);

    return file.path;
  }

  /// Base64データをメモ画像ファイルとしてデコード
  static Future<String> _decodeBase64ToMemoImage(
      String base64Data, String fileName) async {
    final bytes = base64Decode(base64Data);

    // アプリケーションドキュメントディレクトリを取得
    final directory = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${directory.path}/memo_images');

    // メモ画像ディレクトリが存在しない場合は作成
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    // ファイルを保存
    final file = File('${imagesDir.path}/$fileName');
    await file.writeAsBytes(bytes);

    return file.path;
  }

  /// JSONデータを処理してデータベースにインポート
  static Future<ImportResult> _processImportData(
      String jsonString, BuildContext context) async {
    try {
      final Map<String, dynamic> backupData = jsonDecode(jsonString);

      // バックアップファイルの形式を確認
      if (!backupData.containsKey('data') ||
          !backupData['data'].containsKey('memos') ||
          !backupData['data'].containsKey('maps')) {
        return ImportResult(
          success: false,
          message: '無効なバックアップファイル形式です',
        );
      }

      final String backupType = backupData['type'] ?? 'full_backup';

      if (backupType != 'full_backup') {
        return ImportResult(
          success: false,
          message: 'このファイルは全体バックアップファイルではありません',
        );
      }

      final List<dynamic> memosJson = backupData['data']['memos'];
      final List<dynamic> mapsJson = backupData['data']['maps'];

      // 既存データがある場合は確認ダイアログを表示
      final existingMemos = await DatabaseHelper.instance.readAllMemos();
      final existingMaps = await DatabaseHelper.instance.readAllMaps();

      if (existingMemos.isNotEmpty || existingMaps.isNotEmpty) {
        final shouldOverwrite = await _showOverwriteDialog(context);
        if (!shouldOverwrite) {
          return ImportResult(
            success: false,
            message: 'インポートがキャンセルされました',
          );
        }

        // 既存データを削除
        await _clearAllData();
      }

      // 地図データをインポート
      int mapsImported = 0;
      for (final mapJson in mapsJson) {
        try {
          final mapData = Map<String, dynamic>.from(mapJson);

          // 画像データがある場合は保存
          String? imagePath;
          if (mapData.containsKey('imageData') &&
              mapData['imageData'] != null) {
            try {
              final fileName =
                  'imported_map_${DateTime.now().millisecondsSinceEpoch}.png';
              imagePath =
                  await _decodeBase64ToImage(mapData['imageData'], fileName);
            } catch (e) {
              print('画像デコードエラー: $e');
            }
          }

          // 地図を作成
          final mapInfo = MapInfo(
            title: mapData['title'] ?? '不明な地図',
            imagePath: imagePath,
          );
          await DatabaseHelper.instance.createMap(mapInfo);
          mapsImported++;
        } catch (e) {
          print('地図インポートエラー: $e');
        }
      }

      // メモデータをインポート
      int memosImported = 0;
      for (final memoJson in memosJson) {
        try {
          final memoData = Map<String, dynamic>.from(memoJson);

          // メモの画像データがある場合は復元
          List<String>? restoredImagePaths;
          if (memoData.containsKey('imageDataList') &&
              memoData['imageDataList'] != null) {
            final List<dynamic> imageDataList = memoData['imageDataList'];
            restoredImagePaths = [];

            for (int i = 0; i < imageDataList.length; i++) {
              try {
                final fileName =
                    'imported_memo_image_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
                final imagePath =
                    await _decodeBase64ToMemoImage(imageDataList[i], fileName);
                restoredImagePaths.add(imagePath);
              } catch (e) {
                print('メモ画像復元エラー: $e');
              }
            }
          }

          // imageDataListフィールドを削除してからMemoオブジェクトを作成
          memoData.remove('imageDataList');
          final memo = Memo.fromMap(memoData);

          // IDを除外して新しいレコードとして作成
          final newMemo = Memo(
            title: memo.title,
            content: memo.content,
            latitude: memo.latitude,
            longitude: memo.longitude,
            discoveryTime: memo.discoveryTime,
            discoverer: memo.discoverer,
            specimenNumber: memo.specimenNumber,
            category: memo.category,
            notes: memo.notes,
            pinNumber: memo.pinNumber,
            mapId: memo.mapId,
            audioPath: memo.audioPath,
            imagePaths: restoredImagePaths, // 復元された画像パスを設定
            layer: memo.layer, // レイヤー情報を復元
            // キノコ詳細情報も復元
            mushroomCapShape: memo.mushroomCapShape,
            mushroomCapColor: memo.mushroomCapColor,
            mushroomCapSurface: memo.mushroomCapSurface,
            mushroomCapSize: memo.mushroomCapSize,
            mushroomCapUnderStructure: memo.mushroomCapUnderStructure,
            mushroomGillFeature: memo.mushroomGillFeature,
            mushroomStemPresence: memo.mushroomStemPresence,
            mushroomStemShape: memo.mushroomStemShape,
            mushroomStemColor: memo.mushroomStemColor,
            mushroomStemSurface: memo.mushroomStemSurface,
            mushroomRingPresence: memo.mushroomRingPresence,
            mushroomVolvaPresence: memo.mushroomVolvaPresence,
            mushroomHabitat: memo.mushroomHabitat,
            mushroomGrowthPattern: memo.mushroomGrowthPattern,
          );
          await DatabaseHelper.instance.create(newMemo);
          memosImported++;
        } catch (e) {
          print('メモインポートエラー: $e');
        }
      }

      return ImportResult(
        success: true,
        message: 'インポートが完了しました\n地図: $mapsImported件\nメモ: $memosImported件',
        mapsImported: mapsImported,
        memosImported: memosImported,
      );
    } catch (e) {
      print('データ処理エラー: $e');
      return ImportResult(
        success: false,
        message: 'データの処理中にエラーが発生しました: $e',
      );
    }
  }

  /// 地図のJSONデータを処理してデータベースにインポート
  static Future<ImportResult> _processMapImportData(
      String jsonString, BuildContext context) async {
    try {
      final Map<String, dynamic> backupData = jsonDecode(jsonString);

      // バックアップファイルの形式を確認
      if (!backupData.containsKey('data') ||
          !backupData['data'].containsKey('map') ||
          !backupData['data'].containsKey('memos')) {
        return ImportResult(
          success: false,
          message: '無効な地図バックアップファイル形式です',
        );
      }

      final String backupType = backupData['type'] ?? 'unknown';

      if (backupType != 'map_backup') {
        return ImportResult(
          success: false,
          message: 'このファイルは地図バックアップファイルではありません',
        );
      }

      final Map<String, dynamic> mapJson = backupData['data']['map'];
      final List<dynamic> memosJson = backupData['data']['memos'];

      // 地図の重複確認
      final existingMaps = await DatabaseHelper.instance.readAllMaps();
      final mapTitle = mapJson['title'] ?? '不明な地図';

      final duplicateMap =
          existingMaps.where((map) => map.title == mapTitle).firstOrNull;

      if (duplicateMap != null) {
        final shouldOverwrite =
            await _showMapOverwriteDialog(context, mapTitle);
        if (!shouldOverwrite) {
          return ImportResult(
            success: false,
            message: 'インポートがキャンセルされました',
          );
        }

        // 既存の地図とそのメモを削除
        await DatabaseHelper.instance.deleteMap(duplicateMap.id!);
      }

      // 画像データがある場合は保存
      String? imagePath;
      if (mapJson.containsKey('imageData') && mapJson['imageData'] != null) {
        try {
          final fileName =
              'imported_map_${mapTitle.replaceAll(RegExp(r'[^\w\d]'), '_')}_${DateTime.now().millisecondsSinceEpoch}.png';
          imagePath =
              await _decodeBase64ToImage(mapJson['imageData'], fileName);
        } catch (e) {
          print('画像デコードエラー: $e');
        }
      }

      // 地図を作成
      final mapInfo = MapInfo(
        title: mapTitle,
        imagePath: imagePath,
      );
      final createdMap = await DatabaseHelper.instance.createMap(mapInfo);

      // メモデータをインポート
      int memosImported = 0;
      for (final memoJson in memosJson) {
        try {
          final memoData = Map<String, dynamic>.from(memoJson);

          // メモの画像データがある場合は復元
          List<String>? restoredImagePaths;
          if (memoData.containsKey('imageDataList') &&
              memoData['imageDataList'] != null) {
            final List<dynamic> imageDataList = memoData['imageDataList'];
            restoredImagePaths = [];

            for (int i = 0; i < imageDataList.length; i++) {
              try {
                final fileName =
                    'imported_memo_image_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
                final imagePath =
                    await _decodeBase64ToMemoImage(imageDataList[i], fileName);
                restoredImagePaths.add(imagePath);
              } catch (e) {
                print('メモ画像復元エラー: $e');
              }
            }
          }

          // imageDataListフィールドを削除してからMemoオブジェクトを作成
          memoData.remove('imageDataList');
          final memo = Memo.fromMap(memoData);

          // 新しい地図IDを設定してメモを作成
          final newMemo = Memo(
            title: memo.title,
            content: memo.content,
            latitude: memo.latitude,
            longitude: memo.longitude,
            discoveryTime: memo.discoveryTime,
            discoverer: memo.discoverer,
            specimenNumber: memo.specimenNumber,
            category: memo.category,
            notes: memo.notes,
            pinNumber: memo.pinNumber,
            mapId: createdMap.id,
            audioPath: memo.audioPath,
            imagePaths: restoredImagePaths, // 復元された画像パスを設定
            layer: memo.layer, // レイヤー情報を復元
            // キノコ詳細情報も復元
            mushroomCapShape: memo.mushroomCapShape,
            mushroomCapColor: memo.mushroomCapColor,
            mushroomCapSurface: memo.mushroomCapSurface,
            mushroomCapSize: memo.mushroomCapSize,
            mushroomCapUnderStructure: memo.mushroomCapUnderStructure,
            mushroomGillFeature: memo.mushroomGillFeature,
            mushroomStemPresence: memo.mushroomStemPresence,
            mushroomStemShape: memo.mushroomStemShape,
            mushroomStemColor: memo.mushroomStemColor,
            mushroomStemSurface: memo.mushroomStemSurface,
            mushroomRingPresence: memo.mushroomRingPresence,
            mushroomVolvaPresence: memo.mushroomVolvaPresence,
            mushroomHabitat: memo.mushroomHabitat,
            mushroomGrowthPattern: memo.mushroomGrowthPattern,
          );
          await DatabaseHelper.instance.create(newMemo);
          memosImported++;
        } catch (e) {
          print('メモインポートエラー: $e');
        }
      }

      return ImportResult(
        success: true,
        message: '地図「$mapTitle」のインポートが完了しました\nメモ: $memosImported件',
        mapsImported: 1,
        memosImported: memosImported,
      );
    } catch (e) {
      print('地図データ処理エラー: $e');
      return ImportResult(
        success: false,
        message: '地図データの処理中にエラーが発生しました: $e',
      );
    }
  }

  /// 上書き確認ダイアログを表示
  static Future<bool> _showOverwriteDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('⚠️ 既存データの上書き確認'),
            content: const Text(
              '既存のデータが見つかりました。\n'
              'インポートを続行すると、現在の全てのデータが削除され、'
              'バックアップファイルのデータに置き換えられます。\n\n'
              '続行しますか？',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('上書きする'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// 地図の上書き確認ダイアログを表示
  static Future<bool> _showMapOverwriteDialog(
      BuildContext context, String mapTitle) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('⚠️ 地図の上書き確認'),
            content: Text(
              '「$mapTitle」という名前の地図が既に存在します。\n'
              'インポートを続行すると、既存の地図とそのメモが削除され、'
              'バックアップファイルの地図に置き換えられます。\n\n'
              '続行しますか？',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('上書きする'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// 全データを削除
  static Future<void> _clearAllData() async {
    try {
      await DatabaseHelper.instance.deleteAllMemos();
      await DatabaseHelper.instance.deleteAllMaps();
    } catch (e) {
      print('データ削除エラー: $e');
    }
  }

  /// バックアップファイルの情報を取得
  static Future<BackupInfo?> getBackupInfo() async {
    try {
      final memos = await DatabaseHelper.instance.readAllMemos();
      final maps = await DatabaseHelper.instance.readAllMaps();

      return BackupInfo(
        totalMemos: memos.length,
        totalMaps: maps.length,
        lastBackupDate: null, // TODO: SharedPreferencesに保存
      );
    } catch (e) {
      print('バックアップ情報取得エラー: $e');
      return null;
    }
  }

  /// 特定の地図のバックアップ情報を取得
  static Future<MapBackupInfo?> getMapBackupInfo(int mapId) async {
    try {
      final maps = await DatabaseHelper.instance.readAllMaps();
      final targetMap = maps.firstWhere(
        (map) => map.id == mapId,
        orElse: () => throw Exception('指定された地図が見つかりません'),
      );

      final memos = await DatabaseHelper.instance.readMemosByMapId(mapId);

      return MapBackupInfo(
        mapId: mapId,
        mapTitle: targetMap.title,
        totalMemos: memos.length,
        hasImage:
            targetMap.imagePath != null && targetMap.imagePath!.isNotEmpty,
      );
    } catch (e) {
      print('地図バックアップ情報取得エラー: $e');
      return null;
    }
  }

  /// Web環境でのJSONファイルダウンロード
  static void _downloadJsonInWeb(String jsonContent, String fileName) {
    if (kIsWeb) {
      try {
        // Web環境でのダウンロード機能
        WebBackupService.downloadFile(jsonContent, fileName);
        print('Web環境でのバックアップファイルダウンロード完了: $fileName');
      } catch (e) {
        print('Web環境でのダウンロードエラー: $e');
        // フォールバック: コンソールに内容を出力
        print('バックアップデータ（ファイル名: $fileName）:');
        print(jsonContent);
        print('このデータをコピーして手動でファイルに保存してください。');
      }
    }
  }
}

/// インポート結果を表すクラス
class ImportResult {
  final bool success;
  final String message;
  final int? mapsImported;
  final int? memosImported;

  ImportResult({
    required this.success,
    required this.message,
    this.mapsImported,
    this.memosImported,
  });
}

/// バックアップ情報を表すクラス
class BackupInfo {
  final int totalMemos;
  final int totalMaps;
  final DateTime? lastBackupDate;

  BackupInfo({
    required this.totalMemos,
    required this.totalMaps,
    this.lastBackupDate,
  });
}

/// 地図のバックアップ情報を表すクラス
class MapBackupInfo {
  final int mapId;
  final String mapTitle;
  final int totalMemos;
  final bool hasImage;

  MapBackupInfo({
    required this.mapId,
    required this.mapTitle,
    required this.totalMemos,
    required this.hasImage,
  });
}
