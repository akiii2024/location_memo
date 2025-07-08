import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/memo.dart';
import '../models/map_info.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('memos.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path,
        version: 5, onCreate: _createDB, onUpgrade: _upgradeDB);
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
  pinNumber $intType
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
    // pinNumberカラムは_createDBで既に作成されているため、ここでは追加しない
  }

  Future<Memo> create(Memo memo) async {
    final db = await instance.database;
    final id = await db.insert('memos', memo.toMap());
    return memo..id = id;
  }

  Future<MapInfo> createMap(MapInfo mapInfo) async {
    final db = await instance.database;
    final id = await db.insert('maps', mapInfo.toMap());
    return MapInfo(id: id, title: mapInfo.title, imagePath: mapInfo.imagePath);
  }

  Future<Memo> readMemo(int id) async {
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
        'pinNumber'
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

  Future<List<Memo>> readAllMemos() async {
    final db = await instance.database;
    const orderBy = 'id ASC';
    final result = await db.query('memos', orderBy: orderBy);

    return result.map((json) => Memo.fromMap(json)).toList();
  }

  // 地図の名前を含むメモ一覧を取得
  Future<List<Memo>> readAllMemosWithMapTitle() async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT m.*, mp.title as mapTitle 
      FROM memos m 
      LEFT JOIN maps mp ON m.mapId = mp.id 
      ORDER BY m.id ASC
    ''');

    return result.map((json) => Memo.fromMap(json)).toList();
  }

  // タイトルでメモを検索
  Future<List<Memo>> searchMemosByTitle(String searchQuery) async {
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

  // 地図の名前でメモを検索
  Future<List<Memo>> searchMemosByMapTitle(String searchQuery) async {
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

  // タイトルまたは地図の名前でメモを検索
  Future<List<Memo>> searchMemos(String searchQuery) async {
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

  // 特定の地図IDのメモのみを取得
  Future<List<Memo>> readMemosByMapId(int? mapId) async {
    final db = await instance.database;
    final result = await db.query(
      'memos',
      where: mapId != null ? 'mapId = ?' : 'mapId IS NULL',
      whereArgs: mapId != null ? [mapId] : null,
      orderBy: 'id ASC',
    );

    return result.map((json) => Memo.fromMap(json)).toList();
  }

  // 特定の地図画像パスのメモを取得（既存の地図ファイル用）
  Future<List<Memo>> readMemosByMapPath(String? mapImagePath) async {
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

  // 地図画像パスから地図IDを取得（なければ作成）
  Future<int?> getOrCreateMapId(String? mapImagePath, String? mapTitle) async {
    if (mapImagePath == null) return null;

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

  Future<List<MapInfo>> readAllMaps() async {
    final db = await instance.database;
    const orderBy = 'id ASC';
    final result = await db.query('maps', orderBy: orderBy);

    return result.map((json) => MapInfo.fromMap(json)).toList();
  }

  Future<int> update(Memo memo) async {
    final db = await instance.database;

    return db.update(
      'memos',
      memo.toMap(),
      where: 'id = ?',
      whereArgs: [memo.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await instance.database;

    return await db.delete(
      'memos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteMap(int id) async {
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

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
