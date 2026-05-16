// lib/services/notifications/notification_service.dart

import 'dart:convert';
import 'package:ChatApp/model/NotificationType.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final String _restApiKey = 'os_v2_app_ehltm5wfuzbg5bp2szs4tney5aazwiqocvouwl4nmsrjp7fcmsjbxi25pqw653ncsyevmd5e77hubny6sgf6alhny25wq6pfuebo5kq';
  final String _appId = '21d73676-c5a6-426e-85fa-9665c9b498e8';

  bool _isInitialized = false; // ✅ متغير لتتبع التهيئة

  /// ✅ تهيئة OneSignal
  Future<void> initialize() async {
    if (_isInitialized) {
      print('⚠️ OneSignal مهيأ مسبقاً');
      return;
    }

    print('🔔 بدء تهيئة OneSignal...');

    try {
      // تفعيل وضع Debug
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

      // تهيئة OneSignal
      OneSignal.initialize(_appId);

      // ✅ انتظر قليلاً للتأكد من اكتمال التهيئة
      await Future.delayed(const Duration(milliseconds: 500));

      // طلب أذونات الإشعارات
      await OneSignal.Notifications.requestPermission(true);

      _isInitialized = true; // ✅ علّم إن التهيئة تمت
      print('✅ تم تهيئة OneSignal بنجاح');
    } catch (e) {
      print('❌ خطأ في تهيئة OneSignal: $e');
      _isInitialized = false;
    }
  }

  /// ✅ تسجيل المستخدم (مع فحص التهيئة)
  Future<void> loginUser(String userEmail) async {
    try {
      // ✅ تأكد من التهيئة أولاً
      if (!_isInitialized) {
        print('⚠️ OneSignal غير مهيأ، جاري التهيئة...');
        await initialize();
        
        // انتظر قليلاً بعد التهيئة
        await Future.delayed(const Duration(milliseconds: 500));
      }

      print('👤 تسجيل المستخدم: $userEmail');

      final cleanEmail = userEmail.toLowerCase().trim();

      // تسجيل الدخول
      await OneSignal.login(cleanEmail);
      
      // ✅ انتظر قليلاً للتأكد من اكتمال التسجيل
      await Future.delayed(const Duration(milliseconds: 300));
      
      // تعيين Alias إضافي
      OneSignal.User.addAlias('email', cleanEmail);

      // الحصول على OneSignal ID
      final osId = OneSignal.User.pushSubscription.id;
      print('✅ OneSignal ID: $osId');
      print('✅ تم تسجيل المستخدم بنجاح');
    } catch (e) {
      print('❌ خطأ في تسجيل المستخدم: $e');
      
      // ✅ محاولة أخيرة بعد تأخير
      try {
        print('🔄 محاولة إعادة التسجيل...');
        await Future.delayed(const Duration(seconds: 1));
        
        final cleanEmail = userEmail.toLowerCase().trim();
        await OneSignal.login(cleanEmail);
        OneSignal.User.addAlias('email', cleanEmail);
        
        print('✅ نجح التسجيل في المحاولة الثانية');
      } catch (retryError) {
        print('❌ فشل التسجيل نهائياً: $retryError');
      }
    }
  }

  /// ✅ تسجيل خروج المستخدم
  Future<void> logoutUser() async {
    try {
      if (!_isInitialized) {
        print('⚠️ OneSignal غير مهيأ');
        return;
      }

      await OneSignal.logout();
      print('✅ تم تسجيل خروج المستخدم');
    } catch (e) {
      print('❌ خطأ في تسجيل الخروج: $e');
    }
  }

  /// ✅ إرسال إشعار
  Future<bool> sendNotification(NotificationPayload payload, String targetEmail) async {
    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📤 إرسال إشعار...');
      print('🎯 المستلم: $targetEmail');
      print('📦 النوع: ${payload.type.name}');

      final cleanEmail = targetEmail.toLowerCase().trim();
      final chat_messages='chat_messages';

      final response = await http.post(
        Uri.parse('https://api.onesignal.com/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': _restApiKey,
        },
        body: json.encode({
          'app_id': _appId,
          'target_channel': 'push',
          'include_aliases': {
            'external_id': [cleanEmail]
          },
          'headings': {'en': payload.title, 'ar': payload.title},
          'contents': {'en': payload.body, 'ar': payload.body},
          'data': payload.toDataMap(),
          'priority': 10,
          'ttl': 86400,
          'android_channel_id': chat_messages,
        }),
      ).timeout(const Duration(seconds: 15));

      print('📡 Response Status: ${response.statusCode}');
      print('📡 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final recipients = data['recipients'] ?? 0;
        
        if (recipients > 0) {
          print('✅✅✅ تم إرسال الإشعار بنجاح');
          return true;
        } else {
          print('⚠️ لم يتم إرسال الإشعار (0 recipients)');
          print('💡 تأكد من أن المستخدم مسجل في OneSignal');
          return false;
        }
      } else {
        print('❌ فشل الإرسال: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ خطأ في إرسال الإشعار: $e');
      return false;
    } finally {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }
  }

  /// ✅ إرسال إشعار رسالة
  Future<bool> sendMessageNotification({
    required String targetEmail,
    required String senderName,
    required String messageBody,
    required String chatId,
    String? messageId,
  }) async {
    final payload = NotificationPayload(
      type: NotificationType.message,
      title: '💬 $senderName',
      body: messageBody,
      chatId: chatId,
      senderId: senderName,
      messageId: messageId,
    );

    return await sendNotification(payload, targetEmail);
  }
}