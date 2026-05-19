// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'HiveMessage.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HiveMessageAdapter extends TypeAdapter<HiveMessage> {
  @override
  final int typeId = 1;

  @override
  HiveMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveMessage(
      id: fields[0] as String,
      senderUser: fields[1] as String,
      resevUser: fields[2] as String,
      body: fields[3] as String,
      chatId: fields[4] as String,
      timestamp: fields[5] as int,
      isRead: fields[6] as bool,
      isDeleted: fields[7] as bool,
      isSynced: fields[8] as bool,
      editedAt: fields[9] as String?,
      deliveredAt: fields[10] as int?,
      seenAt: fields[11] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, HiveMessage obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.senderUser)
      ..writeByte(2)
      ..write(obj.resevUser)
      ..writeByte(3)
      ..write(obj.body)
      ..writeByte(4)
      ..write(obj.chatId)
      ..writeByte(5)
      ..write(obj.timestamp)
      ..writeByte(6)
      ..write(obj.isRead)
      ..writeByte(7)
      ..write(obj.isDeleted)
      ..writeByte(8)
      ..write(obj.isSynced)
      ..writeByte(9)
      ..write(obj.editedAt)
      ..writeByte(10)
      ..write(obj.deliveredAt)
      ..writeByte(11)
      ..write(obj.seenAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveMessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
