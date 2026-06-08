class VideoModel {
  final String videoId;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String channelTitle;
  final String publishedAt;
  final String viewCount;
  final String likeCount;
  final String duration;

  const VideoModel({
    required this.videoId,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.channelTitle,
    required this.publishedAt,
    this.viewCount = '0',
    this.likeCount = '0',
    this.duration = '',
  });

  factory VideoModel.fromSearchJson(Map<String, dynamic> json) {
    final snippet = json['snippet'] ?? {};
    final thumbnails = snippet['thumbnails'] ?? {};
    final high = thumbnails['high'] ??
        thumbnails['medium'] ??
        thumbnails['default'] ??
        {};

    return VideoModel(
      videoId: json['id']?['videoId'] ?? '',
      title: snippet['title'] ?? 'No Title',
      description: snippet['description'] ?? '',
      thumbnailUrl: high['url'] ?? '',
      channelTitle: snippet['channelTitle'] ?? '',
      publishedAt: snippet['publishedAt'] ?? '',
    );
  }

  factory VideoModel.fromTrendingJson(Map<String, dynamic> json) {
    final snippet = json['snippet'] ?? {};
    final statistics = json['statistics'] ?? {};
    final contentDetails = json['contentDetails'] ?? {};
    final thumbnails = snippet['thumbnails'] ?? {};
    final high = thumbnails['high'] ??
        thumbnails['medium'] ??
        thumbnails['default'] ??
        {};

    return VideoModel(
      videoId: json['id'] ?? '',
      title: snippet['title'] ?? 'No Title',
      description: snippet['description'] ?? '',
      thumbnailUrl: high['url'] ?? '',
      channelTitle: snippet['channelTitle'] ?? '',
      publishedAt: snippet['publishedAt'] ?? '',
      viewCount: statistics['viewCount'] ?? '0',
      likeCount: statistics['likeCount'] ?? '0',
      duration: contentDetails['duration'] ?? '',
    );
  }

  String get formattedViewCount {
    final num = int.tryParse(viewCount) ?? 0;
    if (num >= 1000000000) {
      return '${(num / 1000000000).toStringAsFixed(1)}B مشاهدة';
    } else if (num >= 1000000) {
      return '${(num / 1000000).toStringAsFixed(1)}M مشاهدة';
    } else if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(1)}K مشاهدة';
    }
    return '$num مشاهدة';
  }

  String get formattedLikeCount {
    final num = int.tryParse(likeCount) ?? 0;
    if (num >= 1000000) {
      return '${(num / 1000000).toStringAsFixed(1)}M';
    } else if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(1)}K';
    }
    return '$num';
  }

  String get formattedDuration {
    if (duration.isEmpty) return '';
    final regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
    final match = regex.firstMatch(duration);
    if (match == null) return '';

    final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
    final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  DateTime? get publishedDate {
    try {
      return DateTime.parse(publishedAt);
    } catch (_) {
      return null;
    }
  }
}