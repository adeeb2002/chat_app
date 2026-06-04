import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../../model/instagram/instagram_constants.dart';


class InstagramAuthService {
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  InstagramAuthService({
    required Dio dio,
    required FlutterSecureStorage secureStorage,
  })  : _dio = dio,
        _secureStorage = secureStorage;

  // ========================
  // بناء رابط OAuth
  // ========================
  String _buildAuthUrl() {
    final params = {
      'client_id': InstagramConstants.clientId,
      'redirect_uri': InstagramConstants.redirectUri,
      'scope': InstagramConstants.scopes.join(','),
      'response_type': 'code',
    };

    final queryString = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return '${InstagramConstants.authBaseUrl}?$queryString';
  }

  // ========================
  // تسجيل الدخول
  // ========================
  Future<String> signIn() async {
    try {
      // فتح متصفح OAuth
      final result = await FlutterWebAuth2.authenticate(
        url: _buildAuthUrl(),
        callbackUrlScheme: 'myapp',
        options: const FlutterWebAuth2Options(
          preferEphemeral: true,
        ),
      );

      // استخراج الكود من الرابط
      final uri = Uri.parse(result);
      final code = uri.queryParameters['code'];

      if (code == null) {
        throw Exception('لم يتم الحصول على authorization code');
      }

      // تحويل الكود إلى Access Token
      final shortLivedToken = await _exchangeCodeForToken(code);

      // تحويل Short-lived Token إلى Long-lived Token
      final longLivedToken = await _exchangeForLongLivedToken(shortLivedToken);

      // حفظ التوكن بأمان
      await _saveToken(longLivedToken);

      return longLivedToken;
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  // ========================
  // تبديل الكود بتوكن
  // ========================
  Future<String> _exchangeCodeForToken(String code) async {
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
      ),
    );

    if (response.data == null) {
      throw Exception('فشل في الحصول على التوكن');
    }

    final data = response.data is String
        ? jsonDecode(response.data)
        : response.data;

    return data['access_token'] as String;
  }

  // ========================
  // تحويل إلى Long-lived Token (60 يوم)
  // ========================
  Future<String> _exchangeForLongLivedToken(String shortLivedToken) async {
    final response = await _dio.get(
      InstagramConstants.longLivedTokenUrl,
      queryParameters: {
        'grant_type': 'ig_exchange_token',
        'client_secret': InstagramConstants.clientSecret,
        'access_token': shortLivedToken,
      },
    );

    final data = response.data is String
        ? jsonDecode(response.data)
        : response.data;

    final token = data['access_token'] as String;
    final expiresIn = data['expires_in'] as int? ?? 5183944;

    // حفظ تاريخ انتهاء الصلاحية
    final expiryDate = DateTime.now().add(Duration(seconds: expiresIn));
    await _secureStorage.write(
      key: InstagramConstants.tokenExpiryKey,
      value: expiryDate.toIso8601String(),
    );

    return token;
  }

  // ========================
  // تجديد التوكن تلقائياً
  // ========================
  Future<String?> refreshToken() async {
    final currentToken = await getStoredToken();
    if (currentToken == null) return null;

    try {
      final response = await _dio.get(
        'https://graph.instagram.com/refresh_access_token',
        queryParameters: {
          'grant_type': 'ig_refresh_token',
          'access_token': currentToken,
        },
      );

      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      final newToken = data['access_token'] as String;
      await _saveToken(newToken);
      return newToken;
    } catch (e) {
      return null;
    }
  }

  // ========================
  // حفظ التوكن
  // ========================
  Future<void> _saveToken(String token) async {
    await _secureStorage.write(
      key: InstagramConstants.accessTokenKey,
      value: token,
    );
  }

  // ========================
  // قراءة التوكن المحفوظ
  // ========================
  Future<String?> getStoredToken() async {
    return await _secureStorage.read(key: InstagramConstants.accessTokenKey);
  }

  // ========================
  // التحقق من صلاحية التوكن
  // ========================
  Future<bool> isTokenValid() async {
    final token = await getStoredToken();
    if (token == null) return false;

    final expiryString = await _secureStorage.read(
      key: InstagramConstants.tokenExpiryKey,
    );

    if (expiryString == null) return true;

    final expiry = DateTime.tryParse(expiryString);
    if (expiry == null) return true;

    // تجديد إذا كان سينتهي خلال 7 أيام
    if (expiry.difference(DateTime.now()).inDays < 7) {
      await refreshToken();
    }

    return DateTime.now().isBefore(expiry);
  }

  // ========================
  // تسجيل الخروج
  // ========================
  Future<void> signOut() async {
    await _secureStorage.delete(key: InstagramConstants.accessTokenKey);
    await _secureStorage.delete(key: InstagramConstants.userIdKey);
    await _secureStorage.delete(key: InstagramConstants.tokenExpiryKey);
  }

  // ========================
  // معالجة الأخطاء
  // ========================
  Exception _handleAuthError(dynamic error) {
    if (error is DioException) {
      switch (error.response?.statusCode) {
        case 400: return Exception('طلب غير صحيح');
        case 401: return Exception('غير مصرح له');
        case 403: return Exception('تم رفض الوصول');
        default: return Exception('خطأ في الشبكة: ${error.message}');
      }
    }
    return Exception(error.toString());
  }
}