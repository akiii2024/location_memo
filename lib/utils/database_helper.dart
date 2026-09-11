import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/memo.dart';
import '../models/map_info.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'local_data_repository.dart';

class DatabaseHelper implements LocalDataRepository {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static Box<MapInfo>? _mapBox;
  static Box<Memo>? _memoBox;
  static const Uuid _uuid = Uuid();
  static const _restoreStateBoxName = 'local_restore_state_v2';
  static const _restoreMapsBoxName = 'local_restore_maps_v2';
  static const _restoreMemosBoxName = 'local_restore_memos_v2';

  DatabaseHelper._init();

  @override
  Future<void> init() async {
    await Hive.initFlutter();
    if (kIsWeb) {
      // Hiveアダプターの登録（partファイルから自動的に利用可能）
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(MapInfoAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(MemoAdapter());
      }
      _mapBox ??= await Hive.openBox<MapInfo>('maps');
      _memoBox ??= await Hive.openBox<Memo>('memos');
      await _recoverInterruptedHiveMutation();
      await _backfillHiveSyncMetadata();
    }
  }

  Future<void> _recoverInterruptedHiveMutation() async {
    final state = await Hive.openBox<dynamic>(_restoreStateBoxName);
    final journal = state.get('journal');
    if (journal is! Map || journal['phase'] != 'applying') return;

    final backupMaps = await Hive.openBox<MapInfo>(_restoreMapsBoxName);
    final backupMemos = await Hive.openBox<Memo>(_restoreMemosBoxName);
    final expectedMaps = (journal['mapCount'] as num?)?.toInt();
    final expectedMemos = (journal['memoCount'] as num?)?.toInt();
    if (expectedMaps == null ||
        expectedMemos == null ||
        backupMaps.length != expectedMaps ||
        backupMemos.length != expectedMemos) {
      // 不完全なジャーナルで正常なライブデータを上書きしない。
      await state.delete('journal');
      return;
    }

    await _mapBox!.clear();
    await _memoBox!.clear();
    await _mapBox!.putAll(backupMaps.toMap());
    await _memoBox!.putAll(backupMemos.toMap());
    await state.delete('journal');
    await backupMaps.clear();
    await backupMemos.clear();
  }

  Future<void> _beginHiveMutationJournal(
    Map<dynamic, MapInfo> maps,
    Map<dynamic, Memo> memos,
  ) async {
    final backupMaps = await Hive.openBox<MapInfo>(_restoreMapsBoxName);
    final backupMemos = await Hive.openBox<Memo>(_restoreMemosBoxName);
    final state = await Hive.openBox<dynamic>(_restoreStateBoxName);
    await backupMaps.clear();
    await backupMemos.clear();
    await backupMaps.putAll(maps);
    await backupMemos.putAll(memos);
    await state.put('journal', {
      'phase': 'applying',
      'mapCount': maps.length,
      'memoCount': memos.length,
    });
  }

  Future<void> _finishHiveMutationJournal() async {
    final state = await Hive.openBox<dynamic>(_restoreStateBoxName);
    await state.delete('journal');
    await (await Hive.openBox<MapInfo>(_restoreMapsBoxName)).clear();
    await (await Hive.openBox<Memo>(_restoreMemosBoxName)).clear();
  }

  Future<void> _backfillHiveSyncMetadata() async {
    final mapBox = _mapBox!;
    for (final entry in mapBox.toMap().entries) {
      final map = entry.value;
      final localId = _intKey(entry.key) ?? map.id;
      if (map.syncId == null || map.updatedAt == null || map.id != localId) {
        await mapBox.put(
          entry.key,
          MapInfo(
            id: localId,
            title: map.title,
            imagePath: map.imagePath,
            syncId: map.syncId ?? _legacyMapSyncId(localId),
            updatedAt:
                map.updatedAt ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          ),
        );
      }
    }

    final memoBox = _memoBox!;
    for (final entry in memoBox.toMap().entries) {
      final memo = entry.value;
      final localId = _intKey(entry.key) ?? memo.id;
      if (memo.syncId == null || memo.updatedAt == null || memo.id != localId) {
        memo.id = localId;
        memo.syncId ??= _legacyMemoSyncId(memo.mapId, localId);
        memo.updatedAt ??= DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        await memoBox.put(entry.key, memo);
      }
    }
  }

  static int? _intKey(Object? key) {
    if (key is int) return key;
    return int.tryParse(key?.toString() ?? '');
  }

