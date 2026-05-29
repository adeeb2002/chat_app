// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'HiveChat.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HiveChatAdapter extends TypeAdapter<HiveChat> {
  @override
  final int typeId = 0;

  @override
  HiveChat read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveChat(
      id: fields[0] as String,
      participants: (fields[1] as List).cast<String>(),
      lastMessage: fields[2] as String,
      lastMessageTime: fields[3] as int,
      lastMessageSender: fields[4] as String,
      createdAt: fields[5] as int,
      updatedAt: fields[6] as int,
      deletedFor: (fields[7] as Map?)?.cast<String, dynamic>(),
      clearedFor: (fields[8] as Map?)?.cast<String, dynamic>(),
      isBlocked: fields[9] as bool,
      blockedBy: fields[10] as String?,
      unreadCount: fields[11],
    );
  }

  @override
  void write(BinaryWriter writer, HiveChat obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.participants)
      ..writeByte(2)
      ..write(obj.lastMessage)
      ..writeByte(3)
      ..write(obj.lastMessageTime)
      ..writeByte(4)
      ..write(obj.lastMessageSender)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.updatedAt)
      ..writeByte(7)
      ..write(obj.deletedFor)
      ..writeByte(8)
      ..write(obj.clearedFor)
      ..writeByte(9)
      ..write(obj.isBlocked)
      ..writeByte(10)
      ..write(obj.blockedBy)
      ..writeByte(11)
      ..write(obj.unreadCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveChatAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
