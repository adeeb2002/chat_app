
class StatusReply {
  final String id;
  final String statusId;
  final String senderId;
  final String receiverId;
  final String replyText;
  final DateTime timestamp;
  final bool isRead;
  
  StatusReply({
    required this.id,
    required this.statusId,
    required this.senderId,
    required this.receiverId,
    required this.replyText,
    required this.timestamp,
    this.isRead = false,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'statusId': statusId,
      'senderId': senderId,
      'receiverId': receiverId,
      'replyText': replyText,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isRead': isRead,
    };
  }
  
  factory StatusReply.fromMap(String id, Map<String, dynamic> map) {
    return StatusReply(
      id: id,
      statusId: map['statusId'] ?? '',
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      replyText: map['replyText'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      isRead: map['isRead'] ?? false,
    );
  }
}