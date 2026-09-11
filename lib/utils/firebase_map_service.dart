import 'app_logger.dart';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/map_info.dart';
import '../models/memo.dart';
import 'collaboration_metadata_store.dart';
import 'database_helper.dart';
import 'sync_queue.dart';
import '../utils/image_helper.dart';
import 'package:path_provider/path_provider.dart';

class FirebaseMapDownloadResult {
  final bool success;
  final String message;
  final int? localMapId;

  const FirebaseMapDownloadResult({
    required this.success,
    required this.message,
    this.localMapId,
  });
}

class FirebaseRemoteMapSummary {
  final int mapId;
  final String remoteMapId;
  final String title;
  final DateTime? updatedAt;
  final int memoCount;
  final String? imageUrl;
  final String ownerId;
  final String? ownerEmail;
  final bool isShared;

  const FirebaseRemoteMapSummary({
    required this.mapId,
    required this.remoteMapId,
    required this.title,
    this.updatedAt,
    required this.memoCount,
    this.imageUrl,
    required this.ownerId,
    this.ownerEmail,
    required this.isShared,
  });
}

class FirebaseMapUploadResult {
  final bool success;
  final String message;
  final String? remoteMapId;

  const FirebaseMapUploadResult({
    required this.success,
    required this.message,
    this.remoteMapId,
  });
}

class FirebaseMemoChangeSet {
  const FirebaseMemoChangeSet({
    this.upserts = const <Memo>[],
    this.deletedSyncIds = const <String>{},
  });

  final List<Memo> upserts;
  final Set<String> deletedSyncIds;
}

class FirebaseMapShareResult {
  final bool success;
  final String message;

  const FirebaseMapShareResult({required this.success, required this.message});
}

class FirebaseSharedUser {
  final String uid;
  final String email;
  final String? displayName;

  const FirebaseSharedUser({
    required this.uid,
    required this.email,
    this.displayName,
  });
}

class FirebaseMapService {
  FirebaseMapService._();

  static final FirebaseMapService instance = FirebaseMapService._();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseStorage get _storage => FirebaseStorage.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  static int _memoIdFallbackCounter = 0;

  @visibleForTesting
  static MapInfo? resolveExistingLocalMap({
    required Iterable<MapInfo> maps,
    required String remoteSyncId,
    required String remoteMapId,
    int? associatedLocalMapId,
  }) {
    if (associatedLocalMapId != null) {
      for (final map in maps) {
        if (map.id == associatedLocalMapId) return map;
      }
    }
    for (final map in maps) {
      if (map.syncId == remoteSyncId || map.syncId == remoteMapId) return map;
    }
    return null;
  }

