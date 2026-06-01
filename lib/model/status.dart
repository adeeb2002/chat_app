enum StatusType { text, image }

class Status {
  final String id;
  final String userId;
  final String? text;
  final String? imageUrl;
  final DateTime timestamp;
  final DateTime expiresAt;
  final StatusType type;
  final List<String> views; // List of userIds who viewed this status
  final String userDisplayName; // Denormalized for performance in UI
  final String? userImageUrl;   // Denormalized for performance in UI

  Status({
    required this.id,
    required this.userId,
    this.text,
    this.imageUrl,
    required this.timestamp,
    required this.expiresAt,
    required this.type,
    required this.userDisplayName,
    this.userImageUrl,
    List<String>? views,
  }) : views = views ?? [];

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isTextOnly => type == StatusType.text;
  bool get isImageOnly => type == StatusType.image;

  // Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'text': text,
      'imageUrl': imageUrl,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'expiresAt': expiresAt.millisecondsSinceEpoch,
      'type': type == StatusType.text ? 'text' : 'image',
      'views': views,
      'userDisplayName': userDisplayName,
      'userImageUrl': userImageUrl,
    };
  }

  // Create from JSON (Firestore)
  factory Status.fromJson(Map<String, dynamic> json) {
    return Status(
      id: json['id'] as String,
      userId: json['userId'] as String,
      text: json['text'] as String?,
      imageUrl: json['imageUrl'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(json['expiresAt'] as int),
      type: (json['type'] as String) == 'text'
          ? StatusType.text
          : StatusType.image,
      userDisplayName: json['userDisplayName'] as String,
      userImageUrl: json['userImageUrl'] as String?,
      views: List<String>.from(json['views'] ?? []),
    );
  }

  // Copy with
  Status copyWith({
    String? id,
    String? userId,
    String? text,
    String? imageUrl,
    DateTime? timestamp,
    DateTime? expiresAt,
    StatusType? type,
    List<String>? views,
    String? userDisplayName,
    String? userImageUrl,
  }) {
    return Status(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      timestamp: timestamp ?? this.timestamp,
      expiresAt: expiresAt ?? this.expiresAt,
      type: type ?? this.type,
      views: views ?? this.views,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      userImageUrl: userImageUrl ?? this.userImageUrl,
    );
  }
}