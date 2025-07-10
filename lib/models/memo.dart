import 'package:hive/hive.dart';
import 'dart:convert'; // JSON操作用に追加

part 'memo.g.dart';

@HiveType(typeId: 1)
class Memo {
  @HiveField(0)
  int? id;
  @HiveField(1)
  String title;
  @HiveField(2)
  String content;
  @HiveField(3)
  double? latitude;
  @HiveField(4)
  double? longitude;
  @HiveField(5)
  DateTime? discoveryTime;
  @HiveField(6)
  String? discoverer;
  @HiveField(7)
  String? specimenNumber;
  @HiveField(8)
  String? category;
  @HiveField(9)
  String? notes;
  @HiveField(10)
  int? pinNumber; // ピン番号を追加
  @HiveField(11)
  int? mapId; // 地図ID
  String? mapTitle; // 地図の名前（Hiveでは保存しない、実行時に取得）
  @HiveField(12)
  String? audioPath; // 音声ファイルのパス
  @HiveField(13)
  List<String>? imagePaths; // 画像パス配列を追加

  Memo({
    this.id,
    required this.title,
    required this.content,
    this.latitude,
    this.longitude,
    this.discoveryTime,
    this.discoverer,
    this.specimenNumber,
    this.category,
    this.notes,
    this.pinNumber, // ピン番号を追加
    this.mapId, // 地図ID
    this.mapTitle, // 地図の名前
    this.audioPath, // 音声ファイルのパス
    this.imagePaths, // 画像パス配列を追加
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'latitude': latitude,
      'longitude': longitude,
      'discoveryTime': discoveryTime?.millisecondsSinceEpoch,
      'discoverer': discoverer,
      'specimenNumber': specimenNumber,
      'category': category,
      'notes': notes,
      'pinNumber': pinNumber, // ピン番号を追加
      'mapId': mapId, // 地図ID
      'audioPath': audioPath, // 音声ファイルのパス
      'imagePaths':
          imagePaths != null ? jsonEncode(imagePaths) : null, // JSON文字列として保存
    };
  }

  static Memo fromMap(Map<String, dynamic> map) {
    return Memo(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      discoveryTime: map['discoveryTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['discoveryTime'])
          : null,
      discoverer: map['discoverer'],
      specimenNumber: map['specimenNumber'],
      category: map['category'],
      notes: map['notes'],
      pinNumber: map['pinNumber'], // ピン番号を追加
      mapId: map['mapId'], // 地図ID
      mapTitle: map['mapTitle'], // 地図の名前（JOINクエリで取得）
      audioPath: map['audioPath'], // 音声ファイルのパス
      imagePaths: map['imagePaths'] != null
          ? List<String>.from(jsonDecode(map['imagePaths']))
          : null, // JSON文字列からList<String>に変換
    );
  }
}
