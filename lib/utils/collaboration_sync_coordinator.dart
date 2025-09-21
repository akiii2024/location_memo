import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/memo.dart';
import 'collaboration_metadata_store.dart';
import 'firebase_map_service.dart';

class CollaborationSyncCoordinator {
  CollaborationSyncCoordinator._();

  static final CollaborationSyncCoordinator instance =
      CollaborationSyncCoordinator._();

  final CollaborationMetadataStore _store = CollaborationMetadataStore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<CollaborationMetadata?> getMetadata(int mapId) {
    return _store.getForMap(mapId);
  }

  Future<bool> isCollaborative(int mapId) async {
    final metadata = await getMetadata(mapId);
    return metadata != null;
  }

  Future<void> registerCollaborativeMap({
    required int mapId,
    required String ownerUid,
    required bool isOwner,
    String? ownerEmail,
  }) async {
    final metadata = CollaborationMetadata(
      ownerUid: ownerUid,
      isOwner: isOwner,
      ownerEmail: ownerEmail,
      registeredAt: DateTime.now(),
    );
    await _store.saveForMap(mapId, metadata);
  }

  Future<void> unregisterCollaborativeMap(int mapId) async {
    await _store.deleteForMap(mapId);
  }

  Future<void> onLocalMemoCreated(Memo memo) async {
    await _upsertRemoteMemo(memo);
  }

  Future<void> onLocalMemoUpdated(Memo memo) async {
    await _upsertRemoteMemo(memo);
  }

  Future<void> onLocalMemoDeleted(Memo memo) async {
    final mapId = memo.mapId;
    final memoId = memo.id;
    if (mapId == null || memoId == null) {
      return;
    }
    final metadata = await getMetadata(mapId);
    if (metadata == null) {
      return;
    }
    final ownerUid = metadata.ownerUid;
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint(
          'CollaborationSyncCoordinator: skip delete because user is not logged in');
      return;
    }
    try {
      await FirebaseMapService.instance.deleteMemo(
        mapId: mapId,
        ownerUid: ownerUid,
        memoId: memoId,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to delete memo from collaboration: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> _upsertRemoteMemo(Memo memo) async {
    final mapId = memo.mapId;
    final memoId = memo.id;
    if (mapId == null || memoId == null) {
      return;
    }
    final metadata = await getMetadata(mapId);
    if (metadata == null) {
      return;
    }
    final ownerUid = metadata.ownerUid;
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint(
          'CollaborationSyncCoordinator: skip sync because user is not logged in');
      return;
    }
    try {
      await FirebaseMapService.instance.upsertMemo(
        mapId: mapId,
        ownerUid: ownerUid,
        memo: memo,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to sync memo with collaboration backend: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }
}
