class Message {
  final String id;
  final String senderUser;
  final String resevUser;
  final String body;
  final String chatId;
  final int timestamp;
  final bool isRead;
  final MessageType type;
  final bool isDeleted;
  final String? editedAt;
  final String? originalBody;
  final bool isSynced;

  Message({
    required this.id,
    required this.senderUser,
    required this.resevUser,
    required this.body,
    required this.chatId,
    required this.timestamp,
    this.isRead = false,
    this.type = MessageType.text,
    this.isDeleted = false,
    this.editedAt,
    this.originalBody,
    this.isSynced = true,
  });

  // مصنع لإنشاء رسالة جديدة (نستخدمه عند الإرسال أول مرة)
  factory Message.create({
    required String senderUser,
    required String resevUser,
    required String body,
    required String chatId,
    MessageType type = MessageType.text,
    required bool isSynced
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return Message(
        id: '', // سيتم استبداله بـ key من Firebase في الـ Service
        senderUser: senderUser,
        resevUser: resevUser,
        body: body,
        chatId: chatId,
        timestamp: now,
        isRead: false,
        type: type,
        isDeleted: false,
        isSynced: isSynced
    );
  }

  // ميثود النسخ المعدلة لتشمل كافة الحقول الجديدة
  Message copyWith({
    String? id,
    String? chatId,
    String? senderUser,
    String? resevUser,
    String? body,
    int? timestamp,
    bool? isRead,
    MessageType? type,
    bool? isDeleted,
    String? editedAt,
    String? originalBody,
    bool? isSynced
  }) {
    return Message(
        id: id ?? this.id,
        chatId: chatId ?? this.chatId,
        senderUser: senderUser ?? this.senderUser,
        resevUser: resevUser ?? this.resevUser,
        body: body ?? this.body,
        timestamp: timestamp ?? this.timestamp,
        isRead: isRead ?? this.isRead,
        type: type ?? this.type,
        isDeleted: isDeleted ?? this.isDeleted,
        editedAt: editedAt ?? this.editedAt,
        originalBody: originalBody ?? this.originalBody,
        isSynced: isSynced ?? this.isSynced
    );
  }

  // تحويل إلى Map (للاستخدام المحلي)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderUser': senderUser,
      'resevUser': resevUser,
      'body': isDeleted ? '🚫 تم حذف هذه الرسالة' : body,
      'chatId': chatId,
      'timestamp': timestamp,
      'isRead': isRead,
      'type': type.index,
      'isDeleted': isDeleted,
      'editedAt': editedAt,
      'originalBody': originalBody,
      'isSynced': isSynced,
    };
  }

  // تحويل إلى JSON (للحفظ في SharedPreferences والإرسال إلى Firebase)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderUser': senderUser,
      'resevUser': resevUser,
      'body': body, // نحفظ الـ body الأصلي بدون تعديل
      'chatId': chatId,
      'timestamp': timestamp,
      'isRead': isRead,
      'type': type.index,
      'isDeleted': isDeleted,
      'editedAt': editedAt,
      'originalBody': originalBody,
      'isSynced': isSynced,
    };
  }

  // استخراج من Map
  factory Message.fromMap(Map<dynamic, dynamic> map) {
    return Message(
      id: map['id']?.toString() ?? '',
      senderUser: map['senderUser']?.toString() ?? '',
      resevUser: map['resevUser']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      chatId: map['chatId']?.toString() ?? '',
      timestamp: map['timestamp'] is int
          ? map['timestamp']
          : int.tryParse(map['timestamp']?.toString() ?? '0') ?? 0,
      isRead: map['isRead'] == true,
      type: map['type'] != null && map['type'] < MessageType.values.length
          ? MessageType.values[map['type']]
          : MessageType.text,
      isDeleted: map['isDeleted'] == true,
      editedAt: map['editedAt']?.toString(),
      originalBody: map['originalBody']?.toString(),
      isSynced: map['isSynced'] ?? true,
    );
  }

  // استخراج من JSON
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id']?.toString() ?? '',
      senderUser: json['senderUser']?.toString() ?? '',
      resevUser: json['resevUser']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      chatId: json['chatId']?.toString() ?? '',
      timestamp: json['timestamp'] is int
          ? json['timestamp']
          : int.tryParse(json['timestamp']?.toString() ?? '0') ?? 0,
      isRead: json['isRead'] == true,
      type: json['type'] != null && json['type'] is int && json['type'] < MessageType.values.length
          ? MessageType.values[json['type']]
          : MessageType.text,
      isDeleted: json['isDeleted'] == true,
      editedAt: json['editedAt']?.toString(),
      originalBody: json['originalBody']?.toString(),
      isSynced: json['isSynced'] ?? true,
    );
  }

  // التحقق من صحة البيانات
  bool get isValid => senderUser.isNotEmpty && resevUser.isNotEmpty && body.isNotEmpty && chatId.isNotEmpty;

  // دوال مساعدة للتحقق من هوية المرسل
  bool isFromMe(String myEmail) => senderUser == myEmail;

  @override
  String toString() {
    return 'Message(id: $id, sender: $senderUser, receiver: $resevUser, body: $body, chatId: $chatId, timestamp: $timestamp, isRead: $isRead, type: $type, isDeleted: $isDeleted, isSynced: $isSynced)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

enum MessageType {
  text,
  image,
  audio,
  video
}