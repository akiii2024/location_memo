import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../models/memo.dart';
import 'app_logger.dart';
import 'collaboration_metadata_store.dart';
import 'firebase_availability.dart';
import 'firebase_map_service.dart';
import 'sync_queue.dart';

class CollaborationSyncCoordinator {
  CollaborationSyncCoordinator._();

  static final CollaborationSyncCoordinator instance =
      CollaborationSyncCoordinator._();

  final CollaborationMetadataStore _store = CollaborationMetadataStore.instance;
  final SyncQueueStore _queue = SyncQueueStore.instance;
  final Set<int> _syncingMaps = <int>{};
  bool _isFlushing = false;

  Future<CollaborationMetadata?> getMetadata(int mapId) {
    return _store.getForMap(mapId);
  }

  Future<bool> isCollaborative(int mapId) async {
    return await getMetadata(mapId) != null;
  }

  Future<void> registerCollaborativeMap({
    required int mapId,
    required String ownerUid,
    required bool isOwner,
    String? ownerEmail,
    String? remoteMapId,
  }) async {
    final previous = await _store.getForMap(mapId);
    final metadata = CollaborationMetadata(
      ownerUid: ownerUid,
      isOwner: isOwner,
      ownerEmail: ownerEmail,
      registeredAt: previous?.registeredAt ?? DateTime.now().toUtc(),
      remoteMapId: remoteMapId ?? previous?.remoteMapId ?? mapId.toString(),
      lastSyncedAt: previous?.lastSyncedAt,
    );
    await _store.saveForMap(mapId, metadata);
    unawaited(flushPending());
  }

  Future<void> unregisterCollaborativeMap(int mapId) async {
    await _store.deleteForMap(mapId);
    await _queue.removeForMap(mapId);
  }

  Future<SyncStatus> statusForMap(int mapId) async {
    if (_syncingMaps.contains(mapId)) return SyncStatus.syncing;
    return _queue.statusForMap(mapId);
  }

  Future<Set<String>> pendingSyncIdsForMap(int mapId) =>
      _queue.pendingSyncIdsForMap(mapId);

  Future<void> onLocalMemoCreated(Memo memo) => _enqueueUpsert(memo);

  Future<void> onLocalMemoUpdated(Memo memo) => _enqueueUpsert(memo);

  Future<void> onLocalMemoDeleted(Memo memo) async {
    final mapId = memo.mapId;
    final memoId = memo.id;
    if (mapId == null || memoId == null) return;
    final metadata = await getMetadata(mapId);
    if (metadata == null) return;
    final syncId = memo.syncId ?? 'legacy-memo-$mapId-$memoId';
    await _queue.enqueueDelete(
      localMapId: mapId,
      remoteMapId: metadata.remoteMapId ?? mapId.toString(),
      ownerUid: metadata.ownerUid,
      memoSyncId: syncId,
      legacyMemoId: memoId,
    );
    unawaited(flushPending());
  }

  Future<void> _enqueueUpsert(Memo memo) async {
    final mapId = memo.mapId;
    final memoId = memo.id;
    if (mapId == null || memoId == null) return;
    final metadata = await getMetadata(mapId);
    if (metadata == null) return;
    memo.syncId ??= 'legacy-memo-$mapId-$memoId';
    memo.updatedAt ??= DateTime.now().toUtc();
    await _queue.enqueueUpsert(
      localMapId: mapId,
      remoteMapId: metadata.remoteMapId ?? mapId.toString(),
      ownerUid: metadata.ownerUid,
      memo: memo,
    );
    unawaited(flushPending());
  }

  Future<void> flushPending() async {
    if (_isFlushing || !FirebaseAvailability.isReady) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _isFlushing = true;
    try {
      while (true) {
        final entries = await _queue.readyEntries();
        if (entries.isEmpty) break;
        for (final entry in entries) {
          _syncingMaps.add(entry.localMapId);
          try {
            if (entry.operation == SyncOperation.upsertMemo) {
              final data = entry.memoData;
              if (data == null) {
                await _queue.markSucceeded(entry);
                continue;
              }
              final memo = Memo.fromMap(data)..mapId = entry.localMapId;
              await FirebaseMapService.instance.upsertMemo(
                mapId: entry.localMapId,
                remoteMapId: entry.remoteMapId,
                ownerUid: entry.ownerUid,
                memo: memo,
              );
            } else {
              await FirebaseMapService.instance.deleteMemo(
                mapId: entry.localMapId,
                remoteMapId: entry.remoteMapId,
                ownerUid: entry.ownerUid,
                memoSyncId: entry.memoSyncId,
                legacyMemoId: entry.legacyMemoId,
              );
            }
            final wasCurrent = await _queue.markSucceeded(entry);
            if (wasCurrent) await _markMapSynced(entry.localMapId);
          } catch (error, stackTrace) {
            appLog('Deferred sync failed: ${error.runtimeType}', stackTrace);
            await _queue.markFailed(entry, error);
          } finally {
            _syncingMaps.remove(entry.localMapId);
          }
        }
      }
    } finally {
      _isFlushing = false;
    }
  }

  Future<void> _markMapSynced(int mapId) async {
    final metadata = await _store.getForMap(mapId);
    if (metadata == null) return;
    await _store.saveForMap(
      mapId,
      CollaborationMetadata(
        ownerUid: metadata.ownerUid,
        isOwner: metadata.isOwner,
        ownerEmail: metadata.ownerEmail,
        registeredAt: metadata.registeredAt,
        remoteMapId: metadata.remoteMapId,
        lastSyncedAt: DateTime.now().toUtc(),
      ),
    );
  }
}
