import 'package:hive_flutter/hive_flutter.dart';

import '../models/memo.dart';

enum SyncStatus { synced, pending, syncing, failed }

enum SyncOperation { upsertMemo, deleteMemo }

class SyncQueueEntry {
  const SyncQueueEntry({
    required this.key,
    required this.operation,
    required this.localMapId,
    required this.remoteMapId,
    required this.ownerUid,
    required this.memoSyncId,
    required this.queuedAt,
    this.memoData,
    this.legacyMemoId,
    this.attempts = 0,
    this.nextAttemptAt,
    this.lastErrorCode,
  });

  final String key;
  final SyncOperation operation;
  final int localMapId;
  final String remoteMapId;
  final String ownerUid;
  final String memoSyncId;
  final DateTime queuedAt;
  final Map<String, dynamic>? memoData;
  final int? legacyMemoId;
  final int attempts;
  final DateTime? nextAttemptAt;
  final String? lastErrorCode;

  bool get isReady =>
      nextAttemptAt == null || !nextAttemptAt!.isAfter(DateTime.now().toUtc());

  SyncQueueEntry copyWith({
    int? attempts,
    DateTime? nextAttemptAt,
    String? lastErrorCode,
  }) {
    return SyncQueueEntry(
      key: key,
      operation: operation,
      localMapId: localMapId,
      remoteMapId: remoteMapId,
      ownerUid: ownerUid,
      memoSyncId: memoSyncId,
      queuedAt: queuedAt,
      memoData: memoData,
      legacyMemoId: legacyMemoId,
      attempts: attempts ?? this.attempts,
      nextAttemptAt: nextAttemptAt,
      lastErrorCode: lastErrorCode,
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'operation': operation.name,
    'localMapId': localMapId,
    'remoteMapId': remoteMapId,
    'ownerUid': ownerUid,
    'memoSyncId': memoSyncId,
    'queuedAt': queuedAt.toIso8601String(),
    if (memoData != null) 'memoData': memoData,
    if (legacyMemoId != null) 'legacyMemoId': legacyMemoId,
    'attempts': attempts,
    if (nextAttemptAt != null)
      'nextAttemptAt': nextAttemptAt!.toIso8601String(),
    if (lastErrorCode != null) 'lastErrorCode': lastErrorCode,
  };

  factory SyncQueueEntry.fromJson(Map<dynamic, dynamic> json) {
    final operationName = json['operation']?.toString();
    return SyncQueueEntry(
      key: json['key'].toString(),
      operation: SyncOperation.values.firstWhere(
        (value) => value.name == operationName,
        orElse: () => SyncOperation.upsertMemo,
      ),
      localMapId: (json['localMapId'] as num).toInt(),
      remoteMapId: json['remoteMapId'].toString(),
      ownerUid: json['ownerUid'].toString(),
      memoSyncId: json['memoSyncId'].toString(),
      queuedAt: DateTime.parse(json['queuedAt'].toString()).toUtc(),
      memoData: json['memoData'] is Map
          ? Map<String, dynamic>.from(json['memoData'] as Map)
          : null,
      legacyMemoId: (json['legacyMemoId'] as num?)?.toInt(),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      nextAttemptAt: json['nextAttemptAt'] == null
          ? null
          : DateTime.tryParse(json['nextAttemptAt'].toString())?.toUtc(),
      lastErrorCode: json['lastErrorCode']?.toString(),
    );
  }
}

class SyncQueueStore {
  SyncQueueStore._();

  static final SyncQueueStore instance = SyncQueueStore._();
  static const _boxName = 'sync_queue_v1';
  Box<dynamic>? _box;

  Future<Box<dynamic>> _ensureBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    await Hive.initFlutter();
    _box = await Hive.openBox<dynamic>(_boxName);
    return _box!;
  }

  String _key(String ownerUid, String remoteMapId, String memoSyncId) =>
      '$ownerUid::$remoteMapId::$memoSyncId';