  DocumentReference<Map<String, dynamic>> _mapDocument(
    String uid,
    int mapId, {
    String? remoteMapId,
  }) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('maps')
        .doc(remoteMapId ?? mapId.toString());
  }

  CollectionReference<Map<String, dynamic>> _memoCollection(
    String uid,
    int mapId, {
    String? remoteMapId,
  }) {
    return _mapDocument(
      uid,
      mapId,
      remoteMapId: remoteMapId,
    ).collection('memos');
  }

  Future<List<FirebaseRemoteMapSummary>> fetchRemoteMaps() async {
    final user = _requireUser();

    final summaries = <FirebaseRemoteMapSummary>[];

    final ownSnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('maps')
        .get();

    for (final doc in ownSnapshot.docs) {
      final data = doc.data();
      final parsedId = int.tryParse(doc.id);
      final mapId =
          parsedId ?? (data['id'] is num ? (data['id'] as num).toInt() : null);
      if (mapId == null) {
        continue;
      }
      final updatedAt = _parseTimestamp(data['updatedAt']);
      final ownerEmail = data['ownerEmail']?.toString() ?? user.email;
      summaries.add(
        FirebaseRemoteMapSummary(
          mapId: mapId,
          remoteMapId: doc.id,
          title: data['title']?.toString() ?? '名称未設定の地図',
          updatedAt: updatedAt,
          memoCount: (data['memoCount'] as num?)?.toInt() ?? 0,
          imageUrl: data['imageUrl']?.toString(),
          ownerId: user.uid,
          ownerEmail: ownerEmail,
          isShared: false,
        ),
      );
    }

    final sharedSnapshot = await _firestore
        .collectionGroup('maps')
        .where('sharedWith', arrayContains: user.uid)
        .get();

    for (final doc in sharedSnapshot.docs) {
      final data = doc.data();
      final parsedId = int.tryParse(doc.id);
      final mapId =
          parsedId ?? (data['id'] is num ? (data['id'] as num).toInt() : null);
      if (mapId == null) {
        continue;
      }
      final ownerId =
          data['ownerId']?.toString() ?? doc.reference.parent.parent?.id;
      if (ownerId == null || ownerId == user.uid) {
        continue;
      }
      final updatedAt = _parseTimestamp(data['updatedAt']);
      var ownerEmail = data['ownerEmail']?.toString();
      if (ownerEmail == null || ownerEmail.isEmpty) {
        final profile = await _fetchUserProfile(ownerId);
        ownerEmail = profile?.email;
      }
      summaries.add(
        FirebaseRemoteMapSummary(
          mapId: mapId,
          remoteMapId: doc.id,
          title: data['title']?.toString() ?? '名称未設定の地図',
          updatedAt: updatedAt,
          memoCount: (data['memoCount'] as num?)?.toInt() ?? 0,
          imageUrl: data['imageUrl']?.toString(),
          ownerId: ownerId,
          ownerEmail: ownerEmail,
          isShared: true,
        ),
      );
    }

    summaries.sort((a, b) {
      final aTime = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    return summaries;
  }

  Future<FirebaseMapDownloadResult> downloadMap(
    int mapId, {
    String? ownerUid,
    String? remoteMapId,
    bool importAsCopy = false,
  }) async {
    int? createdLocalMapId;
    final downloadedLocalFiles = <String>[];
    try {
      final user = _requireUser();
      final targetOwnerId = ownerUid ?? user.uid;

      final docRef = _firestore
          .collection('users')
          .doc(targetOwnerId)
          .collection('maps')
          .doc(remoteMapId ?? mapId.toString());
      final doc = await docRef.get();

      if (!doc.exists) {
        return const FirebaseMapDownloadResult(
          success: false,
          message: 'クラウド上に地図が見つかりませんでした。',
        );
      }

      final data = doc.data()!;
      if (targetOwnerId != user.uid) {
        final sharedWith = _parseStringSet(data['sharedWith']);
        if (!sharedWith.contains(user.uid)) {
          return const FirebaseMapDownloadResult(
            success: false,
            message: 'この地図を取得する権限がありません。',
          );
        }
      }

      final resolvedRemoteMapId = doc.id;
      final remoteSyncId = switch (data['syncId']?.toString().trim()) {
        final value? when value.isNotEmpty => value,
        _ => resolvedRemoteMapId,
      };
      final remoteUpdatedAt = _parseTimestamp(data['updatedAt']);
      final remoteTitle = data['title']?.toString() ?? '名称未設定の地図';
      final existingMaps = await DatabaseHelper.instance.readAllMaps();
      MapInfo? existingMap;
      if (!importAsCopy) {
        final associatedLocalId = await CollaborationMetadataStore.instance
            .findLocalMapId(
              ownerUid: targetOwnerId,
              remoteMapId: resolvedRemoteMapId,
            );
        existingMap = resolveExistingLocalMap(
          maps: existingMaps,
          remoteSyncId: remoteSyncId,
          remoteMapId: resolvedRemoteMapId,
          associatedLocalMapId: associatedLocalId,
        );
      }

      // Fetch all remote records before changing local state. The local id is
      // allocated by this device and is never copied from another device.
      final memosSnapshot = await docRef.collection('memos').get();
      if (existingMap == null) {
        final created = await DatabaseHelper.instance.createMap(
          MapInfo(
            title: remoteTitle,
            syncId: importAsCopy ? null : remoteSyncId,
            updatedAt: remoteUpdatedAt,
          ),
        );
        createdLocalMapId = created.id;
        existingMap = created;
      }
      final localMapId = existingMap.id;
      if (localMapId == null) {
        throw StateError('Local map id was not allocated.');
      }

      String? imagePath = existingMap.imagePath;
      final imageUrl = data['imageUrl']?.toString();
      if (imageUrl != null && imageUrl.isNotEmpty) {
        final resolved = await _downloadBinaryFromUrl(
          imageUrl,
          defaultContentType: 'image/png',
        );
        if (resolved == null) throw StateError('Map image download failed.');
        imagePath = await _saveMapImage(localMapId, resolved);
        if (imagePath != null && !imagePath.startsWith('data:')) {
          downloadedLocalFiles.add(imagePath);
        }
      }

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
          discoveryTime = DateTime.fromMillisecondsSinceEpoch(
            discoveryRaw.toInt(),
          );
        }

        final imageUrls =
            (memoData['imageUrls'] as List?)?.cast<String>() ??
            const <String>[];
        final localImagePaths = <String>[];
        for (var i = 0; i < imageUrls.length; i++) {
          final resolved = await _downloadBinaryFromUrl(
            imageUrls[i],
            defaultContentType: 'image/png',
          );
          if (resolved == null) {
            throw StateError('Memo image download failed.');
          }
          final saved = await _saveMemoImage(
            localMapId,
            memoDoc.id,
            i,
            resolved,
          );
          if (saved == null) throw StateError('Memo image save failed.');
          localImagePaths.add(saved);
          if (!saved.startsWith('data:')) {
            downloadedLocalFiles.add(saved);
          }
        }

        String? audioPath;
        final audioUrl = memoData['audioUrl']?.toString();
        if (audioUrl != null && audioUrl.isNotEmpty) {
          final resolved = await _downloadBinaryFromUrl(
            audioUrl,
            defaultContentType: 'audio/aac',
          );
          if (resolved == null) throw StateError('Memo audio download failed.');
          audioPath = await _saveMemoAudio(localMapId, memoDoc.id, resolved);
          if (audioPath == null) throw StateError('Memo audio save failed.');
          if (!audioPath.startsWith('data:')) {
            downloadedLocalFiles.add(audioPath);
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
          mapId: localMapId,
          audioPath: audioPath,
          imagePaths: localImagePaths.isEmpty ? null : localImagePaths,
          mushroomCapShape: memoData['mushroomCapShape']?.toString(),
          mushroomCapColor: memoData['mushroomCapColor']?.toString(),
          mushroomCapSurface: memoData['mushroomCapSurface']?.toString(),
          mushroomCapSize: memoData['mushroomCapSize']?.toString(),
          mushroomCapUnderStructure: memoData['mushroomCapUnderStructure']
              ?.toString(),
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
          syncId: memoData['syncId']?.toString() ?? memoDoc.id,
          updatedAt: _parseTimestamp(memoData['updatedAt']),
        );
        memos.add(memo);
      }

      final mapInfo = MapInfo(
        id: localMapId,
        title: remoteTitle,
        imagePath: imagePath,
        syncId: importAsCopy ? existingMap.syncId : remoteSyncId,
        updatedAt: remoteUpdatedAt,
      );

      if (importAsCopy) {
        await DatabaseHelper.instance.upsertMapInfo(mapInfo);
        for (final memo in memos) {
          memo.id = null;
          memo.mapId = localMapId;
        }
        await DatabaseHelper.instance.replaceMemosForMap(localMapId, memos);
        return FirebaseMapDownloadResult(
          success: true,
          message: '共有地図をインポートしました。',
          localMapId: localMapId,
        );
      }

      await DatabaseHelper.instance.upsertMapInfo(mapInfo);
      final pending = await SyncQueueStore.instance.pendingSyncIdsForMap(
        localMapId,
      );
      final safeMemos = memos
          .where(
            (memo) => memo.syncId == null || !pending.contains(memo.syncId),
          )
          .toList();
      final remoteSyncIds = memos
          .map((memo) => memo.syncId)
          .whereType<String>()
          .toSet();
      final localMemos = await DatabaseHelper.instance.readMemosByMapId(
        localMapId,
      );
      final safeDeletes = localMemos
          .map((memo) => memo.syncId)
          .whereType<String>()
          .where(
            (syncId) =>
                !pending.contains(syncId) && !remoteSyncIds.contains(syncId),
          )
          .toSet();
      await DatabaseHelper.instance.upsertMemosForMap(localMapId, safeMemos);
      await DatabaseHelper.instance.deleteMemosBySyncIds(
        localMapId,
        safeDeletes,
      );

      return FirebaseMapDownloadResult(
        success: true,
        message: 'クラウドから地図を取得しました。',
        localMapId: localMapId,
      );
    } catch (error, stackTrace) {
      if (createdLocalMapId != null) {
        try {
          await DatabaseHelper.instance.deleteMap(createdLocalMapId);
        } catch (_) {
          // Preserve the original failure; incomplete local maps are retried on
          // the next download and are never associated with collaboration.
        }
        await _deleteLocalFilesBestEffort(downloadedLocalFiles);
      }
      appLog('Firebase download failed: $error');
      appLog('Stack trace', stackTrace);
      return const FirebaseMapDownloadResult(
        success: false,
        message: 'ダウンロードに失敗しました。通信状況とアクセス権を確認してください。',
      );
    }
  }

  Future<FirebaseMapUploadResult> uploadMap(MapInfo mapInfo) async {
    if (mapInfo.id == null) {
      return const FirebaseMapUploadResult(
        success: false,
        message: '先に地図を端末へ保存してください。',
      );
    }

    try {
      final user = _requireUser();
      final memos = await DatabaseHelper.instance.readMemosByMapId(mapInfo.id!);
      final remoteMapId = _remoteMapIdFor(mapInfo);
      final docRef = _mapDocument(
        user.uid,
        mapInfo.id!,
        remoteMapId: remoteMapId,
      );
      final previous = await docRef.get();
      final previousBaseGeneration = previous
          .data()?['baseAssetGeneration']
          ?.toString();
      final generation = DateTime.now()
          .toUtc()
          .microsecondsSinceEpoch
          .toString();
      final mapStorageRoot = _storage.ref().child(
        'users/${user.uid}/maps/$remoteMapId/base_generations/$generation',
      );

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
        imageUrl = _storageUri(mapImageRef);
      }

      final uploadedMemoIds = <String>{};
      for (final memo in memos) {
        uploadedMemoIds.add(_memoDocumentId(memo));
        await _upsertMemoDocument(
          mapId: mapInfo.id!,
          remoteMapId: remoteMapId,
          ownerUid: user.uid,
          memo: memo,
          generation: generation,
        );
      }

      await docRef.set({
        'id': mapInfo.id,
        'syncId': mapInfo.syncId ?? remoteMapId,
        'title': mapInfo.title,
        'imageUrl': imageUrl,
        'baseAssetGeneration': generation,
        'updatedAt': Timestamp.fromDate(
          mapInfo.updatedAt ?? DateTime.now().toUtc(),
        ),
        'syncedAt': FieldValue.serverTimestamp(),
        'memoCount': memos.length,
        'ownerId': user.uid,
        'ownerEmail': user.email,
      }, SetOptions(merge: true));

      // Remove stale documents only after the new generation and references
      // have been committed successfully.
      final remoteMemos = await docRef.collection('memos').get();
      for (final remoteMemo in remoteMemos.docs) {
        if (!uploadedMemoIds.contains(remoteMemo.id)) {
          await remoteMemo.reference.delete();
        }
      }
      if (previousBaseGeneration != null &&
          previousBaseGeneration != generation) {
        await _clearStorageFolder(
          _storage.ref().child(
            'users/${user.uid}/maps/$remoteMapId/base_generations/$previousBaseGeneration',
          ),
        );
      }

      return FirebaseMapUploadResult(
        success: true,
        message: 'クラウドへ地図を保存しました。',
        remoteMapId: remoteMapId,
      );
    } catch (error, stackTrace) {
      appLog('Firebase upload failed: $error');
      appLog('Stack trace', stackTrace);
      return const FirebaseMapUploadResult(
        success: false,
        message: 'アップロードに失敗しました。通信状況とアクセス権を確認してください。',
      );
    }
  }

  Stream<FirebaseMemoChangeSet> subscribeToMapMemos({
    required int mapId,
    required String ownerUid,
    String? remoteMapId,
  }) {
    final collection = _memoCollection(
      ownerUid,
      mapId,
      remoteMapId: remoteMapId,
    );
    return collection.snapshots().asyncMap((snapshot) async {
      final upserts = <Memo>[];
      final deletedSyncIds = <String>{};
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.removed) {
          deletedSyncIds.add(
            change.doc.data()?['syncId']?.toString() ?? change.doc.id,
          );
          continue;
        }
        try {
          upserts.add(await _memoFromSnapshot(mapId, change.doc));
        } catch (error, stackTrace) {
          appLog(
            'Failed to parse memo snapshot: ${error.runtimeType}',
            stackTrace,
          );
        }
      }
      return FirebaseMemoChangeSet(
        upserts: upserts,
        deletedSyncIds: deletedSyncIds,
      );
    });
  }

  Future<void> upsertMemo({
    required int mapId,
    required String remoteMapId,
    required String ownerUid,
    required Memo memo,
  }) async {
    await _upsertMemoDocument(
      mapId: mapId,
      remoteMapId: remoteMapId,
      ownerUid: ownerUid,
      memo: memo,
      generation: DateTime.now().toUtc().microsecondsSinceEpoch.toString(),
    );
  }

  Future<void> _upsertMemoDocument({
    required int mapId,
    required String remoteMapId,
    required String ownerUid,
    required Memo memo,
    required String generation,
  }) async {
    final memoDocumentId = _memoDocumentId(memo);
    final docRef = _memoCollection(
      ownerUid,
      mapId,
      remoteMapId: remoteMapId,
    ).doc(memoDocumentId);
    final previous = await docRef.get();
    final previousGeneration = previous.data()?['assetGeneration']?.toString();
    final assets = await _uploadMemoAssets(
      ownerUid,
      remoteMapId,
      memo,
      generation,
    );

    final data = <String, dynamic>{
      'id': memo.id,
      'syncId': memo.syncId ?? memoDocumentId,
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
      'audioUrl': assets.audioUrl,
      'imageUrls': assets.imageUrls,
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
      'assetGeneration': generation,
      'updatedAt': Timestamp.fromDate(memo.updatedAt ?? DateTime.now().toUtc()),
      'syncedAt': FieldValue.serverTimestamp(),
    };

    await docRef.set(data, SetOptions(merge: true));
    if (previousGeneration != null && previousGeneration != generation) {
      await _clearStorageFolder(
        _storage.ref().child(
          'users/$ownerUid/maps/$remoteMapId/memos/$memoDocumentId/generations/$previousGeneration',
        ),
      );
    }
  }

  Future<void> deleteMemo({
    required int mapId,
    required String remoteMapId,
    required String ownerUid,
    required String memoSyncId,
    int? legacyMemoId,
  }) async {
    final collection = _memoCollection(
      ownerUid,
      mapId,
      remoteMapId: remoteMapId,
    );
    await collection.doc(memoSyncId).delete();
    if (legacyMemoId != null && legacyMemoId.toString() != memoSyncId) {
      await collection.doc(legacyMemoId.toString()).delete();
    }
    try {
      final folderRef = _storage.ref().child(
        'users/$ownerUid/maps/$remoteMapId/memos/$memoSyncId',
      );
      await _clearStorageFolder(folderRef);
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') {
        rethrow;
      }
    }
  }

  Future<FirebaseMapShareResult> shareMapWithEmail({
    required int mapId,
    required String email,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      return const FirebaseMapShareResult(
        success: false,
        message: '共有するメールアドレスを入力してください。',
      );
    }

    try {
      final user = _requireUser();
      final profile = await _findUserProfileByEmail(normalizedEmail);
      if (profile == null) {
        return const FirebaseMapShareResult(
          success: false,
          message: '指定されたメールアドレスのユーザーが見つかりません。',
        );
      }
      if (profile.uid == user.uid) {
        return const FirebaseMapShareResult(
          success: false,
          message: '自分自身には共有できません。',
        );
      }

      final docRef = await _mapDocumentForLocalId(user.uid, mapId);
      final doc = await docRef.get();
      if (!doc.exists) {
        return const FirebaseMapShareResult(
          success: false,
          message: '共有する地図が見つかりませんでした。',
        );
      }

      await docRef.set({
        'sharedWith': FieldValue.arrayUnion([profile.uid]),
        'sharedUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return FirebaseMapShareResult(
        success: true,
        message: '${profile.email} と共有しました。',
      );
    } catch (error, stackTrace) {
      appLog('Firebase share failed: $error');
      appLog('Stack trace', stackTrace);
      return const FirebaseMapShareResult(
        success: false,
        message: '共有に失敗しました。入力内容と通信状況を確認してください。',
      );
    }
  }

  Future<FirebaseMapShareResult> revokeSharedUser({
    required int mapId,
    required String uid,
  }) async {
    if (uid.isEmpty) {
      return const FirebaseMapShareResult(
        success: false,
        message: '削除する共有ユーザーが指定されていません。',
      );
    }

    try {
      final user = _requireUser();
      final docRef = await _mapDocumentForLocalId(user.uid, mapId);
      final doc = await docRef.get();
      if (!doc.exists) {
        return const FirebaseMapShareResult(
          success: false,
          message: '共有情報が見つかりませんでした。',
        );
      }

      await docRef.set({
        'sharedWith': FieldValue.arrayRemove([uid]),
        'sharedUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return const FirebaseMapShareResult(
        success: true,
        message: '共有設定を更新しました。',
      );
    } catch (error, stackTrace) {
      appLog('Firebase revoke share failed: $error');
      appLog('Stack trace', stackTrace);
      return const FirebaseMapShareResult(
        success: false,
        message: '共有の解除に失敗しました。時間をおいて再試行してください。',
      );
    }
  }

  Future<List<FirebaseSharedUser>> fetchSharedUsers(int mapId) async {
    try {
      final user = _requireUser();
      final docRef = await _mapDocumentForLocalId(user.uid, mapId);
      final doc = await docRef.get();
      if (!doc.exists) {
        return const <FirebaseSharedUser>[];
      }

      final sharedWith = _parseStringSet(doc.data()?['sharedWith']);
      if (sharedWith.isEmpty) {
        return const <FirebaseSharedUser>[];
      }

      final profiles = <FirebaseSharedUser>[];
      for (final sharedUid in sharedWith) {
        final profile = await _fetchUserProfile(sharedUid);
        if (profile != null) {
          profiles.add(profile);
        }
      }

      profiles.sort((a, b) => a.email.compareTo(b.email));
      return profiles;
    } catch (error, stackTrace) {
      appLog('Firebase fetch shared users failed: $error');
      appLog('Stack trace', stackTrace);
      return const <FirebaseSharedUser>[];
    }
  }

  Future<FirebaseSharedUser?> _findUserProfileByEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }

    final doc = await _firestore
        .collection('shareDirectory')
        .doc(normalized)
        .get();
    final data = doc.data();
    final uid = data?['uid']?.toString();
    if (!doc.exists || data == null || uid == null || uid.isEmpty) {
      return null;
    }

    return FirebaseSharedUser(
      uid: uid,
      email: normalized,
      displayName: data['displayName']?.toString(),
    );
  }

  /// ログイン中ユーザーが所有するクラウドデータを削除する。
  ///
  /// Firebase Auth自体の削除は、呼び出し側で再認証後に行う。
  Future<void> deleteCurrentUserCloudData() async {
    final user = _requireUser();
    final maps = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('maps')
        .get();

    for (final map in maps.docs) {
      await _deleteCollectionInBatches(map.reference.collection('memos'));
      await map.reference.delete();
    }

    await _clearStorageFolder(_storage.ref().child('users/${user.uid}'));
    await _clearStorageFolder(_storage.ref().child('userProfiles/${user.uid}'));

    await _firestore.collection('userProfiles').doc(user.uid).delete();

    final email = user.email?.trim().toLowerCase();
    if (email != null && email.isNotEmpty) {
      await _firestore.collection('shareDirectory').doc(email).delete();
    }
  }

  Future<void> _deleteCollectionInBatches(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    const batchSize = 400;
    while (true) {
      final snapshot = await collection.limit(batchSize).get();
      if (snapshot.docs.isEmpty) {
        return;
      }

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (snapshot.docs.length < batchSize) {
        return;
      }
    }
  }

  Future<FirebaseSharedUser?> _fetchUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('userProfiles').doc(uid).get();
      if (!doc.exists) {
        return null;
      }
      final data = doc.data();
      if (data == null) {
        return null;
      }
      return FirebaseSharedUser(
        uid: doc.id,
        email: data['email']?.toString() ?? '',
        displayName: data['displayName']?.toString(),
      );
    } catch (error) {
      appLog('Firebase fetch user profile failed: $error');
      return null;
    }
  }

  Set<String> _parseStringSet(dynamic value) {
    if (value is Iterable) {
      return value.map((e) => e.toString()).toSet();
    }
    return <String>{};
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toUtc();
    }
    if (value is DateTime) {
      return value.toUtc();
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
    }
    return null;
  }

  User _requireUser() {
    final current = _auth.currentUser;
    if (current == null) {
      throw StateError('User not authenticated.');
    }
    return current;
  }

  String _remoteMapIdFor(MapInfo mapInfo) {
    final syncId = mapInfo.syncId;
    if (syncId != null &&
        syncId.isNotEmpty &&
        !syncId.startsWith('legacy-map-')) {
      return syncId;
    }
    return mapInfo.id.toString();
  }

  Future<DocumentReference<Map<String, dynamic>>> _mapDocumentForLocalId(
    String uid,
    int mapId,
  ) async {
    final maps = await DatabaseHelper.instance.readAllMaps();
    for (final map in maps) {
      if (map.id == mapId) {
        return _mapDocument(uid, mapId, remoteMapId: _remoteMapIdFor(map));
      }
    }
    return _mapDocument(uid, mapId);
  }

  String _memoDocumentId(Memo memo) {
    final syncId = memo.syncId;
    if (syncId != null &&
        syncId.isNotEmpty &&
        !syncId.startsWith('legacy-memo-')) {
      return syncId;
    }
    return memo.id?.toString() ?? _temporaryMemoId();
  }

  Future<Memo> _memoFromSnapshot(
    int mapId,
    DocumentSnapshot<Map<String, dynamic>> memoDoc,
  ) async {
    final memoData = memoDoc.data();
    if (memoData == null) {
      throw StateError('Memo document ${memoDoc.id} has no data');
    }

    final parsedId = int.tryParse(memoDoc.id);
    final memoId =
        parsedId ??
        (memoData['id'] is num ? (memoData['id'] as num).toInt() : null);
    final discoveryTime = _parseTimestamp(memoData['discoveryTime']);

    final imageUrlsRaw = memoData['imageUrls'];
    final imageUrls = imageUrlsRaw is Iterable
        ? imageUrlsRaw
              .map((entry) => entry.toString())
              .where((entry) => entry.isNotEmpty)
              .toList()
        : const <String>[];
    final localImages = <String>[];
    for (var i = 0; i < imageUrls.length; i++) {
      final resolved = await _downloadBinaryFromUrl(
        imageUrls[i],
        defaultContentType: 'image/png',
      );
      if (resolved != null) {
        final saved = await _saveMemoImage(mapId, memoDoc.id, i, resolved);
        if (saved != null) {
          localImages.add(saved);
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

    return Memo(
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
      imagePaths: localImages.isEmpty ? null : localImages,
      mushroomCapShape: memoData['mushroomCapShape']?.toString(),
      mushroomCapColor: memoData['mushroomCapColor']?.toString(),
      mushroomCapSurface: memoData['mushroomCapSurface']?.toString(),
      mushroomCapSize: memoData['mushroomCapSize']?.toString(),
      mushroomCapUnderStructure: memoData['mushroomCapUnderStructure']
          ?.toString(),
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
      syncId: memoData['syncId']?.toString() ?? memoDoc.id,
      updatedAt: _parseTimestamp(memoData['updatedAt']),
    );
  }

  Future<_UploadedAssets> _uploadMemoAssets(
    String uid,
    String remoteMapId,
    Memo memo,
    String generation,
  ) async {
    final memoFolderName = _memoDocumentId(memo);
    final baseRef = _storage.ref().child(
      'users/$uid/maps/$remoteMapId/memos/$memoFolderName/generations/$generation',
    );

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
      imageUrls.add(_storageUri(imageRef));
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
        audioUrl = _storageUri(audioRef);
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
      appLog('Cannot read local file path on the web: $path');
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

  String _storageUri(Reference reference) {
    return 'gs://${reference.bucket}/${reference.fullPath}';
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
      appLog('Failed to download binary from $url: $error');
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
      final extension = _extensionForContent(
        asset.contentType,
        fallback: '.aac',
      );
      final fileName =
          'firebase_audio_${_sanitizeForFile(mapId.toString())}_${_sanitizeForFile(memoKey)}$extension';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(asset.bytes, flush: true);
      return file.path;
    }
  }

  Future<void> _deleteLocalFilesBestEffort(Iterable<String> paths) async {
    if (kIsWeb) return;
    for (final path in paths.toSet()) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {
        // Orphan cleanup is best effort and must not hide the download error.
      }
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
