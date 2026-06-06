class InboxThread {
  final String threadId;
  final String threadTitle;
  final List<User> users;
  final LastMessage? lastMessage;
  final int lastActivityAt;
  final bool hasUnread;

  InboxThread({
    required this.threadId,
    required this.threadTitle,
    required this.users,
    this.lastMessage,
    required this.lastActivityAt,
    this.hasUnread = false,
  });

  factory InboxThread.fromJson(Map<String, dynamic> json) {
    return InboxThread(
      threadId: json['thread_id']?.toString() ?? '',
      threadTitle: json['thread_title']?.toString() ?? '',
      users: (json['users'] as List?)
          ?.map((u) => User.fromJson(u as Map<String, dynamic>))
          .toList() ??
          [],
      lastMessage: json['last_permanent_item'] != null
          ? LastMessage.fromJson(
          json['last_permanent_item'] as Map<String, dynamic>)
          : null,
      lastActivityAt:
      int.tryParse(json['last_activity_at']?.toString() ?? '0') ?? 0,
      hasUnread: json['read_state'] == 0,
    );
  }
}

class User {
  final String userId;
  final String username;
  final String fullName;
  final String? profilePicUrl;
  final bool isVerified;

  User({
    required this.userId,
    required this.username,
    required this.fullName,
    this.profilePicUrl,
    this.isVerified = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['pk']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      profilePicUrl: json['profile_pic_url']?.toString(),
      isVerified: json['is_verified'] == true,
    );
  }
}

class LastMessage {
  final String itemId;
  final String itemType;
  final String? text;
  final int timestamp;
  final String userId;

  LastMessage({
    required this.itemId,
    required this.itemType,
    this.text,
    required this.timestamp,
    required this.userId,
  });

  factory LastMessage.fromJson(Map<String, dynamic> json) {
    return LastMessage(
      itemId: json['item_id']?.toString() ?? '',
      itemType: json['item_type']?.toString() ?? '',
      text: json['text']?.toString(),
      timestamp: int.tryParse(json['timestamp']?.toString() ?? '0') ?? 0,
      userId: json['user_id']?.toString() ?? '',
    );
  }
}

class Message {
  final String itemId;
  final String itemType;
  final String? text;
  final int timestamp;
  final String userId;

  Message({
    required this.itemId,
    required this.itemType,
    this.text,
    required this.timestamp,
    required this.userId,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      itemId: json['item_id']?.toString() ?? '',
      itemType: json['item_type']?.toString() ?? '',
      text: json['text']?.toString(),
      timestamp: int.tryParse(json['timestamp']?.toString() ?? '0') ?? 0,
      userId: json['user_id']?.toString() ?? '',
    );
  }

  String getDisplayText() {
    switch (itemType) {
      case 'text':
        return text ?? '';
      case 'media':
      case 'reel_share':
        return '📷 صورة';
      case 'video_call_event':
        return '📞 مكالمة فيديو';
      case 'voice_media':
        return '🎤 رسالة صوتية';
      case 'link':
        return '🔗 رابط';
      case 'animated_media':
        return '😄 GIF';
      case 'media_share':
        return '📱 منشور';
      case 'story_share':
        return '📖 قصة';
      case 'action_log':
        return 'إجراء';
      default:
        return 'رسالة';
    }
  }
}