class InstagramUser {
  final String id;
  final String username;
  final String? name;
  final String? biography;
  final int followersCount;
  final int followsCount;
  final int mediaCount;
  final String? profilePictureUrl;
  final String? website;
  final String? accessToken;

  const InstagramUser({
    required this.id,
    required this.username,
    this.name,
    this.biography,
    this.followersCount = 0,
    this.followsCount = 0,
    this.mediaCount = 0,
    this.profilePictureUrl,
    this.website,
    this.accessToken,
  });

  factory InstagramUser.fromJson(Map<String, dynamic> json) {
    return InstagramUser(
      id: json['id']?.toString() ?? '',
      username: json['username'] ?? '',
      name: json['name'],
      biography: json['biography'],
      followersCount: json['followers_count'] ?? 0,
      followsCount: json['follows_count'] ?? 0,
      mediaCount: json['media_count'] ?? 0,
      profilePictureUrl: json['profile_picture_url'],
      website: json['website'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'name': name,
    'biography': biography,
    'followers_count': followersCount,
    'follows_count': followsCount,
    'media_count': mediaCount,
    'profile_picture_url': profilePictureUrl,
    'website': website,
  };

  InstagramUser copyWith({String? accessToken}) {
    return InstagramUser(
      id: id,
      username: username,
      name: name,
      biography: biography,
      followersCount: followersCount,
      followsCount: followsCount,
      mediaCount: mediaCount,
      profilePictureUrl: profilePictureUrl,
      website: website,
      accessToken: accessToken ?? this.accessToken,
    );
  }

  // Format numbers
  String get formattedFollowers => _formatCount(followersCount);
  String get formattedFollowing => _formatCount(followsCount);
  String get formattedPosts => _formatCount(mediaCount);

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}