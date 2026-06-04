import 'package:hive/hive.dart';

part 'HiveUser.g.dart';


@HiveType(typeId: 2)
class HiveUser {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String phone;

  @HiveField(2)
  final String? email;

  @HiveField(3)
  final String displayName;

  @HiveField(4)
  final String? imageUrl;

  @HiveField(5)
  final bool isOnline;

  @HiveField(6)
  final int lastSeen;

  HiveUser({
    required this.id,
    required this.phone,
    this.email,
    required this.displayName,
    this.imageUrl,
    this.isOnline = false,
    this.lastSeen = 0,
  });
}
