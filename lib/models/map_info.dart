import 'package:hive/hive.dart';

part 'map_info.g.dart';

@HiveType(typeId: 0)
class MapInfo {
  @HiveField(0)
  final int? id;
  @HiveField(1)
  final String title;
  @HiveField(2)
  final String? imagePath;
  @HiveField(3)
  final String? syncId;
  @HiveField(4)
  final DateTime? updatedAt;

  const MapInfo({
    this.id,
    required this.title,
    this.imagePath,
    this.syncId,
    this.updatedAt,
  });

  MapInfo copyWith({
    int? id,
    String? title,
    String? imagePath,
    String? syncId,
    DateTime? updatedAt,
  }) {
    return MapInfo(
      id: id ?? this.id,
      title: title ?? this.title,
      imagePath: imagePath ?? this.imagePath,
      syncId: syncId ?? this.syncId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'imagePath': imagePath,
      'syncId': syncId,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }

  factory MapInfo.fromMap(Map<String, dynamic> map) {
    return MapInfo(
      id: map['id'],
      title: map['title'],
      imagePath: map['imagePath'],
      syncId: map['syncId']?.toString(),
      updatedAt: _dateTimeFromValue(map['updatedAt']),
    );
  }

  static DateTime? _dateTimeFromValue(Object? value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
