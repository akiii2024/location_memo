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
    );
  }
}
