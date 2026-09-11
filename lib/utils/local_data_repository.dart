import '../models/map_info.dart';
import '../models/memo.dart';

/// UI and synchronization code depend on this contract instead of a concrete
/// SQLite or Hive implementation.
abstract interface class LocalDataRepository {
  Future<void> init();

  Future<Memo> create(Memo memo);
  Future<MapInfo> createMap(MapInfo mapInfo);
  Future<Memo> readMemo(int id);
  Future<List<Memo>> readAllMemos();
  Future<List<Memo>> readAllMemosWithMapTitle();
  Future<List<Memo>> readMemosByMapId(int? mapId);
  Future<List<MapInfo>> readAllMaps();
  Future<int> update(Memo memo);
  Future<int> updateMap(MapInfo mapInfo);
  Future<int> delete(int id);
  Future<int> deleteMap(int id);
  Future<void> deleteAllMemos();
  Future<void> deleteAllMaps();
  Future<void> upsertMapInfo(MapInfo mapInfo);
  Future<void> upsertMemosForMap(int mapId, List<Memo> memos);
  Future<void> deleteMemosBySyncIds(int mapId, Set<String> syncIds);
  Future<void> replaceMemosForMap(int mapId, List<Memo> memos);
  Future<Map<int, int>> replaceAllDataAtomically(
    List<MapInfo> maps,
    List<Memo> memos,
  );
  Future<void> clearAllDataAtomically();
}
