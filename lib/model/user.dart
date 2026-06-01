class AppUser {
  final String? id;
  final String? email;
  final String phone;
  final String displayName;
  final String? imageUrl;
  final bool isOnline;
  final int lastSeen;
  final String? password;

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
      'phone': phone,
      'displayName': displayName,
      'imageUrl': imageUrl,
      'isOnline': isOnline,
      'lastSeen': lastSeen,
      'password': password,
    };
  }

  AppUser copyWith({
    String? id,
    String? displayName,
    String? phone,
    String? email,
    bool? isOnline,
    int? lastSeen,
    String? imageUrl,
    String? password,
  }) {
    return AppUser(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      imageUrl: imageUrl ?? this.imageUrl,
      password: password ?? this.password,
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
      lastSeen: map['lastSeen'] is int ? map['lastSeen'] : 0,
      password: map['password'] ?? '',
    );
  }

  String get name => displayName.isNotEmpty ? displayName : (email?.split('@')[0] ?? 'User');

  /// دالة مساعدة لعرض آخر ظهور بشكل مقروء
  String get lastSeenText {
    if (lastSeen == 0) return 'غير معروف';

    final now = DateTime.now();
    final lastSeenDate = DateTime.fromMillisecondsSinceEpoch(lastSeen);
    final diff = now.difference(lastSeenDate);

    if (diff.inSeconds < 60) {
      return 'الآن';
    } else if (diff.inMinutes < 60) {
      return 'منذ ${diff.inMinutes} دقيقة';
    } else if (diff.inHours < 24 && now.day == lastSeenDate.day) {
      return 'آخر ظهور اليوم ${_formatTime(lastSeenDate)}';
    } else if (diff.inDays == 1) {
      return 'أمس ${_formatTime(lastSeenDate)}';
    } else if (diff.inDays < 7) {
      return 'منذ ${diff.inDays} أيام';
    } else {
      return '${lastSeenDate.day}/${lastSeenDate.month}/${lastSeenDate.year}';
    }
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'م' : 'ص';
    return '$hour:$minute $period';
  }
}