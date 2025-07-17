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
  @HiveField(28)
  int? layer; // レイヤー番号を追加

  // キノコ詳細情報フィールド
  @HiveField(14)
  String? mushroomCapShape; // 傘の形
  @HiveField(15)
  String? mushroomCapColor; // 傘の色
  @HiveField(16)
  String? mushroomCapSurface; // 傘の表面
  @HiveField(17)
  String? mushroomCapSize; // 傘の大きさ
  @HiveField(18)
  String? mushroomCapUnderStructure; // 傘裏面の構造
  @HiveField(19)
  String? mushroomGillFeature; // ヒダの特徴
  @HiveField(20)
  String? mushroomStemPresence; // 柄の有無
  @HiveField(21)
  String? mushroomStemShape; // 柄の形
  @HiveField(22)
  String? mushroomStemColor; // 柄の色
  @HiveField(23)
  String? mushroomStemSurface; // 柄表面の状態
  @HiveField(24)
  String? mushroomRingPresence; // つばの有無
  @HiveField(25)
  String? mushroomVolvaPresence; // つぼの有無
  @HiveField(26)
  String? mushroomHabitat; // 発生場所
  @HiveField(27)
  String? mushroomGrowthPattern; // 生育状態

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
    // キノコ詳細情報
    this.mushroomCapShape,
    this.mushroomCapColor,
    this.mushroomCapSurface,
    this.mushroomCapSize,
    this.mushroomCapUnderStructure,
    this.mushroomGillFeature,
    this.mushroomStemPresence,
    this.mushroomStemShape,
    this.mushroomStemColor,
    this.mushroomStemSurface,
    this.mushroomRingPresence,
    this.mushroomVolvaPresence,
    this.mushroomHabitat,
    this.mushroomGrowthPattern,
    this.layer, // レイヤー番号
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
      // キノコ詳細情報
      'mushroomCapShape': mushroomCapShape,
      'mushroomCapColor': mushroomCapColor,
      'mushroomCapSurface': mushroomCapSurface,
      'mushroomCapSize': mushroomCapSize,
      'mushroomCapUnderStructure': mushroomCapUnderStructure,
      'mushroomGillFeature': mushroomGillFeature,
      'mushroomStemPresence': mushroomStemPresence,
      'mushroomStemShape': mushroomStemShape,
      'mushroomStemColor': mushroomStemColor,
      'mushroomStemSurface': mushroomStemSurface,
      'mushroomRingPresence': mushroomRingPresence,
      'mushroomVolvaPresence': mushroomVolvaPresence,
      'mushroomHabitat': mushroomHabitat,
      'mushroomGrowthPattern': mushroomGrowthPattern,
      if (layer != null) 'layer': layer, // レイヤー番号を保存（存在する場合）
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
      // キノコ詳細情報
      mushroomCapShape: map['mushroomCapShape'],
      mushroomCapColor: map['mushroomCapColor'],
      mushroomCapSurface: map['mushroomCapSurface'],
      mushroomCapSize: map['mushroomCapSize'],
      mushroomCapUnderStructure: map['mushroomCapUnderStructure'],
      mushroomGillFeature: map['mushroomGillFeature'],
      mushroomStemPresence: map['mushroomStemPresence'],
      mushroomStemShape: map['mushroomStemShape'],
      mushroomStemColor: map['mushroomStemColor'],
      mushroomStemSurface: map['mushroomStemSurface'],
      mushroomRingPresence: map['mushroomRingPresence'],
      mushroomVolvaPresence: map['mushroomVolvaPresence'],
      mushroomHabitat: map['mushroomHabitat'],
      mushroomGrowthPattern: map['mushroomGrowthPattern'],
      layer: map['layer'], // レイヤー番号を読み込み
    );
  }
}
