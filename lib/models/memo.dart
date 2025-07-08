class Memo {
  int? id;
  String title;
  String content;
  double? latitude;
  double? longitude;
  DateTime? discoveryTime;
  String? discoverer;
  String? specimenNumber;
  String? category;
  String? notes;
  int? pinNumber; // ピン番号を追加
  int? mapId; // 地図ID
  String? mapTitle; // 地図の名前

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
    );
  }
}
