import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/map_info.dart';
import '../models/memo.dart';
import 'database_helper.dart';
import '../utils/image_helper.dart';
import 'package:path_provider/path_provider.dart';

class FirebaseMapDownloadResult {
  final bool success;
  final String message;

  const FirebaseMapDownloadResult(
      {required this.success, required this.message});
}

class FirebaseRemoteMapSummary {
  final int mapId;
  final String title;
  final DateTime? updatedAt;
  final int memoCount;
  final String? imageUrl;

  const FirebaseRemoteMapSummary({
    required this.mapId,
    required this.title,
    this.updatedAt,
    required this.memoCount,
    this.imageUrl,
  });
}

class FirebaseMapUploadResult {
  final bool success;
  final String message;

  const FirebaseMapUploadResult({required this.success, required this.message});
}

class FirebaseMapService {
  FirebaseMapService._();

  static final FirebaseMapService instance = FirebaseMapService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static int _memoIdFallbackCounter = 0;

  Future<List<FirebaseRemoteMapSummary>> fetchRemoteMaps() async {
    final user = await _ensureSignedIn();
    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('maps')
        .get();

    final summaries = <FirebaseRemoteMapSummary>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final parsedId = int.tryParse(doc.id);
      final mapId =
          parsedId ?? (data['id'] is num ? (data['id'] as num).toInt() : null);
      if (mapId == null) {
        continue;
      }
      DateTime? updatedAt;
      final updatedRaw = data['updatedAt'];
      if (updatedRaw is Timestamp) {
        updatedAt = updatedRaw.toDate();
      } else if (updatedRaw is DateTime) {
        updatedAt = updatedRaw;
      }
      summaries.add(
        FirebaseRemoteMapSummary(
          mapId: mapId,
          title: data['title']?.toString() ?? 'Untitled map',
          updatedAt: updatedAt,
          memoCount: (data['memoCount'] as num?)?.toInt() ?? 0,
          imageUrl: data['imageUrl']?.toString(),
        ),
      );
    }
    return summaries;
  }

  Future<FirebaseMapDownloadResult> downloadMap(int mapId) async {
    try {
      final user = await _ensureSignedIn();
      final docRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('maps')
          .doc(mapId.toString());
      final doc = await docRef.get();

      if (!doc.exists) {
        return const FirebaseMapDownloadResult(
          success: false,
          message: 'Map not found on Firebase.',
        );
      }

      final data = doc.data()!;
      final existingMaps = await DatabaseHelper.instance.readAllMaps();
      MapInfo? existingMap;
      for (final map in existingMaps) {
        if (map.id == mapId) {
          existingMap = map;
          break;
        }
      }

      String? imagePath = existingMap?.imagePath;
      final imageUrl = data['imageUrl']?.toString();
      if (imageUrl != null && imageUrl.isNotEmpty) {
        final resolved = await _downloadBinaryFromUrl(
          imageUrl,
          defaultContentType: 'image/png',
        );
        if (resolved != null) {
          imagePath = await _saveMapImage(mapId, resolved);
        }
      }

      final memosSnapshot = await docRef.collection('memos').get();
      final memos = <Memo>[];
      for (final memoDoc in memosSnapshot.docs) {
        final memoData = memoDoc.data();

        final memoIdValue = memoData['id'];
        int? memoId;
        if (memoIdValue is int) {
          memoId = memoIdValue;
        } else if (memoIdValue is num) {
          memoId = memoIdValue.toInt();
        }

        final discoveryRaw = memoData['discoveryTime'];
        DateTime? discoveryTime;
        if (discoveryRaw is Timestamp) {
          discoveryTime = discoveryRaw.toDate();
        } else if (discoveryRaw is int) {
          discoveryTime = DateTime.fromMillisecondsSinceEpoch(discoveryRaw);
        } else if (discoveryRaw is num) {
          discoveryTime =
              DateTime.fromMillisecondsSinceEpoch(discoveryRaw.toInt());
        }

        final imageUrls = (memoData['imageUrls'] as List?)?.cast<String>() ??
            const <String>[];
        final localImagePaths = <String>[];
        for (var i = 0; i < imageUrls.length; i++) {
          final resolved = await _downloadBinaryFromUrl(
            imageUrls[i],
            defaultContentType: 'image/png',
          );
          if (resolved != null) {
            final saved = await _saveMemoImage(mapId, memoDoc.id, i, resolved);
            if (saved != null) {
              localImagePaths.add(saved);
            }
          }
        }

        String? audioPath;
        final audioUrl = memoData['audioUrl']?.toString();
        if (audioUrl != null && audioUrl.isNotEmpty) {
          final resolved = await _downloadBinaryFromUrl(
            audioUrl,
            defaultContentType: 'audio/aac',
          );
          if (resolved != null) {
            audioPath = await _saveMemoAudio(mapId, memoDoc.id, resolved);
          }
        }

        final memo = Memo(
          id: memoId,
          title: memoData['title']?.toString() ?? '',
          content: memoData['content']?.toString() ?? '',
          latitude: (memoData['latitude'] as num?)?.toDouble(),
          longitude: (memoData['longitude'] as num?)?.toDouble(),
          discoveryTime: discoveryTime,
          discoverer: memoData['discoverer']?.toString(),
          specimenNumber: memoData['specimenNumber']?.toString(),
          category: memoData['category']?.toString(),
          notes: memoData['notes']?.toString(),
          pinNumber: (memoData['pinNumber'] as num?)?.toInt(),
          mapId: mapId,
          audioPath: audioPath,
          imagePaths: localImagePaths.isEmpty ? null : localImagePaths,
          mushroomCapShape: memoData['mushroomCapShape']?.toString(),
          mushroomCapColor: memoData['mushroomCapColor']?.toString(),
          mushroomCapSurface: memoData['mushroomCapSurface']?.toString(),
          mushroomCapSize: memoData['mushroomCapSize']?.toString(),
          mushroomCapUnderStructure:
              memoData['mushroomCapUnderStructure']?.toString(),
          mushroomGillFeature: memoData['mushroomGillFeature']?.toString(),
          mushroomStemPresence: memoData['mushroomStemPresence']?.toString(),
          mushroomStemShape: memoData['mushroomStemShape']?.toString(),
          mushroomStemColor: memoData['mushroomStemColor']?.toString(),
          mushroomStemSurface: memoData['mushroomStemSurface']?.toString(),
          mushroomRingPresence: memoData['mushroomRingPresence']?.toString(),
          mushroomVolvaPresence: memoData['mushroomVolvaPresence']?.toString(),
          mushroomHabitat: memoData['mushroomHabitat']?.toString(),
          mushroomGrowthPattern: memoData['mushroomGrowthPattern']?.toString(),
          layer: (memoData['layer'] as num?)?.toInt(),
        );
        memos.add(memo);
      }

      final mapInfo = MapInfo(
        id: mapId,
        title: data['title']?.toString() ?? 'Untitled map',
        imagePath: imagePath,
      );
      await DatabaseHelper.instance.upsertMapInfo(mapInfo);
      await DatabaseHelper.instance.replaceMemosForMap(mapId, memos);

      return const FirebaseMapDownloadResult(
        success: true,
        message: 'Map downloaded from Firebase.',
      );
    } catch (error, stackTrace) {
      debugPrint('Firebase download failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return FirebaseMapDownloadResult(
        success: false,
        message: 'Download failed: $error',
      );
    }
  }

  Future<FirebaseMapUploadResult> uploadMap(MapInfo mapInfo) async {
    if (mapInfo.id == null) {
      return const FirebaseMapUploadResult(
        success: false,
        message: 'Map id is missing.',
      );
    }

    try {
      final user = await _ensureSignedIn();
      final memos = await DatabaseHelper.instance.readMemosByMapId(mapInfo.id!);

      final docRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('maps')
          .doc(mapInfo.id.toString());

      final mapStorageRoot =
          _storage.ref().child('users/${user.uid}/maps/${mapInfo.id}');
      await _clearStorageFolder(mapStorageRoot);

      String? imageUrl;
      final resolvedMapImage = await _resolveBinary(mapInfo.imagePath);
      if (resolvedMapImage != null) {
        final mapImageRef = mapStorageRoot.child(
          'base_map${_extensionForContent(resolvedMapImage.contentType)}',
        );
        await mapImageRef.putData(
          resolvedMapImage.bytes,
          SettableMetadata(contentType: resolvedMapImage.contentType),
        );
        imageUrl = await mapImageRef.getDownloadURL();
      }

      await docRef.set({
        'title': mapInfo.title,
        'imageUrl': imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
        'memoCount': memos.length,
      }, SetOptions(merge: true));

      await _replaceMemoDocuments(docRef, mapInfo, memos, user.uid);

      return const FirebaseMapUploadResult(
        success: true,
        message: 'Map was uploaded to Firebase.',
      );
    } catch (error, stackTrace) {
      debugPrint('Firebase upload failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return FirebaseMapUploadResult(
        success: false,
        message: 'Upload failed: $error',
      );
    }
  }

  Future<User> _ensureSignedIn() async {
    final current = _auth.currentUser;
    if (current != null) {
      return current;
    }

    final credential = await _auth.signInAnonymously();
    final user = credential.user;
    if (user == null) {
      throw StateError('Anonymous authentication failed.');
    }
    return user;
  }

  Future<void> _replaceMemoDocuments(
    DocumentReference<Map<String, dynamic>> mapDoc,
    MapInfo mapInfo,
    List<Memo> memos,
    String uid,
  ) async {
    final memosCollection = mapDoc.collection('memos');
    final existing = await memosCollection.get();
    for (final doc in existing.docs) {
      await doc.reference.delete();
    }

    for (final memo in memos) {
      final memoId = memo.id?.toString() ?? _temporaryMemoId();
      final memoDoc = memosCollection.doc(memoId);
      final uploadedAssets =
          await _uploadMemoAssets(uid, mapInfo.id!, memo.id, memo);
      await memoDoc.set({
        'id': memo.id,
        'title': memo.title,
        'content': memo.content,
        'latitude': memo.latitude,
        'longitude': memo.longitude,
        'discoveryTime': memo.discoveryTime?.millisecondsSinceEpoch,
        'discoverer': memo.discoverer,
        'specimenNumber': memo.specimenNumber,
        'category': memo.category,
        'notes': memo.notes,
        'pinNumber': memo.pinNumber,
        'mapId': memo.mapId,
        'audioUrl': uploadedAssets.audioUrl,
        'imageUrls': uploadedAssets.imageUrls,
        'mushroomCapShape': memo.mushroomCapShape,
        'mushroomCapColor': memo.mushroomCapColor,
        'mushroomCapSurface': memo.mushroomCapSurface,
        'mushroomCapSize': memo.mushroomCapSize,
        'mushroomCapUnderStructure': memo.mushroomCapUnderStructure,
        'mushroomGillFeature': memo.mushroomGillFeature,
        'mushroomStemPresence': memo.mushroomStemPresence,
        'mushroomStemShape': memo.mushroomStemShape,
        'mushroomStemColor': memo.mushroomStemColor,
        'mushroomStemSurface': memo.mushroomStemSurface,
        'mushroomRingPresence': memo.mushroomRingPresence,
        'mushroomVolvaPresence': memo.mushroomVolvaPresence,
        'mushroomHabitat': memo.mushroomHabitat,
        'mushroomGrowthPattern': memo.mushroomGrowthPattern,
        'layer': memo.layer,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<_UploadedAssets> _uploadMemoAssets(
    String uid,
    int mapId,
    int? memoId,
    Memo memo,
  ) async {
    final memoFolderName = memoId?.toString() ?? _temporaryMemoId();
    final baseRef =
        _storage.ref().child('users/$uid/maps/$mapId/memos/$memoFolderName');

    final imageUrls = <String>[];
    final imagePaths = memo.imagePaths ?? const <String>[];
    for (var i = 0; i < imagePaths.length; i++) {
      final asset = await _resolveBinary(imagePaths[i]);
      if (asset == null) {
        continue;
      }
      final imageRef = baseRef.child(
        'images/image_$i${_extensionForContent(asset.contentType)}',
      );
      await imageRef.putData(
        asset.bytes,
        SettableMetadata(contentType: asset.contentType),
      );
      final url = await imageRef.getDownloadURL();
      imageUrls.add(url);
    }

    String? audioUrl;
    if (memo.audioPath != null && memo.audioPath!.isNotEmpty) {
      final asset = await _resolveBinary(
        memo.audioPath!,
        defaultContentType: 'audio/aac',
      );
      if (asset != null) {
        final audioRef = baseRef.child(
          'audio/memo_audio${_extensionForContent(asset.contentType, fallback: '.aac')}',
        );
        await audioRef.putData(
          asset.bytes,
          SettableMetadata(contentType: asset.contentType),
        );
        audioUrl = await audioRef.getDownloadURL();
      }
    }

    return _UploadedAssets(imageUrls: imageUrls, audioUrl: audioUrl);
  }

  Future<_ResolvedBinary?> _resolveBinary(
    String? path, {
    String defaultContentType = 'image/png',
  }) async {
    if (path == null || path.isEmpty) {
      return null;
    }

    if (path.startsWith('data:')) {
      final commaIndex = path.indexOf(',');
      if (commaIndex == -1) {
        return null;
      }
      final meta = path.substring(0, commaIndex);
      final dataPart = path.substring(commaIndex + 1);
      final bytes = base64Decode(dataPart);
      final type = meta.split(';').first.split(':').last;
      return _ResolvedBinary(
        bytes: Uint8List.fromList(bytes),
        contentType: type.isEmpty ? defaultContentType : type,
      );
    }

    if (kIsWeb) {
      debugPrint('Cannot read local file path on the web: $path');
      return null;
    }

    final file = File(path);
    if (!await file.exists()) {
      return null;
    }

    final bytes = await file.readAsBytes();
    final lowerPath = path.toLowerCase();
    String contentType = defaultContentType;
    if (lowerPath.endsWith('.png')) {
      contentType = 'image/png';
    } else if (lowerPath.endsWith('.jpg') || lowerPath.endsWith('.jpeg')) {
      contentType = 'image/jpeg';
    } else if (lowerPath.endsWith('.heic')) {
      contentType = 'image/heic';
    } else if (lowerPath.endsWith('.aac')) {
      contentType = 'audio/aac';
    } else if (lowerPath.endsWith('.m4a')) {
      contentType = 'audio/m4a';
    } else if (lowerPath.endsWith('.mp3')) {
      contentType = 'audio/mpeg';
    }

    return _ResolvedBinary(bytes: bytes, contentType: contentType);
  }

  Future<void> _clearStorageFolder(Reference root) async {
    try {
      final listResult = await root.listAll();
      for (final item in listResult.items) {
        await item.delete();
      }
      for (final prefix in listResult.prefixes) {
        await _clearStorageFolder(prefix);
      }
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') {
        rethrow;
      }
    }
  }

  Future<_ResolvedBinary?> _downloadBinaryFromUrl(
    String url, {
    required String defaultContentType,
  }) async {
    try {
      final ref = _storage.refFromURL(url);
      final data = await ref.getData(20 * 1024 * 1024);
      if (data == null) {
        return null;
      }
      final metadata = await ref.getMetadata();
      final contentType = metadata.contentType ?? defaultContentType;
      return _ResolvedBinary(
        bytes: Uint8List.fromList(data),
        contentType: contentType,
      );
    } catch (error) {
      debugPrint('Failed to download binary from $url: $error');
      return null;
    }
  }

  Future<String?> _saveMapImage(int mapId, _ResolvedBinary asset) async {
    if (kIsWeb) {
      final encoded = base64Encode(asset.bytes);
      return 'data:${asset.contentType};base64,$encoded';
    } else {
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'firebase_map_${_sanitizeForFile(mapId.toString())}_${DateTime.now().millisecondsSinceEpoch}${_extensionForContent(asset.contentType, fallback: '.png')}';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(asset.bytes, flush: true);
      return file.path;
    }
  }

  Future<String?> _saveMemoImage(
    int mapId,
    String memoKey,
    int index,
    _ResolvedBinary asset,
  ) async {
    if (kIsWeb) {
      final encoded = base64Encode(asset.bytes);
      return 'data:${asset.contentType};base64,$encoded';
    } else {
      return await ImageHelper.saveImageBytes(asset.bytes);
    }
  }

  Future<String?> _saveMemoAudio(
    int mapId,
    String memoKey,
    _ResolvedBinary asset,
  ) async {
    if (kIsWeb) {
      final encoded = base64Encode(asset.bytes);
      return 'data:${asset.contentType};base64,$encoded';
    } else {
      final directory = await getApplicationDocumentsDirectory();
      final extension =
          _extensionForContent(asset.contentType, fallback: '.aac');
      final fileName =
          'firebase_audio_${_sanitizeForFile(mapId.toString())}_${_sanitizeForFile(memoKey)}$extension';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(asset.bytes, flush: true);
      return file.path;
    }
  }

  String _sanitizeForFile(String value) {
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  String _extensionForContent(String contentType, {String fallback = '.png'}) {
    switch (contentType) {
      case 'image/png':
        return '.png';
      case 'image/jpeg':
        return '.jpg';
      case 'image/heic':
        return '.heic';
      case 'audio/aac':
        return '.aac';
      case 'audio/m4a':
        return '.m4a';
      case 'audio/mpeg':
        return '.mp3';
      default:
        return fallback;
    }
  }

  String _temporaryMemoId() {
    _memoIdFallbackCounter++;
    return 'temp_${DateTime.now().microsecondsSinceEpoch}_$_memoIdFallbackCounter';
  }
}

class _ResolvedBinary {
  final Uint8List bytes;
  final String contentType;

  const _ResolvedBinary({required this.bytes, required this.contentType});
}

class _UploadedAssets {
  final List<String> imageUrls;
  final String? audioUrl;

  const _UploadedAssets({required this.imageUrls, this.audioUrl});
}
