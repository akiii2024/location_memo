import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/memo.dart';
import '../models/map_info.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static Box<MapInfo>? _mapBox;
  static Box<Memo>? _memoBox;

  DatabaseHelper._init();

  Future<void> init() async {
    if (kIsWeb) {
      await Hive.initFlutter();
      // Hiveアダプターの登録（partファイルから自動的に利用可能）
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(MapInfoAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(MemoAdapter());
      }
      _mapBox = await Hive.openBox<MapInfo>('maps');
      _memoBox = await Hive.openBox<Memo>('memos');
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('memos.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    final db = await openDatabase(path,
        version: 9, onCreate: _createDB, onUpgrade: _upgradeDB);

    // レイヤー列が存在しない場合は追加
    await _ensureLayerColumn(db);

    return db;
  }

  Future<void> _ensureLayerColumn(Database db) async {
    final result = await db.rawQuery('PRAGMA table_info(memos)');
    final hasLayer = result.any((row) => row['name'] == 'layer');
    if (!hasLayer) {
      await db.execute('ALTER TABLE memos ADD COLUMN layer INTEGER');
    }
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
  layer $intType
)
''');

    await db.execute('''
CREATE TABLE maps (
  id $idType,
  title $textType,
  imagePath $textNullType
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
          'ALTER TABLE memos ADD COLUMN mushroomCapUnderStructure TEXT');
      await db.execute('ALTER TABLE memos ADD COLUMN mushroomGillFeature TEXT');
      await db
          .execute('ALTER TABLE memos ADD COLUMN mushroomStemPresence TEXT');
      await db.execute('ALTER TABLE memos ADD COLUMN mushroomStemShape TEXT');
      await db.execute('ALTER TABLE memos ADD COLUMN mushroomStemColor TEXT');
      await db.execute('ALTER TABLE memos ADD COLUMN mushroomStemSurface TEXT');
      await db
          .execute('ALTER TABLE memos ADD COLUMN mushroomRingPresence TEXT');
      await db
          .execute('ALTER TABLE memos ADD COLUMN mushroomVolvaPresence TEXT');
      await db.execute('ALTER TABLE memos ADD COLUMN mushroomHabitat TEXT');
      await db
          .execute('ALTER TABLE memos ADD COLUMN mushroomGrowthPattern TEXT');
    }
    if (oldVersion < 9) {
      await db.execute('ALTER TABLE memos ADD COLUMN layer INTEGER');
    }
  }

  Future<Memo> create(Memo memo) async {
    if (kIsWeb) {
      await init();
      final key = await _memoBox!.add(memo);
      return Memo(
        id: key,
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
        imagePaths: memo.imagePaths,
        // キノコ詳細情報
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
        layer: memo.layer,
      );
    } else {
      final db = await instance.database;
      final id = await db.insert('memos', memo.toMap());
      return memo..id = id;
    }
  }

  Future<MapInfo> createMap(MapInfo mapInfo) async {
    if (kIsWeb) {
      await init();
      final key = await _mapBox!.add(mapInfo);

      // キーをintに変換（Hiveのキーはdynamicなのでintにキャスト）
      int? convertedId;
      if (key is int) {
        convertedId = key;
      } else if (key != null) {
        // 文字列や他の型の場合はint型に変換を試行
        final keyString = key.toString();
        convertedId = int.tryParse(keyString);
      }

      return MapInfo(
        id: convertedId,
        title: mapInfo.title,
        imagePath: mapInfo.imagePath,
      );
    } else {
      final db = await instance.database;
      final id = await db.insert('maps', mapInfo.toMap());
      return MapInfo(
          id: id, title: mapInfo.title, imagePath: mapInfo.imagePath);
    }
  }

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
          'mushroomGrowthPattern'
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
            orElse: () => MapInfo(title: '不明な地図'),
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
          .where((memo) =>
              memo.title.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();

      // 地図タイトルを設定
      for (var memo in filteredMemos) {
        if (memo.mapId != null) {
          final map = maps.firstWhere(
            (m) => m.id == memo.mapId,
            orElse: () => MapInfo(title: '不明な地図'),
          );
          memo.mapTitle = map.title;
        }
      }

      return filteredMemos;
    } else {
      final db = await instance.database;
      final result = await db.rawQuery('''
        SELECT m.*, mp.title as mapTitle 
        FROM memos m 
        LEFT JOIN maps mp ON m.mapId = mp.id 
        WHERE m.title LIKE ? 
        ORDER BY m.id ASC
      ''', ['%$searchQuery%']);

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
          .where((map) =>
              map.title.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();

      final matchingMapIds = matchingMaps.map((map) => map.id).toSet();

      final filteredMemos = memos
          .where((memo) =>
              memo.mapId != null && matchingMapIds.contains(memo.mapId))
          .toList();

      // 地図タイトルを設定
      for (var memo in filteredMemos) {
        if (memo.mapId != null) {
          final map = maps.firstWhere(
            (m) => m.id == memo.mapId,
            orElse: () => MapInfo(title: '不明な地図'),
          );
          memo.mapTitle = map.title;
        }
      }

      return filteredMemos;
    } else {
      final db = await instance.database;
      final result = await db.rawQuery('''
        SELECT m.*, mp.title as mapTitle 
        FROM memos m 
        LEFT JOIN maps mp ON m.mapId = mp.id 
        WHERE mp.title LIKE ? 
        ORDER BY m.id ASC
      ''', ['%$searchQuery%']);

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
          .where((map) =>
              map.title.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();

      final matchingMapIds = matchingMaps.map((map) => map.id).toSet();

      final filteredMemos = memos
          .where((memo) =>
              memo.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
              (memo.mapId != null && matchingMapIds.contains(memo.mapId)))
          .toList();

      // 地図タイトルを設定
      for (var memo in filteredMemos) {
        if (memo.mapId != null) {
          final map = maps.firstWhere(
            (m) => m.id == memo.mapId,
            orElse: () => MapInfo(title: '不明な地図'),
          );
          memo.mapTitle = map.title;
        }
      }

      return filteredMemos;
    } else {
      final db = await instance.database;
      final result = await db.rawQuery('''
        SELECT m.*, mp.title as mapTitle 
        FROM memos m 
        LEFT JOIN maps mp ON m.mapId = mp.id 
        WHERE m.title LIKE ? OR mp.title LIKE ? 
        ORDER BY m.id ASC
      ''', ['%$searchQuery%', '%$searchQuery%']);

      return result.map((json) => Memo.fromMap(json)).toList();
    }
  }

  // 特定の地図IDのメモのみを取得
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
        orElse: () => MapInfo(title: ''),
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
        orElse: () => MapInfo(title: ''),
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

  Future<int> update(Memo memo) async {
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

  Future<int> updateMap(MapInfo mapInfo) async {
    if (kIsWeb) {
      await init();
      if (mapInfo.id != null) {
        await _mapBox!.put(mapInfo.id, mapInfo);
        return 1; // 成功を示す
      }
      return 0; // 失敗を示す
    } else {
      final db = await instance.database;

      return db.update(
        'maps',
        mapInfo.toMap(),
        where: 'id = ?',
        whereArgs: [mapInfo.id],
      );
    }
  }

  Future<int> delete(int id) async {
    if (kIsWeb) {
      await init();
      await _memoBox!.delete(id);
      return 1; // 成功を示す
    } else {
      final db = await instance.database;

      return await db.delete(
        'memos',
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<int> deleteMap(int id) async {
    if (kIsWeb) {
      await init();

      // 関連するメモを削除
      final memos = _memoBox!.values.toList();
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

      await db.delete(
        'memos',
        where: 'mapId = ?',
        whereArgs: [id],
      );

      return await db.delete(
        'maps',
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> deleteAllMemos() async {
    if (kIsWeb) {
      await init();
      await _memoBox!.clear();
    } else {
      final db = await instance.database;
      await db.delete('memos');
    }
  }

  Future<void> deleteAllMaps() async {
    if (kIsWeb) {
      await init();
      await _mapBox!.clear();
    } else {
      final db = await instance.database;
      await db.delete('maps');
    }
  }

  Future<void> upsertMapInfo(MapInfo mapInfo) async {
    if (kIsWeb) {
      await init();
      if (mapInfo.id == null) {
        final created = await createMap(mapInfo);
        if (created.id != null) {
          await _mapBox!.put(created.id, created);
        }
      } else {
        final stored = MapInfo(
          id: mapInfo.id,
          title: mapInfo.title,
          imagePath: mapInfo.imagePath,
        );
        await _mapBox!.put(mapInfo.id, stored);
      }
    } else {
      final db = await instance.database;
      final data = Map<String, dynamic>.from(mapInfo.toMap());
      await db.insert(
        'maps',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

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
        if (memo.id != null) {
          await _memoBox!.put(memo.id, memo);
        } else {
          final key = await _memoBox!.add(memo);
          if (key is int) {
            memo.id = key;
          } else {
            final parsed = int.tryParse(key.toString());
            if (parsed != null) {
              memo.id = parsed;
            }
          }
        }
      }
    } else {
      final db = await instance.database;
      await db.delete('memos', where: 'mapId = ?', whereArgs: [mapId]);

      for (final memo in memos) {
        memo.mapId = mapId;
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
