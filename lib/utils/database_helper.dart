import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/memo.dart';

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

    return await openDatabase(path, version: 2, onCreate: _createDB, onUpgrade: _upgradeDB);
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
  notes $textNullType
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
  }

  Future<Memo> create(Memo memo) async {
    final db = await instance.database;
    final id = await db.insert('memos', memo.toMap());
    return memo..id = id;
  }

  Future<Memo> readMemo(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'memos',
      columns: ['id', 'title', 'content', 'latitude', 'longitude', 'discoveryTime', 'discoverer', 'specimenNumber', 'category', 'notes'],
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

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