  static String _legacyMapSyncId(int? id) =>
      id == null ? _uuid.v4() : 'legacy-map-$id';

  static String _legacyMemoSyncId(int? mapId, int? id) =>
      id == null ? _uuid.v4() : 'legacy-memo-${mapId ?? 'none'}-$id';

  static Memo _withSyncMetadata(Memo memo, {bool touch = false}) {
    memo.syncId ??= _legacyMemoSyncId(memo.mapId, memo.id);
    memo.updatedAt ??= touch
        ? DateTime.now().toUtc()
        : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return memo;
  }

  static MapInfo _mapWithSyncMetadata(
    MapInfo map, {
    int? id,
    bool touch = false,
  }) {
    final localId = id ?? map.id;
    return MapInfo(
      id: localId,
      title: map.title,
      imagePath: map.imagePath,
      syncId: map.syncId ?? _legacyMapSyncId(localId),
      updatedAt:
          map.updatedAt ??
          (touch
              ? DateTime.now().toUtc()
              : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)),
    );
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('memos.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    final db = await openDatabase(
      path,
      version: 9,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );

    // レイヤー列が存在しない場合は追加
    await _ensureLayerColumn(db);
    await _ensureSyncColumns(db);

    return db;
  }

  Future<void> _ensureLayerColumn(Database db) async {
    final result = await db.rawQuery('PRAGMA table_info(memos)');
    final hasLayer = result.any((row) => row['name'] == 'layer');
    if (!hasLayer) {
      await db.execute('ALTER TABLE memos ADD COLUMN layer INTEGER');
    }
  }

  Future<void> _ensureSyncColumns(Database db) async {
    final memoColumns = await db.rawQuery('PRAGMA table_info(memos)');
    final memoNames = memoColumns.map((row) => row['name']).toSet();
    if (!memoNames.contains('syncId')) {
      await db.execute('ALTER TABLE memos ADD COLUMN syncId TEXT');
    }
    if (!memoNames.contains('updatedAt')) {
      await db.execute('ALTER TABLE memos ADD COLUMN updatedAt INTEGER');
    }

    final mapColumns = await db.rawQuery('PRAGMA table_info(maps)');
    final mapNames = mapColumns.map((row) => row['name']).toSet();
    if (!mapNames.contains('syncId')) {
      await db.execute('ALTER TABLE maps ADD COLUMN syncId TEXT');
    }
    if (!mapNames.contains('updatedAt')) {
      await db.execute('ALTER TABLE maps ADD COLUMN updatedAt INTEGER');
    }

    final epoch = DateTime.fromMillisecondsSinceEpoch(0).millisecondsSinceEpoch;
    await db.execute(
      "UPDATE maps SET syncId = 'legacy-map-' || id WHERE syncId IS NULL OR syncId = ''",
    );
    await db.execute(
      "UPDATE memos SET syncId = 'legacy-memo-' || COALESCE(mapId, 'none') || '-' || id WHERE syncId IS NULL OR syncId = ''",
    );
    await db.execute('UPDATE maps SET updatedAt = ? WHERE updatedAt IS NULL', [
      epoch,
    ]);
    await db.execute('UPDATE memos SET updatedAt = ? WHERE updatedAt IS NULL', [
      epoch,
    ]);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL';
    const intType = 'INTEGER';
    const textNullType = 'TEXT';

    await db.execute('''
CREATE TABLE memos (
  id $idType,
  title $textType,
  content $textType,
  latitude $realType,
  longitude $realType,
  discoveryTime $intType,
  discoverer $textNullType,
  specimenNumber $textNullType,
  category $textNullType,
  notes $textNullType,
  mapId $intType,
  pinNumber $intType,
  audioPath $textNullType,
  imagePaths $textNullType,
  mushroomCapShape $textNullType,
  mushroomCapColor $textNullType,
  mushroomCapSurface $textNullType,
  mushroomCapSize $textNullType,
  mushroomCapUnderStructure $textNullType,
  mushroomGillFeature $textNullType,
  mushroomStemPresence $textNullType,
  mushroomStemShape $textNullType,
  mushroomStemColor $textNullType,
  mushroomStemSurface $textNullType,
  mushroomRingPresence $textNullType,
  mushroomVolvaPresence $textNullType,
  mushroomHabitat $textNullType,
  mushroomGrowthPattern $textNullType,
  layer $intType,
  syncId $textNullType,
  updatedAt $intType
)
''');

    await db.execute('''
CREATE TABLE maps (
  id $idType,
  title $textType,
  imagePath $textNullType,
  syncId $textNullType,
  updatedAt $intType
)
''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE memos ADD COLUMN discoveryTime INTEGER');
      await db.execute('ALTER TABLE memos ADD COLUMN discoverer TEXT');
      await db.execute('ALTER TABLE memos ADD COLUMN specimenNumber TEXT');
      await db.execute('ALTER TABLE memos ADD COLUMN category TEXT');
      await db.execute('ALTER TABLE memos ADD COLUMN notes TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE memos ADD COLUMN mapId INTEGER');
      await db.execute('''
CREATE TABLE maps (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL
)
''');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE maps ADD COLUMN imagePath TEXT');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE memos ADD COLUMN pinNumber INTEGER');
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE memos ADD COLUMN audioPath TEXT');
    }
    if (oldVersion < 7) {
      await db.execute('ALTER TABLE memos ADD COLUMN imagePaths TEXT');
    }
    if (oldVersion < 8) {
      // キノコ詳細情報フィールドを追加
      await db.execute('ALTER TABLE memos ADD COLUMN mushroomCapShape TEXT');
      await db.execute('ALTER TABLE memos ADD COLUMN mushroomCapColor TEXT');
      await db.execute('ALTER TABLE memos ADD COLUMN mushroomCapSurface TEXT');
      await db.execute('ALTER TABLE memos ADD COLUMN mushroomCapSize TEXT');
      await db.execute(
        'ALTER TABLE memos ADD COLUMN mushroomCapUnderStructure TEXT',
      );
      await db.execute('ALTER TABLE memos ADD COLUMN mushroomGillFeature TEXT');
      await db.execute(
        'ALTER TABLE memos ADD COLUMN mushroomStemPresence TEXT',
      );
      await db.execute('ALTER TABLE memos ADD COLUMN mushroomStemShape TEXT');
      await db.execute('ALTER TABLE memos ADD COLUMN mushroomStemColor TEXT');
      await db.execute('ALTER TABLE memos ADD COLUMN mushroomStemSurface TEXT');
      await db.execute(
        'ALTER TABLE memos ADD COLUMN mushroomRingPresence TEXT',
      );
      await db.execute(
        'ALTER TABLE memos ADD COLUMN mushroomVolvaPresence TEXT',
      );
      await db.execute('ALTER TABLE memos ADD COLUMN mushroomHabitat TEXT');
      await db.execute(
        'ALTER TABLE memos ADD COLUMN mushroomGrowthPattern TEXT',
      );
    }
    if (oldVersion < 9) {
      await db.execute('ALTER TABLE memos ADD COLUMN layer INTEGER');
    }
  }

  @override
  Future<Memo> create(Memo memo) async {
    memo.syncId ??= _uuid.v4();
    memo.updatedAt = DateTime.now().toUtc();
    if (kIsWeb) {
      await init();
      final key = await _memoBox!.add(memo);
      memo.id = _intKey(key);
      await _memoBox!.put(key, memo);
      return memo;
    } else {
      final db = await instance.database;
      final id = await db.insert('memos', memo.toMap());
      return memo..id = id;
    }
  }

  @override
  Future<MapInfo> createMap(MapInfo mapInfo) async {
    final prepared = MapInfo(
      title: mapInfo.title,
      imagePath: mapInfo.imagePath,
      syncId: mapInfo.syncId ?? _uuid.v4(),
      updatedAt: mapInfo.updatedAt ?? DateTime.now().toUtc(),
    );
    if (kIsWeb) {
      await init();
      final key = await _mapBox!.add(prepared);

      // キーをintに変換（Hiveのキーはdynamicなのでintにキャスト）
      int? convertedId;
      convertedId = key;

      final stored = MapInfo(
        id: convertedId,
        title: prepared.title,
        imagePath: prepared.imagePath,
        syncId: prepared.syncId,
        updatedAt: prepared.updatedAt,
      );
      await _mapBox!.put(key, stored);
      return stored;
    } else {
      final db = await instance.database;
      final data = Map<String, dynamic>.from(prepared.toMap())..remove('id');
      final id = await db.insert('maps', data);
      return prepared.copyWith(id: id);
    }
  }

  @override
  Future<Memo> readMemo(int id) async {
    if (kIsWeb) {
      await init();
      final memo = _memoBox!.get(id);
      if (memo != null) {
        return memo;
      } else {
        throw Exception('ID $id not found');
      }
    } else {
      final db = await instance.database;
      final maps = await db.query(
        'memos',
        columns: [
          'id',
          'title',
          'content',
          'latitude',
          'longitude',
          'discoveryTime',
          'discoverer',
          'specimenNumber',
          'category',
          'notes',
          'mapId',
          'pinNumber',
          'audioPath',
          'imagePaths',
          'mushroomCapShape',
          'mushroomCapColor',
          'mushroomCapSurface',
          'mushroomCapSize',
          'mushroomCapUnderStructure',
          'mushroomGillFeature',
          'mushroomStemPresence',
          'mushroomStemShape',
          'mushroomStemColor',
          'mushroomStemSurface',
          'mushroomRingPresence',
          'mushroomVolvaPresence',
          'mushroomHabitat',
          'mushroomGrowthPattern',
          'layer',
          'syncId',
          'updatedAt',
        ],
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isNotEmpty) {
        return Memo.fromMap(maps.first);
      } else {
        throw Exception('ID $id not found');
      }
    }
  }

  @override
  Future<List<Memo>> readAllMemos() async {
    if (kIsWeb) {
      await init();
      return _memoBox!.values.toList();
    } else {
      final db = await instance.database;
      const orderBy = 'id ASC';
      final result = await db.query('memos', orderBy: orderBy);

      return result.map((json) => Memo.fromMap(json)).toList();
    }
  }

  // 地図の名前を含むメモ一覧を取得
  @override
  Future<List<Memo>> readAllMemosWithMapTitle() async {
    if (kIsWeb) {
      await init();
      final memos = _memoBox!.values.toList();
      final maps = _mapBox!.values.toList();

      // 地図タイトルを設定
      for (var memo in memos) {
        if (memo.mapId != null) {
          final map = maps.firstWhere(
            (m) => m.id == memo.mapId,
            orElse: () => const MapInfo(title: '不明な地図'),
          );
          memo.mapTitle = map.title;
        }
      }

      return memos;
    } else {
      final db = await instance.database;
      final result = await db.rawQuery('''
        SELECT m.*, mp.title as mapTitle 
        FROM memos m 
        LEFT JOIN maps mp ON m.mapId = mp.id 
        ORDER BY m.id ASC
      ''');

      return result.map((json) => Memo.fromMap(json)).toList();
    }
  }

  // タイトルでメモを検索
  Future<List<Memo>> searchMemosByTitle(String searchQuery) async {
    if (kIsWeb) {
      await init();
      final memos = _memoBox!.values.toList();
      final maps = _mapBox!.values.toList();

      final filteredMemos = memos
          .where(
            (memo) =>
                memo.title.toLowerCase().contains(searchQuery.toLowerCase()),
          )
          .toList();

      // 地図タイトルを設定
      for (var memo in filteredMemos) {
        if (memo.mapId != null) {
          final map = maps.firstWhere(
            (m) => m.id == memo.mapId,
            orElse: () => const MapInfo(title: '不明な地図'),
          );
          memo.mapTitle = map.title;
        }
      }

      return filteredMemos;
    } else {
      final db = await instance.database;
      final result = await db.rawQuery(
        '''
        SELECT m.*, mp.title as mapTitle 
        FROM memos m 
        LEFT JOIN maps mp ON m.mapId = mp.id 
        WHERE m.title LIKE ? 
        ORDER BY m.id ASC
      ''',
        ['%$searchQuery%'],
      );

      return result.map((json) => Memo.fromMap(json)).toList();
    }
  }

  // 地図の名前でメモを検索
  Future<List<Memo>> searchMemosByMapTitle(String searchQuery) async {
    if (kIsWeb) {
      await init();
      final memos = _memoBox!.values.toList();
      final maps = _mapBox!.values.toList();

      // 検索クエリに一致する地図IDを取得
      final matchingMaps = maps
          .where(
            (map) =>
                map.title.toLowerCase().contains(searchQuery.toLowerCase()),
          )
          .toList();

      final matchingMapIds = matchingMaps.map((map) => map.id).toSet();

      final filteredMemos = memos
          .where(
            (memo) => memo.mapId != null && matchingMapIds.contains(memo.mapId),
          )
          .toList();

      // 地図タイトルを設定
      for (var memo in filteredMemos) {
        if (memo.mapId != null) {
          final map = maps.firstWhere(
            (m) => m.id == memo.mapId,
            orElse: () => const MapInfo(title: '不明な地図'),
          );
          memo.mapTitle = map.title;
        }
      }

      return filteredMemos;
    } else {
      final db = await instance.database;
      final result = await db.rawQuery(
        '''
        SELECT m.*, mp.title as mapTitle 
        FROM memos m 
        LEFT JOIN maps mp ON m.mapId = mp.id 
        WHERE mp.title LIKE ? 
        ORDER BY m.id ASC
      ''',
        ['%$searchQuery%'],
      );

      return result.map((json) => Memo.fromMap(json)).toList();
    }
  }

  // タイトルまたは地図の名前でメモを検索
  Future<List<Memo>> searchMemos(String searchQuery) async {
    if (kIsWeb) {
      await init();
      final memos = _memoBox!.values.toList();
      final maps = _mapBox!.values.toList();

      // 検索クエリに一致する地図IDを取得
      final matchingMaps = maps
          .where(
            (map) =>
                map.title.toLowerCase().contains(searchQuery.toLowerCase()),
          )
          .toList();

      final matchingMapIds = matchingMaps.map((map) => map.id).toSet();

      final filteredMemos = memos
          .where(
            (memo) =>
                memo.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
                (memo.mapId != null && matchingMapIds.contains(memo.mapId)),
          )
          .toList();

      // 地図タイトルを設定
      for (var memo in filteredMemos) {
        if (memo.mapId != null) {
          final map = maps.firstWhere(
            (m) => m.id == memo.mapId,
            orElse: () => const MapInfo(title: '不明な地図'),
          );
          memo.mapTitle = map.title;
        }
      }

      return filteredMemos;
    } else {
      final db = await instance.database;
      final result = await db.rawQuery(
        '''
        SELECT m.*, mp.title as mapTitle 
        FROM memos m 
        LEFT JOIN maps mp ON m.mapId = mp.id 
        WHERE m.title LIKE ? OR mp.title LIKE ? 
        ORDER BY m.id ASC
      ''',
        ['%$searchQuery%', '%$searchQuery%'],
      );

      return result.map((json) => Memo.fromMap(json)).toList();
    }
  }

  // 特定の地図IDのメモのみを取得
  @override
  Future<List<Memo>> readMemosByMapId(int? mapId) async {
    if (kIsWeb) {
      await init();
      final memos = _memoBox!.values.toList();

      return memos.where((memo) {
        if (mapId == null) {
          return memo.mapId == null;
        } else {
          return memo.mapId == mapId;
        }
      }).toList();
    } else {
      final db = await instance.database;
      final result = await db.query(
        'memos',
        where: mapId != null ? 'mapId = ?' : 'mapId IS NULL',
        whereArgs: mapId != null ? [mapId] : null,
        orderBy: 'id ASC',
      );

      return result.map((json) => Memo.fromMap(json)).toList();
    }
  }

  // 特定の地図画像パスのメモを取得（既存の地図ファイル用）
  Future<List<Memo>> readMemosByMapPath(String? mapImagePath) async {
    if (kIsWeb) {
      await init();
      final memos = _memoBox!.values.toList();
      final maps = _mapBox!.values.toList();

      if (mapImagePath == null) {
        // 地図画像パスがnullの場合は、mapIdもnullのメモを取得
        return memos.where((memo) => memo.mapId == null).toList();
      }

      // 地図画像パスから地図IDを取得してメモを検索
      final matchingMap = maps.firstWhere(
        (map) => map.imagePath == mapImagePath,
        orElse: () => const MapInfo(title: ''),
      );

      if (matchingMap.id != null) {
        return readMemosByMapId(matchingMap.id);
      } else {
        // 該当する地図がない場合は、mapIdがnullのメモを取得（デフォルト地図用）
        return memos.where((memo) => memo.mapId == null).toList();
      }
    } else {
      final db = await instance.database;

      if (mapImagePath == null) {
        // 地図画像パスがnullの場合は、mapIdもnullのメモを取得
        final result = await db.query(
          'memos',
          where: 'mapId IS NULL',
          orderBy: 'id ASC',
        );
        return result.map((json) => Memo.fromMap(json)).toList();
      }

      // 地図画像パスから地図IDを取得してメモを検索
      final mapResult = await db.query(
        'maps',
        where: 'imagePath = ?',
        whereArgs: [mapImagePath],
      );

      if (mapResult.isNotEmpty) {
        final mapId = mapResult.first['id'] as int;
        return readMemosByMapId(mapId);
      } else {
        // 該当する地図がない場合は、mapIdがnullのメモを取得（デフォルト地図用）
        final result = await db.query(
          'memos',
          where: 'mapId IS NULL',
          orderBy: 'id ASC',
        );
        return result.map((json) => Memo.fromMap(json)).toList();
      }
    }
  }

  // 地図画像パスから地図IDを取得（なければ作成）
  Future<int?> getOrCreateMapId(String? mapImagePath, String? mapTitle) async {
    if (mapImagePath == null) return null;

    if (kIsWeb) {
      await init();
      final maps = _mapBox!.values.toList();

      // 既存の地図を検索
      final existing = maps.firstWhere(
        (map) => map.imagePath == mapImagePath,
        orElse: () => const MapInfo(title: ''),
      );

      if (existing.id != null) {
        return existing.id;
      } else {
        // 新しい地図を作成
        final mapInfo = MapInfo(
          title: mapTitle ?? 'カスタム地図',
          imagePath: mapImagePath,
        );
        final created = await createMap(mapInfo);
        return created.id;
      }
    } else {
      final db = await instance.database;

      // 既存の地図を検索
      final existing = await db.query(
        'maps',
        where: 'imagePath = ?',
        whereArgs: [mapImagePath],
      );

      if (existing.isNotEmpty) {
        return existing.first['id'] as int;
      } else {
        // 新しい地図を作成
        final mapInfo = MapInfo(
          title: mapTitle ?? 'カスタム地図',
          imagePath: mapImagePath,
        );
        final created = await createMap(mapInfo);
        return created.id;
      }
    }
  }

  @override
  Future<List<MapInfo>> readAllMaps() async {
    if (kIsWeb) {
      await init();
      final mapsList = <MapInfo>[];

      // HiveのBoxから全ての地図を取得し、キーをIDとして設定
      for (final entry in _mapBox!.toMap().entries) {
        final key = entry.key;
        final mapInfo = entry.value;

        // キーをintに変換
        int? convertedId;
        if (key is int) {
          convertedId = key;
        } else if (key != null) {
          final keyString = key.toString();
          convertedId = int.tryParse(keyString);
        }

        // IDが設定されたMapInfoを作成
        final mapWithId = MapInfo(
          id: convertedId,
          title: mapInfo.title,
          imagePath: mapInfo.imagePath,
          syncId: mapInfo.syncId ?? _legacyMapSyncId(convertedId),
          updatedAt:
              mapInfo.updatedAt ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        );

        mapsList.add(mapWithId);
      }

      return mapsList;
    } else {
      final db = await instance.database;
      const orderBy = 'id ASC';
      final result = await db.query('maps', orderBy: orderBy);

      return result.map((json) => MapInfo.fromMap(json)).toList();
    }
  }

  @override
  Future<int> update(Memo memo) async {
    _withSyncMetadata(memo, touch: true);
    if (kIsWeb) {
      await init();
      if (memo.id != null) {
        await _memoBox!.put(memo.id, memo);
        return 1; // 成功を示す
      }
      return 0; // 失敗を示す
    } else {
      final db = await instance.database;

      return db.update(
        'memos',
        memo.toMap(),
        where: 'id = ?',
        whereArgs: [memo.id],
      );
    }
  }

  @override
  Future<int> updateMap(MapInfo mapInfo) async {
    final prepared = _mapWithSyncMetadata(mapInfo, touch: true);
    if (kIsWeb) {
      await init();
      if (prepared.id != null) {
        await _mapBox!.put(prepared.id, prepared);
        return 1; // 成功を示す
      }
      return 0; // 失敗を示す
    } else {
      final db = await instance.database;

      return db.update(
        'maps',
        prepared.toMap(),
        where: 'id = ?',
        whereArgs: [prepared.id],
      );
    }
  }

  @override
  Future<int> delete(int id) async {
    if (kIsWeb) {
      await init();
      await _memoBox!.delete(id);
      return 1; // 成功を示す
    } else {
      final db = await instance.database;

      return await db.delete('memos', where: 'id = ?', whereArgs: [id]);
    }
  }

  @override
  Future<int> deleteMap(int id) async {
    if (kIsWeb) {
      await init();

      // 関連するメモを削除
      final relatedMemoKeys = <dynamic>[];

      for (var entry in _memoBox!.toMap().entries) {
        if (entry.value.mapId == id) {
          relatedMemoKeys.add(entry.key);
        }
      }

      for (var key in relatedMemoKeys) {
        await _memoBox!.delete(key);
      }

      // 地図を削除
      await _mapBox!.delete(id);
      return 1; // 成功を示す
    } else {
      final db = await instance.database;

      await db.delete('memos', where: 'mapId = ?', whereArgs: [id]);

      return await db.delete('maps', where: 'id = ?', whereArgs: [id]);
    }
  }

  @override
  Future<void> deleteAllMemos() async {
    if (kIsWeb) {
      await init();
      await _memoBox!.clear();
    } else {
      final db = await instance.database;
      await db.delete('memos');
    }
  }

  @override
  Future<void> deleteAllMaps() async {
    if (kIsWeb) {
      await init();
      await _mapBox!.clear();
    } else {
      final db = await instance.database;
      await db.delete('maps');
    }
  }

  @override
  Future<void> upsertMapInfo(MapInfo mapInfo) async {
    final prepared = _mapWithSyncMetadata(mapInfo);
    if (kIsWeb) {
      await init();
      if (prepared.id == null) {
        final created = await createMap(prepared);
        if (created.id != null) {
          await _mapBox!.put(created.id, created);
        }
      } else {
        final stored = MapInfo(
          id: prepared.id,
          title: prepared.title,
          imagePath: prepared.imagePath,
          syncId: prepared.syncId,
          updatedAt: prepared.updatedAt,
        );
        await _mapBox!.put(prepared.id, stored);
      }
    } else {
      final db = await instance.database;
      final data = Map<String, dynamic>.from(prepared.toMap());
      await db.insert(
        'maps',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  @override
  Future<void> replaceMemosForMap(int mapId, List<Memo> memos) async {
    if (kIsWeb) {
      await init();
      final keysToDelete = <dynamic>[];
      for (final entry in _memoBox!.toMap().entries) {
        if (entry.value.mapId == mapId) {
          keysToDelete.add(entry.key);
        }
      }
      await _memoBox!.deleteAll(keysToDelete);

      for (final memo in memos) {
        memo.mapId = mapId;
        _withSyncMetadata(memo);
        if (memo.id != null) {
          await _memoBox!.put(memo.id, memo);
        } else {
          final key = await _memoBox!.add(memo);
          memo.id = key;
        }
      }
    } else {
      final db = await instance.database;
      await db.delete('memos', where: 'mapId = ?', whereArgs: [mapId]);

      for (final memo in memos) {
        memo.mapId = mapId;
        _withSyncMetadata(memo);
        final data = Map<String, dynamic>.from(memo.toMap());
        if (memo.id == null) {
          data.remove('id');
          final newId = await db.insert('memos', data);
          memo.id = newId;
        } else {
          await db.insert(
            'memos',
            data,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    }
  }

  @override
  Future<void> upsertMemosForMap(int mapId, List<Memo> memos) async {
    if (kIsWeb) {
      await init();
      for (final memo in memos) {
        memo.mapId = mapId;
        _withSyncMetadata(memo);
        MapEntry<dynamic, Memo>? existingEntry;
        for (final entry in _memoBox!.toMap().entries) {
          if (entry.value.mapId == mapId && entry.value.syncId == memo.syncId) {
            existingEntry = entry;
            break;
          }
        }
        if (existingEntry != null) {
          final localUpdated =
              existingEntry.value.updatedAt ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
          final remoteUpdated =
              memo.updatedAt ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
          if (remoteUpdated.isBefore(localUpdated)) continue;
          memo.id ??= _intKey(existingEntry.key);
          await _memoBox!.put(existingEntry.key, memo);
        } else if (memo.id != null &&
            _memoBox!.get(memo.id)?.syncId == memo.syncId) {
          await _memoBox!.put(memo.id, memo);
        } else {
          final key = await _memoBox!.add(memo);
          memo.id = _intKey(key);
          await _memoBox!.put(key, memo);
        }
      }
      return;
    }

    final db = await instance.database;
    await db.transaction((txn) async {
      for (final memo in memos) {
        memo.mapId = mapId;
        _withSyncMetadata(memo);
        final existing = await txn.query(
          'memos',
          columns: ['id', 'updatedAt'],
          where: 'mapId = ? AND syncId = ?',
          whereArgs: [mapId, memo.syncId],
          limit: 1,
        );
        final data = Map<String, dynamic>.from(memo.toMap());
        if (existing.isNotEmpty) {
          final localUpdated = existing.first['updatedAt'] as int? ?? 0;
          final remoteUpdated = memo.updatedAt?.millisecondsSinceEpoch ?? 0;
          if (remoteUpdated >= localUpdated) {
            final id = existing.first['id'] as int;
            data['id'] = id;
            memo.id = id;
            await txn.update('memos', data, where: 'id = ?', whereArgs: [id]);
          }
        } else {
          // A numeric id belongs to the source device. Always allocate a local
          // id so an unrelated local record cannot be overwritten.
          data.remove('id');
          memo.id = await txn.insert(
            'memos',
            data,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  @override
  Future<void> deleteMemosBySyncIds(int mapId, Set<String> syncIds) async {
    if (syncIds.isEmpty) return;
    if (kIsWeb) {
      await init();
      final keys = <dynamic>[];
      for (final entry in _memoBox!.toMap().entries) {
        if (entry.value.mapId == mapId &&
            syncIds.contains(entry.value.syncId)) {
          keys.add(entry.key);
        }
      }
      await _memoBox!.deleteAll(keys);
      return;
    }

    final db = await instance.database;
    final placeholders = List.filled(syncIds.length, '?').join(',');
    await db.delete(
      'memos',
      where: 'mapId = ? AND syncId IN ($placeholders)',
      whereArgs: [mapId, ...syncIds],
    );
  }

  @override
  Future<Map<int, int>> replaceAllDataAtomically(
    List<MapInfo> maps,
    List<Memo> memos,
  ) async {
    if (kIsWeb) {
      await init();
      final previousMaps = Map<dynamic, MapInfo>.from(_mapBox!.toMap());
      final previousMemos = Map<dynamic, Memo>.from(_memoBox!.toMap());
      final idMap = <int, int>{};
      await _beginHiveMutationJournal(previousMaps, previousMemos);
      try {
        await _memoBox!.clear();
        await _mapBox!.clear();
        for (final map in maps) {
          final stored = MapInfo(
            title: map.title,
            imagePath: map.imagePath,
            syncId: map.syncId,
            updatedAt: map.updatedAt,
          );
          final key = await _mapBox!.add(stored);
          final newId = _intKey(key);
          if (newId == null) throw StateError('Local map id was not allocated');
          await _mapBox!.put(key, stored.copyWith(id: newId));
          if (map.id != null) idMap[map.id!] = newId;
        }
        for (final memo in memos) {
          final data = Map<String, dynamic>.from(memo.toMap())
            ..remove('id')
            ..['mapId'] = memo.mapId == null ? null : idMap[memo.mapId!];
          final stored = Memo.fromMap(data);
          final key = await _memoBox!.add(stored);
          stored.id = _intKey(key);
          await _memoBox!.put(key, stored);
        }
        await _finishHiveMutationJournal();
        return idMap;
      } catch (_) {
        await _memoBox!.clear();
        await _mapBox!.clear();
        await _mapBox!.putAll(previousMaps);
        await _memoBox!.putAll(previousMemos);
        await _finishHiveMutationJournal();
        rethrow;
      }
    }

    final db = await instance.database;
    return db.transaction((txn) async {
      final idMap = <int, int>{};
      await txn.delete('memos');
      await txn.delete('maps');
      for (final map in maps) {
        final data = Map<String, dynamic>.from(map.toMap())..remove('id');
        final newId = await txn.insert('maps', data);
        if (map.id != null) idMap[map.id!] = newId;
      }
      for (final memo in memos) {
        final data = Map<String, dynamic>.from(memo.toMap())..remove('id');
        if (memo.mapId != null) data['mapId'] = idMap[memo.mapId!];
        await txn.insert('memos', data);
      }
      return idMap;
    });
  }

  @override
  Future<void> clearAllDataAtomically() async {
    if (kIsWeb) {
      await init();
      final previousMaps = Map<dynamic, MapInfo>.from(_mapBox!.toMap());
      final previousMemos = Map<dynamic, Memo>.from(_memoBox!.toMap());
      await _beginHiveMutationJournal(previousMaps, previousMemos);
      try {
        await _memoBox!.clear();
        await _mapBox!.clear();
        await _finishHiveMutationJournal();
      } catch (_) {
        await _mapBox!.putAll(previousMaps);
        await _memoBox!.putAll(previousMemos);
        await _finishHiveMutationJournal();
        rethrow;
      }
      return;
    }
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('memos');
      await txn.delete('maps');
    });
  }

  Future close() async {
    if (kIsWeb) {
      await _mapBox?.close();
      await _memoBox?.close();
    } else {
      final db = await instance.database;
      db.close();
    }
  }
}
