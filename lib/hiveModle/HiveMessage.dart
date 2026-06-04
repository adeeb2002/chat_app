

import 'package:hive/hive.dart';

import '../model/Message.dart';

part 'HiveMessage.g.dart';

@HiveType(typeId: 1) // ✅ استخدم typeId مختلف عن HiveChat (الذي كان typeId 0)
class HiveMessage {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String senderUser;

  @HiveField(2)
  final String resevUser;

  @HiveField(3)
  final String body;

  @HiveField(4)
  final String chatId;

  @HiveField(5)
  final int timestamp;

  @HiveField(6)
  final bool isRead;

  @HiveField(7)
  final bool isDeleted;

  @HiveField(8)
  final bool isSynced;

  @HiveField(9)
  final String? editedAt;

  @HiveField(10)
  final int? deliveredAt;

  @HiveField(11)
  final int? seenAt;

  HiveMessage({
    required this.id,
    required this.senderUser,
    required this.resevUser,
    required this.body,
    required this.chatId,
    required this.timestamp,
    this.isRead = false,
    this.isDeleted = false,
    this.isSynced = true,
    this.editedAt,
    this.deliveredAt,
    this.seenAt,
  });

  // ✅ تحويل من Message العادي إلى HiveMessage
  factory HiveMessage.fromMessage(Message message) {
    return HiveMessage(
      id: message.id,
      senderUser: message.senderUser,
      resevUser: message.resevUser,
      body: message.body,
      chatId: message.chatId,
      timestamp: message.timestamp,
      isRead: message.isRead,
      isDeleted: message.isDeleted,
      isSynced: message.isSynced,
      editedAt: message.editedAt,

    );
  }

  // ✅ تحويل إلى Message العادي
  Message toMessage() {
    return Message(
      id: id,
      senderUser: senderUser,
      resevUser: resevUser,
      body: body,
      chatId: chatId,
      timestamp: timestamp,
      isRead: isRead,
      isDeleted: isDeleted,
      isSynced: isSynced,
      editedAt: editedAt,

    );
  }

  // ✅ نسخة معدلة (للتحديث)
  HiveMessage copyWith({
    String? id,
    String? senderUser,
    String? resevUser,
    String? body,
    String? chatId,
    int? timestamp,
    bool? isRead,
    bool? isDeleted,
    bool? isSynced,
    String? editedAt,
    int? deliveredAt,
    int? seenAt,
  }) {
    return HiveMessage(
      id: id ?? this.id,
      senderUser: senderUser ?? this.senderUser,
      resevUser: resevUser ?? this.resevUser,
      body: body ?? this.body,
      chatId: chatId ?? this.chatId,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      isDeleted: isDeleted ?? this.isDeleted,
      isSynced: isSynced ?? this.isSynced,
      editedAt: editedAt ?? this.editedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      seenAt: seenAt ?? this.seenAt,
    );
  }

  // ✅ تحويل إلى Map (للتخزين المؤقت أو التصحيح)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderUser': senderUser,
      'resevUser': resevUser,
      'body': body,
      'chatId': chatId,
      'timestamp': timestamp,
      'isRead': isRead,
      'isDeleted': isDeleted,
      'isSynced': isSynced,
      'editedAt': editedAt,
      'deliveredAt': deliveredAt,
      'seenAt': seenAt,
    };
  }

  // ✅ إنشاء من Map
  factory HiveMessage.fromMap(Map<String, dynamic> map) {
    return HiveMessage(
      id: map['id'] ?? '',
      senderUser: map['senderUser'] ?? '',
      resevUser: map['resevUser'] ?? '',
      body: map['body'] ?? '',
      chatId: map['chatId'] ?? '',
      timestamp: map['timestamp'] ?? 0,
      isRead: map['isRead'] ?? false,
      isDeleted: map['isDeleted'] ?? false,
      isSynced: map['isSynced'] ?? true,
      editedAt: map['editedAt'],
      deliveredAt: map['deliveredAt'],
      seenAt: map['seenAt'],
    );
  }

  @override
  String toString() {
    return 'HiveMessage(id: $id, chatId: $chatId, body: $body, timestamp: $timestamp, isSynced: $isSynced)';
  }
}