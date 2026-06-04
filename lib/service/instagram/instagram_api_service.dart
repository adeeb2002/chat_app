

import 'package:dio/dio.dart';

import '../../model/instagram/instagram_constants.dart';
import '../../model/instagram/instagram_media_model.dart';
import '../../model/instagram/instagram_user_model.dart';

class InstagramApiService {
  final Dio _dio;

  InstagramApiService({required Dio dio}) : _dio = dio;

  // ========================
  // جلب بيانات المستخدم
  // ========================
  Future<InstagramUser> getCurrentUser(String accessToken) async {
    final response = await _dio.get(
      '${InstagramConstants.graphBaseUrl}/me',
      queryParameters: {
        'fields': InstagramConstants.userFields,
        'access_token': accessToken,
      },
    );

    return InstagramUser.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  // ========================
  // جلب المنشورات
  // ========================
  Future<InstagramMediaResponse> getUserMedia(
      String accessToken, {
        String? cursor,
        int limit = 12,
      }) async {
    final params = {
      'fields': InstagramConstants.mediaFields,
      'access_token': accessToken,
      'limit': limit.toString(),
    };

    if (cursor != null) {
      params['after'] = cursor;
    }

    final response = await _dio.get(
      '${InstagramConstants.graphBaseUrl}/me/media',
      queryParameters: params,
    );

    return InstagramMediaResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  // ========================
  // جلب إحصائيات منشور
  // ========================
  Future<Map<String, dynamic>> getMediaInsights(
      String mediaId,
      String accessToken,
      ) async {
    final response = await _dio.get(
      '${InstagramConstants.graphBaseUrl}/$mediaId/insights',
      queryParameters: {
        'metric': 'impressions,reach,engagement',
        'access_token': accessToken,
      },
    );
    return response.data as Map<String, dynamic>;
  }
}