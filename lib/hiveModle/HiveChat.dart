import 'package:hive/hive.dart';

part 'HiveChat.g.dart';


@HiveType(typeId: 0)
class HiveChat {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final List<String> participants;

  @HiveField(2)
  final String lastMessage;

  @HiveField(3)
  final int lastMessageTime;

  @HiveField(4)
  final String lastMessageSender;

  @HiveField(5)
  final int createdAt;

  @HiveField(6)
  final int updatedAt;

  @HiveField(7)
  final Map<String, dynamic>? deletedFor;

  @HiveField(8)
  final Map<String, dynamic>? clearedFor;

  @HiveField(9)
  final bool isBlocked;

  @HiveField(10)
  final String? blockedBy;
  @HiveField(11)
  final dynamic unreadCount;


  HiveChat({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastMessageSender,
    required this.createdAt,
    required this.updatedAt,
    this.deletedFor,
    this.clearedFor,
    this.isBlocked = false,
    this.blockedBy,
    this.unreadCount,
  });
}