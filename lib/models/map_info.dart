class MapInfo {
  final int? id;
  final String title;
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
