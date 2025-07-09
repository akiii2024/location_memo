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

  MapInfo({this.id, required this.title, this.imagePath});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'imagePath': imagePath,
    };
  }

  factory MapInfo.fromMap(Map<String, dynamic> map) {
    return MapInfo(
      id: map['id'],
      title: map['title'],
      imagePath: map['imagePath'],
    );
  }
}
