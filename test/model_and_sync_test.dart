import 'package:flutter_test/flutter_test.dart';
import 'package:location_memo/models/map_info.dart';
import 'package:location_memo/models/memo.dart';
import 'package:location_memo/utils/sync_queue.dart';
import 'package:location_memo/utils/collaboration_metadata_store.dart';
import 'package:location_memo/utils/firebase_map_service.dart';
import 'package:location_memo/utils/diagnostic_log_store.dart';

void main() {
  group('同期メタデータの互換変換', () {
    test('旧MapInfoデータは同期項目がなくても読み込める', () {
      final map = MapInfo.fromMap({'id': 7, 'title': '旧地図', 'imagePath': null});

      expect(map.id, 7);
      expect(map.title, '旧地図');
      expect(map.syncId, isNull);
      expect(map.updatedAt, isNull);
    });

    test('MemoのsyncIdと更新日時を往復できる', () {
      final updatedAt = DateTime.utc(2026, 9, 10, 12, 30);
      final source = Memo(
        id: 9,
        title: '観察地点',
        content: '本文',
        mapId: 7,
        imagePaths: ['one.jpg', 'two.png'],
        syncId: 'memo-uuid',
        updatedAt: updatedAt,
      );

      final restored = Memo.fromMap(source.toMap());
      expect(restored.syncId, 'memo-uuid');
      expect(restored.updatedAt, updatedAt);
      expect(restored.imagePaths, ['one.jpg', 'two.png']);
    });

    test('旧CollaborationMetadataと新しいリモートIDを両方読める', () {
      final oldValue = CollaborationMetadata.fromJson({'ownerUid': 'owner-1'});
      expect(oldValue.ownerUid, 'owner-1');
      expect(oldValue.remoteMapId, isNull);

      final updatedAt = DateTime.utc(2026, 9, 11, 8);
      final newValue = CollaborationMetadata.fromJson(
        CollaborationMetadata(
          ownerUid: 'owner-2',
          isOwner: false,
          remoteMapId: 'map-uuid',
          lastSyncedAt: updatedAt,
        ).toJson(),
      );
      expect(newValue.remoteMapId, 'map-uuid');
      expect(newValue.lastSyncedAt, updatedAt);
    });

    test('リモートの数値IDだけでは無関係なローカル地図を選ばない', () {
      const unrelated = MapInfo(
        id: 1,
        title: '端末内の別地図',
        syncId: 'local-map-uuid',
      );
      final resolved = FirebaseMapService.resolveExistingLocalMap(
        maps: const [unrelated],
        remoteSyncId: '1',
        remoteMapId: '1',
      );
      expect(resolved, isNull);
    });

    test('安定IDまたは保存済み関連付けでローカル地図を選べる', () {
      const stable = MapInfo(id: 5, title: '同期地図', syncId: 'map-uuid');
      const associated = MapInfo(id: 8, title: '旧共有地図', syncId: 'legacy-map-8');
      expect(
        FirebaseMapService.resolveExistingLocalMap(
          maps: const [stable, associated],
          remoteSyncId: 'map-uuid',
          remoteMapId: 'remote-doc',
        )?.id,
        5,
      );
      expect(
        FirebaseMapService.resolveExistingLocalMap(
          maps: const [stable, associated],
          remoteSyncId: 'old-remote',
          remoteMapId: '8',
          associatedLocalMapId: 8,
        )?.id,
        8,
      );
    });
  });

  group('同期キュー', () {
    test('永続化形式を欠損なく往復できる', () {
      final queuedAt = DateTime.utc(2026, 9, 10);
      final retryAt = queuedAt.add(const Duration(seconds: 20));
      final source = SyncQueueEntry(
        key: 'owner::map::memo',
        operation: SyncOperation.deleteMemo,
        localMapId: 3,
        remoteMapId: 'map-uuid',
        ownerUid: 'owner',
        memoSyncId: 'memo-uuid',
        legacyMemoId: 42,
        queuedAt: queuedAt,
        attempts: 2,
        nextAttemptAt: retryAt,
        lastErrorCode: 'TimeoutException',
      );

      final restored = SyncQueueEntry.fromJson(source.toJson());
      expect(restored.operation, SyncOperation.deleteMemo);
      expect(restored.localMapId, 3);
      expect(restored.remoteMapId, 'map-uuid');
      expect(restored.memoSyncId, 'memo-uuid');
      expect(restored.legacyMemoId, 42);
      expect(restored.attempts, 2);
      expect(restored.nextAttemptAt, retryAt);
      expect(restored.lastErrorCode, 'TimeoutException');
    });

    test('未知の旧operationは安全にupsertへフォールバックする', () {
      final restored = SyncQueueEntry.fromJson({
        'key': 'legacy',
        'operation': 'unknown',
        'localMapId': 1,
        'remoteMapId': 'remote',
        'ownerUid': 'owner',
        'memoSyncId': 'memo',
        'queuedAt': '2026-09-10T00:00:00Z',
      });

      expect(restored.operation, SyncOperation.upsertMemo);
      expect(restored.attempts, 0);
    });
  });

  test('端末内診断ログの永続化形式に利用者データ用フィールドを持たない', () {
    final json = DiagnosticLogEntry(
      occurredAt: DateTime.utc(2026, 9, 11),
      event: 'flutter_framework_error',
      errorType: 'StateError',
    ).toJson();
    expect(json.keys, {'occurredAt', 'event', 'errorType'});
    expect(json.values.join(' '), isNot(contains('地図名')));
  });
}
