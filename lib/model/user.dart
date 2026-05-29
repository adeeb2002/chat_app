// model/user.dart
class AppUser {
  final String? id;
  final String? email;
  final String phone;
  final String displayName;
  final String? imageUrl;
  final bool isOnline;
  final int lastSeen;
  final String? password; // فقط للتطوير، لا تخزن كلمة المرور بهذا الشكل في الإنتاج

  AppUser({
    this.id,
    required this.phone,
    this.email,
    required this.displayName,
    this.imageUrl,
    this.isOnline = false,
    this.lastSeen = 0,
    this.password,
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'phone' : phone,
      'displayName': displayName,
      'imageUrl': imageUrl,
      'isOnline': isOnline,
      'lastSeen': lastSeen,
      'password': password
    };
  }


  AppUser copyWith({
    String? id,
    String? displayName,
    String? phone,
    String? email,
    bool? isOnline,
    String? imageUrl
  }) {
    return AppUser(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email:this.email,
      phone: phone ?? this.phone,
      isOnline: isOnline ?? this.isOnline,
      imageUrl: imageUrl ?? this.imageUrl
    );
  }

  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
    return AppUser(
      id: id,
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      displayName: map['displayName'] ?? '',
      imageUrl: map['imageUrl'] ?? 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRGa70BgePn1Rsf41oiG6ac0_TAzpKXj4d9qg&s',
      isOnline: map['isOnline'] ?? false,
      lastSeen: map['lastSeen'] ?? 0,
      password: map['password'] ?? ''
    );
  }

  String get name => displayName.isNotEmpty ? displayName : (email?.split('@')[0] ?? 'User');
}