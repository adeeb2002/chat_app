// model/user.dart
class AppUser {
  final String? id;
  final String email;
  final String displayName;
  final String? imageUrl;
  final bool isOnline;
  final int lastSeen;
  final String? password; // فقط للتطوير، لا تخزن كلمة المرور بهذا الشكل في الإنتاج

  AppUser({
    this.id,
    required this.email,
    required this.displayName,
    this.imageUrl,
    this.isOnline = false,
    this.lastSeen = 0,
    this.password,
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'imageUrl': imageUrl,
      'isOnline': isOnline,
      'lastSeen': lastSeen,
      'password': password
    };
  }

  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
    return AppUser(
      id: id,
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      imageUrl: map['imageUrl'],
      isOnline: map['isOnline'] ?? false,
      lastSeen: map['lastSeen'] ?? 0,
      password: map['password'] ?? ''
    );
  }

  String get name => displayName.isNotEmpty ? displayName : email.split('@')[0];
}