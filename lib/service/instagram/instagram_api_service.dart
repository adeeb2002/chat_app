import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:uuid/uuid.dart';

class InstagramApiService {
  late Dio dio;
  String? csrfToken;
  String? sessionId;
  String userId = '';
  String? username;

  static const String IG_SIG_KEY =
      '4f8732eb9ba7d1c8e8897a75d6474d4eb3f5279137431b2aafb71fafe2ade178';
  static const String IG_VERSION = '269.0.0.18.75';
  static const String USER_AGENT =
      'Instagram 269.0.0.18.75 Android (28/9; 480dpi; 1080x2088; samsung; SM-G960F; starlte; samsungexynos9810; ar_AE; 314665256)';

  InstagramApiService() {
    _initializeDio();
  }

  void _initializeDio() {
    dio = Dio(BaseOptions(
      baseUrl: 'https://i.instagram.com',
      connectTimeout: Duration(seconds: 30),
      receiveTimeout: Duration(seconds: 30),
      headers: {
        'User-Agent': USER_AGENT,
        'Accept-Language': 'ar-AE,ar;q=0.9,en-US;q=0.8,en;q=0.7',
        'Accept-Encoding': 'gzip, deflate',
        'Connection': 'keep-alive',
        'X-IG-Capabilities': '3brTvw==',
        'X-IG-Connection-Type': 'WIFI',
        'X-IG-App-ID': '567067343352427',
        'Accept': '*/*',
      },
    ));

    var cookieJar = CookieJar();
    dio.interceptors.add(CookieManager(cookieJar));
  }

  String _generateDeviceId(String username, String password) {
    final seed = '$username$password';
    final hash = md5.convert(utf8.encode(seed));
    return 'android-${hash.toString().substring(0, 16)}';
  }

  String _generateUUID() {
    return const Uuid().v4();
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      this.username = username;

      // 1. جلب CSRF Token
      await dio.get(
          '/api/v1/si/fetch_headers/?challenge_type=signup&guid=${_generateUUID()}');

      await Future.delayed(Duration(seconds: 2));

      // 2. تحضير بيانات تسجيل الدخول
      final deviceId = _generateDeviceId(username, password);
      final uuid = _generateUUID();

      Map<String, dynamic> loginData = {
        'username': username,
        'password': password,
        'guid': uuid,
        'device_id': deviceId,
        'phone_id': _generateUUID(),
        'login_attempt_count': '0',
        '_csrftoken': 'missing',
      };

      String payload = json.encode(loginData);

      // 3. تسجيل الدخول
      var response = await dio.post(
        '/api/v1/accounts/login/',
        data: 'signed_body=SIGNATURE.$payload&ig_sig_key_version=4',
        options: Options(
          contentType: 'application/x-www-form-urlencoded; charset=UTF-8',
          headers: {
            'X-CSRFToken': 'missing',
          },
        ),
      );

      if (response.data['status'] == 'ok') {
        userId = response.data['logged_in_user']['pk'].toString();

        // استخراج الكوكيز
        var cookies = response.headers['set-cookie'];
        if (cookies != null) {
          for (var cookie in cookies) {
            if (cookie.contains('csrftoken=')) {
              csrfToken = cookie.split('csrftoken=')[1].split(';')[0];
            }
            if (cookie.contains('sessionid=')) {
              sessionId = cookie.split('sessionid=')[1].split(';')[0];
            }
          }
        }

        return {
          'success': true,
          'user': response.data['logged_in_user'],
          'message': 'تم تسجيل الدخول بنجاح'
        };
      }

      return {
        'success': false,
        'message': response.data['message'] ?? 'فشل تسجيل الدخول'
      };
    } on DioException catch (e) {
      return {'success': false, 'message': _handleDioError(e)};
    } catch (e) {
      return {'success': false, 'message': 'خطأ: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> getInbox({String? cursor}) async {
    try {
      Map<String, dynamic> params = {};
      if (cursor != null) {
        params['cursor'] = cursor;
      }

      var response = await dio.get(
        '/api/v1/direct_v2/inbox/',
        queryParameters: params,
        options: Options(
          headers: {
            'X-CSRFToken': csrfToken ?? '',
          },
        ),
      );

      if (response.data['status'] == 'ok') {
        return {
          'success': true,
          'threads': response.data['inbox']['threads'] ?? [],
          'has_older': response.data['inbox']['has_older'] ?? false,
          'oldest_cursor': response.data['inbox']['oldest_cursor'],
        };
      }

      return {'success': false, 'threads': []};
    } catch (e) {
      print('خطأ جلب المحادثات: $e');
      return {'success': false, 'threads': [], 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getThreadMessages(String threadId,
      {String? cursor}) async {
    try {
      Map<String, dynamic> params = {};
      if (cursor != null) {
        params['cursor'] = cursor;
      }

      var response = await dio.get(
        '/api/v1/direct_v2/threads/$threadId/',
        queryParameters: params,
        options: Options(
          headers: {
            'X-CSRFToken': csrfToken ?? '',
          },
        ),
      );

      if (response.data['status'] == 'ok') {
        return {
          'success': true,
          'messages': response.data['thread']['items'] ?? [],
          'users': response.data['thread']['users'] ?? [],
          'has_older': response.data['thread']['has_older'] ?? false,
          'oldest_cursor': response.data['thread']['oldest_cursor'],
        };
      }

      return {'success': false, 'messages': []};
    } catch (e) {
      print('خطأ جلب الرسائل: $e');
      return {'success': false, 'messages': [], 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> sendMessage(
      String threadId, String message) async {
    try {
      final clientContext = _generateUUID();

      var response = await dio.post(
        '/api/v1/direct_v2/threads/broadcast/text/',
        data: {
          'recipient_users': '[]',
          'action': 'send_item',
          'thread_ids': '["$threadId"]',
          'client_context': clientContext,
          'text': message,
          '_uuid': _generateUUID(),
        },
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          headers: {
            'X-CSRFToken': csrfToken ?? '',
          },
        ),
      );

      return {
        'success': response.data['status'] == 'ok',
        'message':
        response.data['status'] == 'ok' ? 'تم الإرسال' : 'فشل الإرسال'
      };
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الإرسال: ${e.toString()}'};
    }
  }

  String _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'انتهت مهلة الاتصال';
      case DioExceptionType.sendTimeout:
        return 'انتهت مهلة الإرسال';
      case DioExceptionType.receiveTimeout:
        return 'انتهت مهلة الاستقبال';
      case DioExceptionType.badResponse:
        if (e.response?.statusCode == 400) {
          return 'خطأ في بيانات تسجيل الدخول';
        } else if (e.response?.statusCode == 401) {
          return 'اسم المستخدم أو كلمة المرور خاطئة';
        }
        return 'خطأ من الخادم: ${e.response?.statusCode}';
      case DioExceptionType.cancel:
        return 'تم إلغاء الطلب';
      default:
        return 'تحقق من الاتصال بالإنترنت';
    }
  }

  Future<void> logout() async {
    try {
      await dio.post(
        '/api/v1/accounts/logout/',
        options: Options(
          headers: {'X-CSRFToken': csrfToken ?? ''},
        ),
      );
    } catch (e) {
      print('خطأ تسجيل الخروج: $e');
    } finally {
      csrfToken = null;
      sessionId = null;
      userId = '';
      username = null;
    }
  }
}