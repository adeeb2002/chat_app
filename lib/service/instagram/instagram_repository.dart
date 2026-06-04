

import '../../model/instagram/instagram_media_model.dart';
import '../../model/instagram/instagram_user_model.dart';
import 'instagram_api_service.dart';
import 'instagram_auth_service.dart';

class InstagramRepository {
  final InstagramAuthService _authService;
  final InstagramApiService _apiService;

  InstagramRepository({
    required InstagramAuthService authService,
    required InstagramApiService apiService,
  })  : _authService = authService,
        _apiService = apiService;

  Future<String> signIn() => _authService.signIn();
  Future<void> signOut() => _authService.signOut();
  Future<String?> getStoredToken() => _authService.getStoredToken();
  Future<bool> isTokenValid() => _authService.isTokenValid();

  Future<InstagramUser> getUserProfile() async {
    final token = await _getValidToken();
    final user = await _apiService.getCurrentUser(token);
    return user.copyWith(accessToken: token);
  }

  Future<InstagramMediaResponse> getUserMedia({
    String? cursor,
    int limit = 12,
  }) async {
    final token = await _getValidToken();
    return _apiService.getUserMedia(token, cursor: cursor, limit: limit);
  }

  Future<String> _getValidToken() async {
    final token = await _authService.getStoredToken();
    if (token == null) throw Exception('لم يتم تسجيل الدخول');
    return token;
  }
}