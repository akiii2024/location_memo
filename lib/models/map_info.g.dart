// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'map_info.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MapInfoAdapter extends TypeAdapter<MapInfo> {
  @override
  final int typeId = 0;

  @override
  MapInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MapInfo(
      id: fields[0] as int?,
      title: fields[1] as String,
      imagePath: fields[2] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MapInfo obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.imagePath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
