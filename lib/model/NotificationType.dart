// lib/services/notifications/notification_types.dart

enum NotificationType {
  message,           // رسالة عادية
  messageReply,      // رد على رسالة
  friendRequest,     // طلب صداقة
  friendAccepted,    // قبول صداقة
  groupInvite,       // دعوة لمجموعة
  mention,           // منشن في محادثة
}

class NotificationPayload {
  final NotificationType type;
  final String title;
  final String body;
  final String? chatId;
  final String? senderId;
  final String? messageId;
  final String? groupId;
  final Map<String, dynamic>? extraData;

  NotificationPayload({
    required this.type,
    required this.title,
    required this.body,
    this.chatId,
    this.senderId,
    this.messageId,
    this.groupId,
    this.extraData,
  });

  // تحويل إلى Map لإرسالها عبر OneSignal
  Map<String, dynamic> toDataMap() {
    return {
      'type': type.name,
      'title': title,
      'body': body,
      if (chatId != null) 'chatId': chatId,
      if (senderId != null) 'senderId': senderId,
      if (messageId != null) 'messageId': messageId,
      if (groupId != null) 'groupId': groupId,
      // ignore: use_null_aware_elements
      if (extraData case final data?) ...data,
    };
  }

  // استخراج من OneSignal notification
  factory NotificationPayload.fromOSNotification(Map<String, dynamic> data) {
    return NotificationPayload(
      type: NotificationType.values.firstWhere(
            (e) => e.name == data['type'],
        orElse: () => NotificationType.message,
      ),
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      chatId: data['chatId'],
      senderId: data['senderId'],
      messageId: data['messageId'],
      groupId: data['groupId'],
      extraData: data,
    );
  }
}