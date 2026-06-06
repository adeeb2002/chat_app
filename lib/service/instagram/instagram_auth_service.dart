import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../model/instagram/instagram_constants.dart';

class InstagramAuthService {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  InstagramAuthService({
    required Dio dio,
    required FlutterSecureStorage storage,
  })  : _dio = dio,
        _storage = storage;

  // بناء رابط OAuth
  String buildAuthUrl() {
    final params = {
      'client_id': InstagramConstants.clientId,
      'redirect_uri': InstagramConstants.redirectUri,
      'scope': InstagramConstants.scopes.join(','),
      'response_type': 'code',
    };
    final query = params.entries
        .map((e) =>
    '${Uri.encodeComponent(e.key)}'
        '=${Uri.encodeComponent(e.value)}')
        .join('&');
    return '${InstagramConstants.authBaseUrl}?$query';
  }

  // هل هذا رابط الـ callback?
  bool isRedirectUrl(String url) {
    return url.startsWith(InstagramConstants.redirectUri) ||
        url.startsWith('https://localhost');
  }

  // استخراج الكود
  String? extractCode(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.queryParameters['code'];
    } catch (_) {
      return null;
    }
  }

  // استخراج الخطأ
  String? extractError(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.queryParameters['error_description'] ??
          uri.queryParameters['error'];
    } catch (_) {
      return null;
    }
  }

  // تبديل الكود بـ Token
  Future<void> exchangeCodeForToken(String code) async {
    try {
      final response = await _dio.post(
        InstagramConstants.tokenUrl,
        data: {
          'client_id': InstagramConstants.clientId,
          'client_secret': InstagramConstants.clientSecret,
          'grant_type': 'authorization_code',
          'redirect_uri': InstagramConstants.redirectUri,
          'code': code,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      if (response.statusCode != 200) {
        final err = _parse(response.data);
        throw Exception(
          err['error_message'] ??
              err['message'] ??
              'فشل الحصول على رمز الوصول',
        );
      }

      final data = _parse(response.data);
      final shortToken = data['access_token']?.toString();
      final userId = data['user_id']?.toString();

      if (shortToken == null || shortToken.isEmpty) {
        throw Exception('رمز الوصول غير موجود');
      }

      if (userId != null) {
        await _storage.write(
          key: InstagramConstants.userIdKey,
          value: userId,
        );
      }

      await _toLongLivedToken(shortToken);
    } on DioException catch (e) {
      final data = _parse(e.response?.data);
      throw Exception(
        data['error_message'] ??
            data['message'] ??
            'خطأ في الشبكة',
      );
    }
  }

  // تحويل إلى Long-lived Token
  Future<void> _toLongLivedToken(String shortToken) async {
    final response = await _dio.get(
      InstagramConstants.longLivedTokenUrl,
      queryParameters: {
        'grant_type': 'ig_exchange_token',
        'client_secret': InstagramConstants.clientSecret,
        'access_token': shortToken,
      },
    );

    final data = _parse(response.data);
    final token = data['access_token']?.toString();
    if (token == null) throw Exception('فشل تحويل التوكن');

    final expiresIn =
        (data['expires_in'] as num?)?.toInt() ?? 5183944;
    final expiry =
    DateTime.now().add(Duration(seconds: expiresIn));

    await Future.wait([
      _storage.write(
        key: InstagramConstants.accessTokenKey,
        value: token,
      ),
      _storage.write(
        key: InstagramConstants.tokenExpiryKey,
        value: expiry.toIso8601String(),
      ),
    ]);
  }

  Future<String?> getValidToken() async {
    final token = await _storage.read(
      key: InstagramConstants.accessTokenKey,
    );
    if (token == null || token.isEmpty) return null;

    final expiryStr = await _storage.read(
      key: InstagramConstants.tokenExpiryKey,
    );
    if (expiryStr != null) {
      final expiry = DateTime.tryParse(expiryStr);
      if (expiry != null) {
        if (DateTime.now().isAfter(expiry)) {
          await logout();
          return null;
        }
        if (expiry.difference(DateTime.now()).inDays < 7) {
          return await _refresh(token);
        }
      }
    }
    return token;
  }

  Future<String?> _refresh(String token) async {
    try {
      final response = await _dio.get(
        '${InstagramConstants.graphBaseUrl}/refresh_access_token',
        queryParameters: {
          'grant_type': 'ig_refresh_token',
          'access_token': token,
        },
      );
      final data = _parse(response.data);
      final newToken = data['access_token']?.toString();
      if (newToken == null) return token;

      final expiresIn =
          (data['expires_in'] as num?)?.toInt() ?? 5183944;
      final expiry =
      DateTime.now().add(Duration(seconds: expiresIn));
      await Future.wait([
        _storage.write(
          key: InstagramConstants.accessTokenKey,
          value: newToken,
        ),
        _storage.write(
          key: InstagramConstants.tokenExpiryKey,
          value: expiry.toIso8601String(),
        ),
      ]);
      return newToken;
    } catch (_) {
      return token;
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(
      key: InstagramConstants.accessTokenKey,
    );
    if (token == null || token.isEmpty) return false;

    final expiryStr = await _storage.read(
      key: InstagramConstants.tokenExpiryKey,
    );
    if (expiryStr == null) return true;
    final expiry = DateTime.tryParse(expiryStr);
    if (expiry == null) return true;
    return DateTime.now().isBefore(expiry);
  }

  Future<void> logout() async {
    await Future.wait([
      _storage.delete(key: InstagramConstants.accessTokenKey),
      _storage.delete(key: InstagramConstants.userIdKey),
      _storage.delete(key: InstagramConstants.tokenExpiryKey),
    ]);
  }

  Map<String, dynamic> _parse(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      try {
        final d = jsonDecode(data);
        if (d is Map<String, dynamic>) return d;
      } catch (_) {}
    }
    return {};
  }
}