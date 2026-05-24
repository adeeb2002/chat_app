// lib/Notifications/notifications.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../model/NotificationType.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const String _restApiKey = "os_v2_app_ehltm5wfuzyb9sbp2s4z6tney5aazwiqocvouwL4nmsrjp7fcmsjbxi25pqw653ncseyemd5e77l";
  static const String _appId = "21d73676-c5a6-426e-85fa-9665c9b9688";

  bool _isInitialized = false;
  static String? currentOpenChatId;

  /// ✅ تهيئة OneSignal بشكل آمن
  Future<void> initialize() async {
    if (_isInitialized) {
      print('⚠️ OneSignal مهيأ مسبقاً');
      return;
    }

    print('🔔 بدء تهيئة OneSignal...');

    try {
      // ✅ تفعيل وضع Debug فقط في وضع التطوير
      if (kDebugMode) {
        OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      }

      // ✅ تهيئة OneSignal
      OneSignal.initialize(_appId);

      // ✅ انتظار قليل للتأكد من اكتمال التهيئة
      await Future.delayed(const Duration(milliseconds: 300));

      // ✅ طلب أذونات الإشعارات
      await OneSignal.Notifications.requestPermission(true);

      _isInitialized = true;
      print('✅ تم تهيئة OneSignal بنجاح');
    } catch (e) {
      print('❌ خطأ في تهيئة OneSignal: $e');
      _isInitialized = false;
    }
  }

  /// ✅ تسجيل المستخدم (مع فحص التهيئة)
  Future<void> loginUser(String userPhone) async {
    try {
      if (!_isInitialized) {
        print('⚠️ OneSignal غير مهيأ، جاري التهيئة...');
        await initialize();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      print('👤 تسجيل المستخدم: $userPhone');
      final cleanPhone = userPhone.toLowerCase().trim();

      await OneSignal.login(cleanPhone);
      await Future.delayed(const Duration(milliseconds: 300));
      await OneSignal.User.addAlias('phone', cleanPhone);

      final osId = OneSignal.User.pushSubscription.id;
      print('✅ OneSignal ID: $osId');
      print('✅ تم تسجيل المستخدم بنجاح');
    } catch (e) {
      print('❌ خطأ في تسجيل المستخدم: $e');
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
  Future<bool> sendNotification(NotificationPayload payload, String targetPhone) async {
    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📤 إرسال إشعار...');
      print('🎯 المستلم: $targetPhone');

      final cleanPhone = targetPhone.toLowerCase().trim();

      final requestBody = {
        'app_id': _appId,
        'target_channel': 'push',
        'include_aliases': {
          'external_id': [cleanPhone]
        },
        'headings': {'en': payload.title, 'ar': payload.title},
        'contents': {'en': payload.body, 'ar': payload.body},
        'data': payload.toDataMap(),
        'priority': 10,
        'ttl': 86400,
      };

      final response = await http.post(
        Uri.parse('https://api.onesignal.com/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $_restApiKey',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 15));

      print('📡 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final recipients = data['recipients'] ?? 0;

        if (recipients > 0) {
          print('✅✅✅ تم إرسال الإشعار بنجاح');
          return true;
        } else {
          print('⚠️ لم يتم إرسال الإشعار (0 recipients)');
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
    required String targetPhone,
    required String senderName,
    required String messageBody,
    required String chatId,
    String? messageId,
  }) async {
    // ✅ لا ترسل إشعار إذا كانت المحادثة مفتوحة حالياً
    if (currentOpenChatId == chatId) {
      print('📱 المستخدم في المحادثة حالياً، لن يتم إرسال إشعار');
      return false;
    }

    final payload = NotificationPayload(
      type: NotificationType.message,
      title: '💬 $senderName',
      body: messageBody,
      chatId: chatId,
      senderId: senderName,
      messageId: messageId,
    );

    return await sendNotification(payload, targetPhone);
  }

  /// ✅ تنظيف الموارد (يُستدعى عند إغلاق التطبيق)
  void dispose() {
    print('🔴 تنظيف OneSignal...');
    _isInitialized = false;
  }
}