  Future<void> enqueueUpsert({
    required int localMapId,
    required String remoteMapId,
    required String ownerUid,
    required Memo memo,
  }) async {
    final syncId = memo.syncId;
    if (syncId == null || syncId.isEmpty) {
      throw ArgumentError('memo.syncId is required');
    }
    final key = _key(ownerUid, remoteMapId, syncId);
    final entry = SyncQueueEntry(
      key: key,
      operation: SyncOperation.upsertMemo,
      localMapId: localMapId,
      remoteMapId: remoteMapId,
      ownerUid: ownerUid,
      memoSyncId: syncId,
      memoData: memo.toMap(),
      legacyMemoId: memo.id,
      queuedAt: DateTime.now().toUtc(),
    );
    final box = await _ensureBox();
    await box.put(key, entry.toJson());
  }

  Future<void> enqueueDelete({
    required int localMapId,
    required String remoteMapId,
    required String ownerUid,
    required String memoSyncId,
    int? legacyMemoId,
  }) async {
    final key = _key(ownerUid, remoteMapId, memoSyncId);
    final entry = SyncQueueEntry(
      key: key,
      operation: SyncOperation.deleteMemo,
      localMapId: localMapId,
      remoteMapId: remoteMapId,
      ownerUid: ownerUid,
      memoSyncId: memoSyncId,
      legacyMemoId: legacyMemoId,
      queuedAt: DateTime.now().toUtc(),
    );
    final box = await _ensureBox();
    await box.put(key, entry.toJson());
  }

  Future<List<SyncQueueEntry>> readyEntries() async {
    final box = await _ensureBox();
    final entries = <SyncQueueEntry>[];
    for (final value in box.values) {
      if (value is Map) {
        final entry = SyncQueueEntry.fromJson(value);
        if (entry.isReady) entries.add(entry);
      }
    }
    entries.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
    return entries;
  }

  Future<Set<String>> pendingSyncIdsForMap(int localMapId) async {
    final box = await _ensureBox();
    final result = <String>{};
    for (final value in box.values) {
      if (value is Map) {
        final entry = SyncQueueEntry.fromJson(value);
        if (entry.localMapId == localMapId) result.add(entry.memoSyncId);
      }
    }
    return result;
  }

  Future<SyncStatus> statusForMap(int localMapId) async {
    final box = await _ensureBox();
    var hasPending = false;
    for (final value in box.values) {
      if (value is! Map) continue;
      final entry = SyncQueueEntry.fromJson(value);
      if (entry.localMapId != localMapId) continue;
      if (entry.attempts > 0) return SyncStatus.failed;
      hasPending = true;
    }
    return hasPending ? SyncStatus.pending : SyncStatus.synced;
  }

  Future<bool> markSucceeded(SyncQueueEntry processed) async {
    final box = await _ensureBox();
    final raw = box.get(processed.key);
    if (raw is! Map) return false;
    final current = SyncQueueEntry.fromJson(raw);
    if (current.queuedAt == processed.queuedAt &&
        current.operation == processed.operation) {
      await box.delete(processed.key);
      return true;
    }
    return false;
  }

  Future<void> markFailed(SyncQueueEntry processed, Object error) async {
    final box = await _ensureBox();
    final raw = box.get(processed.key);
    if (raw is! Map) return;
    final current = SyncQueueEntry.fromJson(raw);
    // 送信中に同じメモが再編集された場合、新しいキューを失敗扱いにしない。
    if (current.queuedAt != processed.queuedAt ||
        current.operation != processed.operation) {
      return;
    }
    final attempts = current.attempts + 1;
    final exponent = attempts.clamp(0, 6);
    final seconds = (1 << exponent) * 5;
    final updated = current.copyWith(
      attempts: attempts,
      nextAttemptAt: DateTime.now().toUtc().add(Duration(seconds: seconds)),
      lastErrorCode: error.runtimeType.toString(),
    );
    await box.put(processed.key, updated.toJson());
  }

  Future<void> removeForMap(int localMapId) async {
    final box = await _ensureBox();
    final keys = <dynamic>[];
    for (final entry in box.toMap().entries) {
      if (entry.value is Map &&
          SyncQueueEntry.fromJson(entry.value as Map).localMapId ==
              localMapId) {
        keys.add(entry.key);
      }
    }
    await box.deleteAll(keys);
  }

  Future<void> clear() async {
    final box = await _ensureBox();
    await box.clear();
  }
}
