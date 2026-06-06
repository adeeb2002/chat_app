enum MediaType { image, video, carouselAlbum, unknown }

class InstagramMedia {
  final String id;
  final String? caption;
  final MediaType mediaType;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final String? permalink;
  final DateTime? timestamp;
  final int likeCount;
  final int commentsCount;
  final List<InstagramMedia> children;

  const InstagramMedia({
    required this.id,
    this.caption,
    this.mediaType = MediaType.unknown,
    this.mediaUrl,
    this.thumbnailUrl,
    this.permalink,
    this.timestamp,
    this.likeCount = 0,
    this.commentsCount = 0,
    this.children = const [],
  });

  factory InstagramMedia.fromJson(Map<String, dynamic> json) {
    final childrenData = json['children']?['data'] as List<dynamic>?;
    final children = childrenData
        ?.map((c) => InstagramMedia.fromJson(c as Map<String, dynamic>))
        .toList() ??
        [];

    return InstagramMedia(
      id: json['id']?.toString() ?? '',
      caption: json['caption'],
      mediaType: _parseMediaType(json['media_type']),
      mediaUrl: json['media_url'],
      thumbnailUrl: json['thumbnail_url'],
      permalink: json['permalink'],
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'])
          : null,
      likeCount: json['like_count'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      children: children,
    );
  }

  static MediaType _parseMediaType(String? type) {
    switch (type?.toUpperCase()) {
      case 'IMAGE':
        return MediaType.image;
      case 'VIDEO':
        return MediaType.video;
      case 'CAROUSEL_ALBUM':
        return MediaType.carouselAlbum;
      default:
        return MediaType.unknown;
    }
  }

  String get displayUrl {
    if (mediaType == MediaType.video) {
      return thumbnailUrl ?? mediaUrl ?? '';
    }
    return mediaUrl ?? thumbnailUrl ?? '';
  }

  bool get isVideo => mediaType == MediaType.video;
  bool get isCarousel => mediaType == MediaType.carouselAlbum;
  bool get isImage => mediaType == MediaType.image;
}

class InstagramMediaResponse {
  final List<InstagramMedia> data;
  final String? nextCursor;
  final bool hasMore;

  const InstagramMediaResponse({
    required this.data,
    this.nextCursor,
    this.hasMore = false,
  });

  factory InstagramMediaResponse.fromJson(Map<String, dynamic> json) {
    final dataList = (json['data'] as List<dynamic>? ?? [])
        .map((item) =>
        InstagramMedia.fromJson(item as Map<String, dynamic>))
        .toList();

    final paging = json['paging'] as Map<String, dynamic>?;
    final cursors = paging?['cursors'] as Map<String, dynamic>?;
    final nextCursor = cursors?['after'] as String?;

    return InstagramMediaResponse(
      data: dataList,
      nextCursor: nextCursor,
      hasMore: nextCursor != null,
    );
  }
}