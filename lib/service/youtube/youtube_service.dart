import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../model/youtube/constants.dart';
import '../../model/youtube/video_model.dart';


class YoutubeService {
  final http.Client _client;

  YoutubeService({http.Client? client}) : _client = client ?? http.Client();

  // ----------------------------------------
  // البحث عن فيديوهات
  // ----------------------------------------
  Future<List<VideoModel>> searchVideos(String query) async {
    try {
      final url = Uri.parse(
        '${AppConstants.baseUrl}/search'
            '?part=snippet'
            '&q=${Uri.encodeComponent(query)}'
            '&type=video'
            '&maxResults=${AppConstants.maxResults}'
            '&key=${AppConstants.apiKey}',
      );

      final response = await _client.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List? ?? [];
        return items
            .map((item) => VideoModel.fromSearchJson(item))
            .where((v) => v.videoId.isNotEmpty)
            .toList();
      } else {
        final error = json.decode(response.body);
        throw Exception(
          error['error']?['message'] ?? 'فشل البحث: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('خطأ في البحث: $e');
    }
  }

  // ----------------------------------------
  // جلب فيديوهات الترند
  // ----------------------------------------
  Future<List<VideoModel>> getTrendingVideos() async {
    try {
      final url = Uri.parse(
        '${AppConstants.baseUrl}/videos'
            '?part=snippet,statistics,contentDetails'
            '&chart=mostPopular'
            '&regionCode=${AppConstants.regionCode}'
            '&maxResults=${AppConstants.maxResults}'
            '&key=${AppConstants.apiKey}',
      );

      final response = await _client.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List? ?? [];
        return items
            .map((item) => VideoModel.fromTrendingJson(item))
            .where((v) => v.videoId.isNotEmpty)
            .toList();
      } else {
        final error = json.decode(response.body);
        throw Exception(
          error['error']?['message'] ?? 'فشل التحميل: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('خطأ في تحميل الترند: $e');
    }
  }

  // ----------------------------------------
  // جلب تفاصيل فيديو معين
  // ----------------------------------------
  Future<VideoModel?> getVideoDetails(String videoId) async {
    try {
      final url = Uri.parse(
        '${AppConstants.baseUrl}/videos'
            '?part=snippet,statistics,contentDetails'
            '&id=$videoId'
            '&key=${AppConstants.apiKey}',
      );

      final response = await _client.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List? ?? [];
        if (items.isEmpty) return null;
        return VideoModel.fromTrendingJson(items.first);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _client.close();
  }
}