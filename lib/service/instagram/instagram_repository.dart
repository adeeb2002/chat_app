import '../../model/instagram/instagram_media_model.dart';
import '../../model/instagram/instagram_user_model.dart';

import 'instagram_api_service.dart';
import 'instagram_auth_service.dart';

class InstagramRepository {
  final InstagramAuthService _auth;
  final InstagramApiService _api;

  InstagramRepository({
    required InstagramAuthService auth,
    required InstagramApiService api,
  })  : _auth = auth,
        _api = api;

  String buildAuthUrl() => _auth.buildAuthUrl();
  bool isRedirectUrl(String url) => _auth.isRedirectUrl(url);
  String? extractCode(String url) => _auth.extractCode(url);
  String? extractError(String url) => _auth.extractError(url);
  Future<bool> isLoggedIn() => _auth.isLoggedIn();
  Future<void> logout() => _auth.logout();

  Future<void> handleCode(String code) =>
      _auth.exchangeCodeForToken(code);

  Future<InstagramUser> getUserProfile() async {
    final token = await _getToken();
    final user = await _api.getCurrentUser(token);
    return user.copyWith(accessToken: token);
  }

  Future<InstagramMediaResponse> getUserMedia({
    String? cursor,
    int limit = 12,
  }) async {
    final token = await _getToken();
    return _api.getUserMedia(
      token,
      cursor: cursor,
      limit: limit,
    );
  }

  Future<List<InstagramMedia>> getUserStories() async {
    final token = await _getToken();
    return _api.getUserStories(token);
  }

  Future<String> _getToken() async {
    final token = await _auth.getValidToken();
    if (token == null) throw Exception('يجب تسجيل الدخول أولاً');
    return token;
  }
}