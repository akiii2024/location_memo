// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memo.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MemoAdapter extends TypeAdapter<Memo> {
  @override
  final int typeId = 1;

  @override
  Memo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Memo(
      id: fields[0] as int?,
      title: fields[1] as String,
      content: fields[2] as String,
      latitude: fields[3] as double?,
      longitude: fields[4] as double?,
      discoveryTime: fields[5] as DateTime?,
      discoverer: fields[6] as String?,
      specimenNumber: fields[7] as String?,
      category: fields[8] as String?,
      notes: fields[9] as String?,
      pinNumber: fields[10] as int?,
      mapId: fields[11] as int?,
      audioPath: fields[12] as String?,
      imagePaths: (fields[13] as List?)?.cast<String>(),
      mushroomCapShape: fields[14] as String?,
      mushroomCapColor: fields[15] as String?,
      mushroomCapSurface: fields[16] as String?,
      mushroomCapSize: fields[17] as String?,
      mushroomCapUnderStructure: fields[18] as String?,
      mushroomGillFeature: fields[19] as String?,
      mushroomStemPresence: fields[20] as String?,
      mushroomStemShape: fields[21] as String?,
      mushroomStemColor: fields[22] as String?,
      mushroomStemSurface: fields[23] as String?,
      mushroomRingPresence: fields[24] as String?,
      mushroomVolvaPresence: fields[25] as String?,
      mushroomHabitat: fields[26] as String?,
      mushroomGrowthPattern: fields[27] as String?,
      layer: fields[28] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, Memo obj) {
    writer
      ..writeByte(29)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.latitude)
      ..writeByte(4)
      ..write(obj.longitude)
      ..writeByte(5)
      ..write(obj.discoveryTime)
      ..writeByte(6)
      ..write(obj.discoverer)
      ..writeByte(7)
      ..write(obj.specimenNumber)
      ..writeByte(8)
      ..write(obj.category)
      ..writeByte(9)
      ..write(obj.notes)
      ..writeByte(10)
      ..write(obj.pinNumber)
      ..writeByte(11)
      ..write(obj.mapId)
      ..writeByte(12)
      ..write(obj.audioPath)
      ..writeByte(13)
      ..write(obj.imagePaths)
      ..writeByte(14)
      ..write(obj.mushroomCapShape)
      ..writeByte(15)
      ..write(obj.mushroomCapColor)
      ..writeByte(16)
      ..write(obj.mushroomCapSurface)
      ..writeByte(17)
      ..write(obj.mushroomCapSize)
      ..writeByte(18)
      ..write(obj.mushroomCapUnderStructure)
      ..writeByte(19)
      ..write(obj.mushroomGillFeature)
      ..writeByte(20)
      ..write(obj.mushroomStemPresence)
      ..writeByte(21)
      ..write(obj.mushroomStemShape)
      ..writeByte(22)
      ..write(obj.mushroomStemColor)
      ..writeByte(23)
      ..write(obj.mushroomStemSurface)
      ..writeByte(24)
      ..write(obj.mushroomRingPresence)
      ..writeByte(25)
      ..write(obj.mushroomVolvaPresence)
      ..writeByte(26)
      ..write(obj.mushroomHabitat)
      ..writeByte(27)
      ..write(obj.mushroomGrowthPattern)
      ..writeByte(28)
      ..write(obj.layer);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
