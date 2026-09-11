import 'app_logger.dart';
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

  @visibleForTesting
  static bool isSupportedBackupJson(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map) return false;
      final version = decoded['version']?.toString() ?? '1.0.0';
      if (!version.startsWith('1.') && !version.startsWith('2.')) return false;
      final type = decoded['type']?.toString();
      final data = decoded['data'];
      if (data is! Map) return false;
      if (type == 'full_backup') {
        if (data['maps'] is! List || data['memos'] is! List) return false;
        _validateMediaPayloads(data);
        return true;
      }
      if (type == 'map_backup') {
        if (data['map'] is! Map || data['memos'] is! List) return false;
        _validateMediaPayloads({
          'maps': [data['map']],
          'memos': data['memos'],
        });
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

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
            final image = await _encodeMedia(
              map.imagePath!,
              fallbackMimeType: 'image/png',
            );
            mapData['imageData'] = image.data;
            mapData['imageMimeType'] = image.mimeType;
          } catch (e) {
            appLog('画像エンコードエラー (${map.imagePath}): $e');
            rethrow;
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
          final List<String> imageMimeTypes = [];
          for (final imagePath in memo.imagePaths!) {
            try {
              final image = await _encodeMedia(
                imagePath,
                fallbackMimeType: 'image/jpeg',
              );
              encodedImages.add(image.data);
              imageMimeTypes.add(image.mimeType);
            } catch (e) {
              appLog('メモ画像エンコードエラー ($imagePath): $e');
              rethrow;
            }
          }
          if (encodedImages.isNotEmpty) {
            memoData['imageDataList'] = encodedImages;
            memoData['imageMimeTypes'] = imageMimeTypes;
          }
        }
        if (memo.audioPath != null && memo.audioPath!.isNotEmpty) {
          try {
            final audio = await _encodeMedia(
              memo.audioPath!,
              fallbackMimeType: 'audio/aac',
            );
            memoData['audioData'] = audio.data;
            memoData['audioMimeType'] = audio.mimeType;
          } catch (error) {
            appLog('音声エンコードエラー: ${error.runtimeType}');
            rethrow;
          }
        }
        memosWithImages.add(memoData);
      }

      // バックアップデータを作成
      final backupData = {
        'version': '2.0.0',
        'schemaVersion': 2,
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'full_backup',
        'data': {
          'memos': memosWithImages,
          'maps': mapsWithImages,
          'idMap': {
            'maps': [
              for (final map in maps) {'localId': map.id, 'syncId': map.syncId},
            ],
          },
        },
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
      appLog('バックアップエクスポートエラー: $e');
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
          final image = await _encodeMedia(
            targetMap.imagePath!,
            fallbackMimeType: 'image/png',
          );
          mapData['imageData'] = image.data;
          mapData['imageMimeType'] = image.mimeType;
        } catch (e) {
          appLog('画像エンコードエラー (${targetMap.imagePath}): $e');
          rethrow;
        }
      }

      // メモの画像をBase64エンコード
      final List<Map<String, dynamic>> memosWithImages = [];
      for (final memo in memos) {
        final memoData = memo.toMap();

        // メモに添付された画像をエンコード
        if (memo.imagePaths != null && memo.imagePaths!.isNotEmpty) {
          final List<String> encodedImages = [];
          final List<String> imageMimeTypes = [];
          for (final imagePath in memo.imagePaths!) {
            try {
              final image = await _encodeMedia(
                imagePath,
                fallbackMimeType: 'image/jpeg',
              );
              encodedImages.add(image.data);
              imageMimeTypes.add(image.mimeType);
            } catch (e) {
              appLog('メモ画像エンコードエラー ($imagePath): $e');
              rethrow;
            }
          }
          if (encodedImages.isNotEmpty) {
            memoData['imageDataList'] = encodedImages;
            memoData['imageMimeTypes'] = imageMimeTypes;
          }
        }
        if (memo.audioPath != null && memo.audioPath!.isNotEmpty) {
          try {
            final audio = await _encodeMedia(
              memo.audioPath!,
              fallbackMimeType: 'audio/aac',
            );
            memoData['audioData'] = audio.data;
            memoData['audioMimeType'] = audio.mimeType;
          } catch (error) {
            appLog('音声エンコードエラー: ${error.runtimeType}');
            rethrow;
          }
        }
        memosWithImages.add(memoData);
      }

      // バックアップデータを作成
      final backupData = {
        'version': '2.0.0',
        'schemaVersion': 2,
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'map_backup',
        'data': {
          'map': mapData,
          'memos': memosWithImages,
          'idMap': {
            'map': {'localId': targetMap.id, 'syncId': targetMap.syncId},
          },
        },
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
      appLog('地図バックアップエクスポートエラー: $e');
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
          appLog('バックアップファイル「$_backupFileName」のダウンロードを開始しました');
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
      appLog('バックアップ共有エラー: $e');
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
          appLog('地図「${targetMap.title}」のバックアップファイル「$fileName」のダウンロードを開始しました');
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
      appLog('地図バックアップ共有エラー: $e');
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
      if (!context.mounted) {
        return ImportResult(success: false, message: 'インポートをキャンセルしました');
      }

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        final jsonString = utf8.decode(bytes);

        return await _processImportData(jsonString, context);
      } else {
        return ImportResult(success: false, message: 'ファイルが選択されませんでした');
      }
    } catch (e) {
      appLog('インポートエラー: $e');
      return ImportResult(
        success: false,
        message: 'インポートできませんでした。ファイルを確認してください。',
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
      if (!context.mounted) {
        return ImportResult(success: false, message: 'インポートをキャンセルしました');
      }

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        final jsonString = utf8.decode(bytes);

        return await _processMapImportData(jsonString, context);
      } else {
        return ImportResult(success: false, message: 'ファイルが選択されませんでした');
      }
    } catch (e) {
      appLog('地図インポートエラー: $e');
      return ImportResult(
        success: false,
        message: '地図をインポートできませんでした。ファイルを確認してください。',
      );
    }
  }

  static Future<_EncodedMedia> _encodeMedia(
    String path, {
    required String fallbackMimeType,
  }) async {
    if (path.startsWith('data:')) {
      final comma = path.indexOf(',');
      if (comma < 0) throw const FormatException('Invalid data URL');
      final metadata = path.substring(5, comma);
      final mime = metadata.split(';').first;
      final data = path.substring(comma + 1);
      base64Decode(data);
      return _EncodedMedia(
        data: data,
        mimeType: mime.isEmpty ? fallbackMimeType : mime,
      );
    }
    if (kIsWeb) {
      throw const FormatException('Web media must be a data URL');
    }
    final file = File(path);
    if (!await file.exists()) throw const FileSystemException('Media missing');
    return _EncodedMedia(
      data: base64Encode(await file.readAsBytes()),
      mimeType: _mimeTypeForPath(path, fallbackMimeType),
    );
  }

  static String _mimeTypeForPath(String path, String fallback) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.aac')) return 'audio/aac';
    return fallback;
  }

  /// Base64データを画像ファイルとしてデコード
  static Future<String> _decodeBase64ToImage(
    String base64Data,
    String fileName, {
    String mimeType = 'image/png',
  }) async {
    final bytes = base64Decode(base64Data);
    if (kIsWeb) return 'data:$mimeType;base64,$base64Data';

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
    String base64Data,
    String fileName, {
    String mimeType = 'image/jpeg',
  }) async {
    final bytes = base64Decode(base64Data);
    if (kIsWeb) return 'data:$mimeType;base64,$base64Data';

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

  static Future<String> _decodeBase64ToAudio(
    String base64Data,
    String fileName, {
    String mimeType = 'audio/aac',
  }) async {
    final bytes = base64Decode(base64Data);
    if (kIsWeb) return 'data:$mimeType;base64,$base64Data';
    final directory = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${directory.path}/memo_audio');
    if (!await audioDir.exists()) await audioDir.create(recursive: true);
    final file = File('${audioDir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  static Future<ImportResult> _restoreFullBackup(
    Map<String, dynamic> backupData,
  ) async {
    final createdFiles = <String>[];
    try {
      final data = backupData['data'];
      if (data is! Map || data['maps'] is! List || data['memos'] is! List) {
        throw const FormatException('Invalid backup structure');
      }
      final version = backupData['version']?.toString() ?? '1.0.0';
      if (!version.startsWith('1.') && !version.startsWith('2.')) {
        throw const FormatException('Unsupported backup version');
      }
      _validateMediaPayloads(data);

      final restoredMaps = <MapInfo>[];
      final sourceMapIds = <int>{};
      var sequence = 0;
      for (final raw in data['maps'] as List) {
        if (raw is! Map) throw const FormatException('Invalid map record');
        final mapData = Map<String, dynamic>.from(raw);
        if (mapData['title'] is! String) {
          throw const FormatException('Map title is missing');
        }
        final original = MapInfo.fromMap(mapData);
        if (original.id != null) sourceMapIds.add(original.id!);
        String? imagePath;
        final imageData = mapData['imageData']?.toString();
        if (imageData != null && imageData.isNotEmpty) {
          final mime = mapData['imageMimeType']?.toString() ?? 'image/png';
          imagePath = await _decodeBase64ToImage(
            imageData,
            'restored_map_${DateTime.now().microsecondsSinceEpoch}_${sequence++}${_extensionForMime(mime)}',
            mimeType: mime,
          );
          if (!kIsWeb) createdFiles.add(imagePath);
        }
        restoredMaps.add(
          MapInfo(
            id: original.id,
            title: original.title,
            imagePath: imagePath,
            syncId: original.syncId,
            updatedAt: original.updatedAt,
          ),
        );
      }

      final restoredMemos = <Memo>[];
      for (final raw in data['memos'] as List) {
        if (raw is! Map) throw const FormatException('Invalid memo record');
        final memoData = Map<String, dynamic>.from(raw);
        if (memoData['title'] is! String || memoData['content'] is! String) {
          throw const FormatException('Memo fields are missing');
        }
        final mapId = (memoData['mapId'] as num?)?.toInt();
        if (mapId != null && !sourceMapIds.contains(mapId)) {
          throw const FormatException('Memo refers to an unknown map');
        }

        final imageDataList = memoData['imageDataList'];
        final mimeTypes = memoData['imageMimeTypes'];
        final restoredImages = <String>[];
        if (imageDataList is List) {
          for (var i = 0; i < imageDataList.length; i++) {
            final encoded = imageDataList[i].toString();
            final mime = mimeTypes is List && i < mimeTypes.length
                ? mimeTypes[i].toString()
                : 'image/jpeg';
            final path = await _decodeBase64ToMemoImage(
              encoded,
              'restored_memo_${DateTime.now().microsecondsSinceEpoch}_${sequence++}${_extensionForMime(mime)}',
              mimeType: mime,
            );
            restoredImages.add(path);
            if (!kIsWeb) createdFiles.add(path);
          }
        }

        var audioPath = memoData['audioPath']?.toString();
        final audioData = memoData['audioData']?.toString();
        if (audioData != null && audioData.isNotEmpty) {
          final mime = memoData['audioMimeType']?.toString() ?? 'audio/aac';
          audioPath = await _decodeBase64ToAudio(
            audioData,
            'restored_audio_${DateTime.now().microsecondsSinceEpoch}_${sequence++}${_extensionForMime(mime)}',
            mimeType: mime,
          );
          if (!kIsWeb) createdFiles.add(audioPath);
        }

        memoData
          ..remove('imageDataList')
          ..remove('imageMimeTypes')
          ..remove('audioData')
          ..remove('audioMimeType')
          ..['mapId'] = mapId
          ..['audioPath'] = audioPath
          ..['imagePaths'] = restoredImages.isEmpty
              ? null
              : jsonEncode(restoredImages);
        restoredMemos.add(Memo.fromMap(memoData));
      }

      await DatabaseHelper.instance.replaceAllDataAtomically(
        restoredMaps,
        restoredMemos,
      );
      return ImportResult(
        success: true,
        message:
            '復元が完了しました\n地図: ${restoredMaps.length}件\nメモ: ${restoredMemos.length}件',
        mapsImported: restoredMaps.length,
        memosImported: restoredMemos.length,
      );
    } catch (error, stackTrace) {
      appLog('Validated restore failed: ${error.runtimeType}', stackTrace);
      if (!kIsWeb) {
        for (final path in createdFiles) {
          try {
            final file = File(path);
            if (await file.exists()) await file.delete();
          } catch (_) {
            // Best-effort cleanup. Original database data is still intact.
          }
        }
      }
      return ImportResult(
        success: false,
        message: 'バックアップを復元できませんでした。ファイルが壊れていないか確認してください。',
      );
    }
  }

  static void _validateMediaPayloads(Map<dynamic, dynamic> data) {
    const maxAssetBytes = 25 * 1024 * 1024;
    const maxTotalBytes = 250 * 1024 * 1024;
    var total = 0;
    void validate(dynamic value, dynamic mime, String expectedPrefix) {
      if (value == null) return;
      if (value is! String) throw const FormatException('Invalid media data');
      if (mime != null &&
          (mime is! String || !mime.toLowerCase().startsWith(expectedPrefix))) {
        throw const FormatException('Invalid media type');
      }
      final bytes = base64Decode(value);
      if (bytes.length > maxAssetBytes) {
        throw const FormatException('Media item is too large');
      }
      total += bytes.length;
      if (total > maxTotalBytes) {
        throw const FormatException('Backup media is too large');
      }
    }

    for (final raw in data['maps'] as List) {
      if (raw is Map) {
        validate(raw['imageData'], raw['imageMimeType'], 'image/');
      }
    }
    for (final raw in data['memos'] as List) {
      if (raw is! Map) continue;
      final images = raw['imageDataList'];
      final imageMimes = raw['imageMimeTypes'];
      if (images is List) {
        if (imageMimes != null && imageMimes is! List) {
          throw const FormatException('Invalid image MIME list');
        }
        if (imageMimes is List && imageMimes.length != images.length) {
          throw const FormatException('Image MIME count mismatch');
        }
        for (var index = 0; index < images.length; index++) {
          validate(
            images[index],
            imageMimes is List ? imageMimes[index] : null,
            'image/',
          );
        }
      } else if (images != null) {
        throw const FormatException('Invalid image list');
      }
      validate(raw['audioData'], raw['audioMimeType'], 'audio/');
    }
  }

  static String _extensionForMime(String mime) {
    return switch (mime.toLowerCase()) {
      'image/jpeg' => '.jpg',
      'image/webp' => '.webp',
      'audio/mp4' || 'audio/m4a' => '.m4a',
      'audio/mpeg' => '.mp3',
      'audio/wav' => '.wav',
      'audio/aac' => '.aac',
      _ => '.png',
    };
  }

  static Future<ImportResult> _restoreMapBackup(
    Map<String, dynamic> mapData,
    List<dynamic> memoRecords,
    BuildContext context,
  ) async {
    final createdFiles = <String>[];
    int? createdMapId;
    try {
      if (mapData['title'] is! String) {
        throw const FormatException('Map title is missing');
      }
      _validateMediaPayloads({
        'maps': [mapData],
        'memos': memoRecords,
      });
      final title = mapData['title'] as String;
      final maps = await DatabaseHelper.instance.readAllMaps();
      if (!context.mounted) {
        return ImportResult(success: false, message: 'インポートをキャンセルしました');
      }
      final duplicate = maps.where((map) => map.title == title).firstOrNull;
      if (duplicate != null && !await _showMapOverwriteDialog(context, title)) {
        return ImportResult(success: false, message: 'インポートがキャンセルされました');
      }

      String? imagePath;
      final encodedMap = mapData['imageData']?.toString();
      if (encodedMap != null && encodedMap.isNotEmpty) {
        final mime = mapData['imageMimeType']?.toString() ?? 'image/png';
        imagePath = await _decodeBase64ToImage(
          encodedMap,
          'restored_map_${DateTime.now().microsecondsSinceEpoch}${_extensionForMime(mime)}',
          mimeType: mime,
        );
        if (!kIsWeb) createdFiles.add(imagePath);
      }

      final createdMap = await DatabaseHelper.instance.createMap(
        MapInfo(title: title, imagePath: imagePath),
      );
      createdMapId = createdMap.id;
      if (createdMapId == null) throw StateError('Map id was not allocated');

      var sequence = 0;
      for (final raw in memoRecords) {
        if (raw is! Map) throw const FormatException('Invalid memo record');
        final memoData = Map<String, dynamic>.from(raw);
        if (memoData['title'] is! String || memoData['content'] is! String) {
          throw const FormatException('Memo fields are missing');
        }
        final restoredImages = <String>[];
        final images = memoData['imageDataList'];
        final mimes = memoData['imageMimeTypes'];
        if (images is List) {
          for (var i = 0; i < images.length; i++) {
            final mime = mimes is List && i < mimes.length
                ? mimes[i].toString()
                : 'image/jpeg';
            final path = await _decodeBase64ToMemoImage(
              images[i].toString(),
              'restored_memo_${DateTime.now().microsecondsSinceEpoch}_${sequence++}${_extensionForMime(mime)}',
              mimeType: mime,
            );
            restoredImages.add(path);
            if (!kIsWeb) createdFiles.add(path);
          }
        }
        String? audioPath;
        final audioData = memoData['audioData']?.toString();
        if (audioData != null && audioData.isNotEmpty) {
          final mime = memoData['audioMimeType']?.toString() ?? 'audio/aac';
          audioPath = await _decodeBase64ToAudio(
            audioData,
            'restored_audio_${DateTime.now().microsecondsSinceEpoch}_${sequence++}${_extensionForMime(mime)}',
            mimeType: mime,
          );
          if (!kIsWeb) createdFiles.add(audioPath);
        }
        memoData
          ..remove('id')
          ..remove('syncId')
          ..remove('updatedAt')
          ..remove('imageDataList')
          ..remove('imageMimeTypes')
          ..remove('audioData')
          ..remove('audioMimeType')
          ..['mapId'] = createdMapId
          ..['audioPath'] = audioPath
          ..['imagePaths'] = restoredImages.isEmpty
              ? null
              : jsonEncode(restoredImages);
        await DatabaseHelper.instance.create(Memo.fromMap(memoData));
      }
      if (duplicate?.id != null) {
        await DatabaseHelper.instance.deleteMap(duplicate!.id!);
      }
      return ImportResult(
        success: true,
        message: '地図「$title」を復元しました\nメモ: ${memoRecords.length}件',
        mapsImported: 1,
        memosImported: memoRecords.length,
      );
    } catch (error, stackTrace) {
      appLog('Map restore failed: ${error.runtimeType}', stackTrace);
      if (createdMapId != null) {
        try {
          await DatabaseHelper.instance.deleteMap(createdMapId);
        } catch (_) {}
      }
      if (!kIsWeb) {
        for (final path in createdFiles) {
          try {
            final file = File(path);
            if (await file.exists()) await file.delete();
          } catch (_) {}
        }
      }
      return ImportResult(
        success: false,
        message: '地図を復元できませんでした。ファイルが壊れていないか確認してください。',
      );
    }
  }

  /// JSONデータを処理してデータベースにインポート
  static Future<ImportResult> _processImportData(
    String jsonString,
    BuildContext context,
  ) async {
    try {
      final Map<String, dynamic> backupData = jsonDecode(jsonString);

      // バックアップファイルの形式を確認
      if (!backupData.containsKey('data') ||
          !backupData['data'].containsKey('memos') ||
          !backupData['data'].containsKey('maps')) {
        return ImportResult(success: false, message: '無効なバックアップファイル形式です');
      }

      final String backupType = backupData['type'] ?? 'full_backup';

      if (backupType != 'full_backup') {
        return ImportResult(
          success: false,
          message: 'このファイルは全体バックアップファイルではありません',
        );
      }

      // All normal v1/v2 backups use the validated, atomic restore path. The
      // sentinel only keeps malformed legacy data away from destructive work.
      if (_usesAtomicRestore(backupData)) {
        final existingMemos = await DatabaseHelper.instance.readAllMemos();
        final existingMaps = await DatabaseHelper.instance.readAllMaps();
        if (!context.mounted) {
          return ImportResult(success: false, message: 'インポートをキャンセルしました');
        }
        if ((existingMemos.isNotEmpty || existingMaps.isNotEmpty) &&
            !await _showOverwriteDialog(context)) {
          return ImportResult(success: false, message: 'インポートがキャンセルされました');
        }
        return _restoreFullBackup(backupData);
      }

      final List<dynamic> memosJson = backupData['data']['memos'];
      final List<dynamic> mapsJson = backupData['data']['maps'];

      // 既存データがある場合は確認ダイアログを表示
      final existingMemos = await DatabaseHelper.instance.readAllMemos();
      final existingMaps = await DatabaseHelper.instance.readAllMaps();
      if (!context.mounted) {
        return ImportResult(success: false, message: 'インポートをキャンセルしました');
      }

      if (existingMemos.isNotEmpty || existingMaps.isNotEmpty) {
        final shouldOverwrite = await _showOverwriteDialog(context);
        if (!shouldOverwrite) {
          return ImportResult(success: false, message: 'インポートがキャンセルされました');
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
              imagePath = await _decodeBase64ToImage(
                mapData['imageData'],
                fileName,
              );
            } catch (e) {
              appLog('画像デコードエラー: $e');
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
          appLog('地図インポートエラー: $e');
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
                final imagePath = await _decodeBase64ToMemoImage(
                  imageDataList[i],
                  fileName,
                );
                restoredImagePaths.add(imagePath);
              } catch (e) {
                appLog('メモ画像復元エラー: $e');
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
          appLog('メモインポートエラー: $e');
        }
      }

      return ImportResult(
        success: true,
        message: 'インポートが完了しました\n地図: $mapsImported件\nメモ: $memosImported件',
        mapsImported: mapsImported,
        memosImported: memosImported,
      );
    } catch (e) {
      appLog('データ処理エラー: $e');
      return ImportResult(
        success: false,
        message: 'データを復元できませんでした。ファイルを確認してください。',
      );
    }
  }

  /// 地図のJSONデータを処理してデータベースにインポート
  static Future<ImportResult> _processMapImportData(
    String jsonString,
    BuildContext context,
  ) async {
    try {
      final Map<String, dynamic> backupData = jsonDecode(jsonString);

      // バックアップファイルの形式を確認
      if (!backupData.containsKey('data') ||
          !backupData['data'].containsKey('map') ||
          !backupData['data'].containsKey('memos')) {
        return ImportResult(success: false, message: '無効な地図バックアップファイル形式です');
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

      if (_usesAtomicRestore(backupData)) {
        return _restoreMapBackup(mapJson, memosJson, context);
      }

      // 地図の重複確認
      final existingMaps = await DatabaseHelper.instance.readAllMaps();
      if (!context.mounted) {
        return ImportResult(success: false, message: 'インポートをキャンセルしました');
      }
      final mapTitle = mapJson['title'] ?? '不明な地図';

      final duplicateMap = existingMaps
          .where((map) => map.title == mapTitle)
          .firstOrNull;

      if (duplicateMap != null) {
        final shouldOverwrite = await _showMapOverwriteDialog(
          context,
          mapTitle,
        );
        if (!shouldOverwrite) {
          return ImportResult(success: false, message: 'インポートがキャンセルされました');
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
          imagePath = await _decodeBase64ToImage(
            mapJson['imageData'],
            fileName,
          );
        } catch (e) {
          appLog('画像デコードエラー: $e');
        }
      }

      // 地図を作成
      final mapInfo = MapInfo(title: mapTitle, imagePath: imagePath);
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
                final imagePath = await _decodeBase64ToMemoImage(
                  imageDataList[i],
                  fileName,
                );
                restoredImagePaths.add(imagePath);
              } catch (e) {
                appLog('メモ画像復元エラー: $e');
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
          appLog('メモインポートエラー: $e');
        }
      }

      return ImportResult(
        success: true,
        message: '地図「$mapTitle」のインポートが完了しました\nメモ: $memosImported件',
        mapsImported: 1,
        memosImported: memosImported,
      );
    } catch (e) {
      appLog('地図データ処理エラー: $e');
      return ImportResult(
        success: false,
        message: '地図データを復元できませんでした。ファイルを確認してください。',
      );
    }
  }

  /// 上書き確認ダイアログを表示
  // v1も含め、すべてのバックアップを検証・ステージング・一括確定経路へ通す。
  // 旧逐次復元コードは既存形式の参照用に残しているが、実行は許可しない。
  static bool _usesAtomicRestore(Map<String, dynamic> _) => true;

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
    BuildContext context,
    String mapTitle,
  ) async {
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
      appLog('データ削除エラー: $e');
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
      appLog('バックアップ情報取得エラー: $e');
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
      appLog('地図バックアップ情報取得エラー: $e');
      return null;
    }
  }

  /// Web環境でのJSONファイルダウンロード
  static void _downloadJsonInWeb(String jsonContent, String fileName) {
    if (kIsWeb) {
      try {
        // Web環境でのダウンロード機能
        WebBackupService.downloadFile(jsonContent, fileName);
        appLog('Web環境でのバックアップファイルダウンロード完了: $fileName');
      } catch (e) {
        appLog('Web backup download failed: ${e.runtimeType}');
      }
    }
  }
}

class _EncodedMedia {
  const _EncodedMedia({required this.data, required this.mimeType});

  final String data;
  final String mimeType;
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
