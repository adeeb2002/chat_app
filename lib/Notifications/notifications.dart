// lib/services/notifications/notification_service.dart


import 'dart:convert';
import 'package:ChatApp/model/NotificationType.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final String _restApiKey = 'os_v2_app_ehltm5wfuzbg5bp2szs4tney5aazwiqocvouwl4nmsrjp7fcmsjbxi25pqw653ncsyevmd5e77hubny6sgf6alhny25wq6pfuebo5kq';
  final String _appId = '21d73676-c5a6-426e-85fa-9665c9b498e8';

  bool _isInitialized = false; // ✅ متغير لتتبع التهيئة

  // 1️⃣ متغير لحفظ الـ ID الخاص بالمحادثة المفتوحة حالياً في التطبيق
  static String? currentOpenChatId;

  /// ✅ تهيئة OneSignal
  Future<void> initialize() async {
    if (_isInitialized) {
      print('⚠️ OneSignal مهيأ مسبقاً');
      return;
    }

    print('🔔 بدء تهيئة OneSignal...');

    try {
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      OneSignal.initialize(_appId);

      await Future.delayed(const Duration(milliseconds: 500));
      await OneSignal.Notifications.requestPermission(true);

      // 2️⃣ الاستماع للإشعارات القادمة والتطبيق مفتوح في الواجهة (Foreground)
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        print('🔔 استلام إشعار والتطبيق في الواجهة...');

        // استخراج البيانات الإضافية المرسلة مع الإشعار (data payload)
        final additionalData = event.notification.additionalData;

        if (additionalData != null && additionalData.containsKey('chatId')) {
          final incomingChatId = additionalData['chatId'].toString();

          // 3️⃣ المقارنة: إذا كان الـ chatId القادم هو نفسه المفتوح حالياً، قم بكتم الإشعار فوراً!
          if (currentOpenChatId == incomingChatId) {
            print('🤫 تم كتم الإشعار لأن المستخدم داخل شاشة المحادثة حالياً ($incomingChatId)');
            event.preventDefault(); // 🚫 يمنع OneSignal من إظهار الإشعار للنظام
            return;
          }
        }

        // إذا كانت محادثة أخرى أو التطبيق في مكان آخر، اسمح بظهور الإشعار بشكل طبيعي
        event.notification.display();
      });

      _isInitialized = true;
      print('✅ تم تهيئة OneSignal بنجاح مع مستمع الواجهة');
    } catch (e) {
      print('❌ خطأ في تهيئة OneSignal: $e');
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
      print('📱 App ID: $_appId');
      print('🔐 REST API Key (أول 20 حرف): ${_restApiKey.substring(0, 20)}...');
      print('📦 النوع: ${payload.type.name}');

      final cleanEmail = targetEmail.toLowerCase().trim();

      final response = await http.post(
        Uri.parse('https://api.onesignal.com/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': _restApiKey, // تأكد من نقلها لـ .env لاحقاً
        },
        body: json.encode({
          'app_id': _appId,
          // التعديل هنا: استخدام include_external_user_ids مباشرة وهي الأضمن والأدق لـ API الإرسال المباشر
          'include_external_user_ids': [cleanEmail],
          'headings': {'en': payload.title, 'ar': payload.title},
          'contents': {'en': payload.body, 'ar': payload.body},
          'data': payload.toDataMap(),
          'priority': 10,
          'ttl': 86400,
          //'android_channel_id': 'chat_messages',
        }),
      ).timeout(const Duration(seconds: 15));

      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📡 Response Status: ${response.statusCode}');
      print('📡 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final recipients = data['recipients'] ?? 0;
        final errors = data['errors'];

        if (errors != null && errors.isNotEmpty) {
          print('⚠️ أخطاء OneSignal: $errors');
        }

        if (recipients > 0) {
          print('✅✅✅ تم إرسال الإشعار بنجاح إلى $recipients جهاز');
          return true;
        } else {
          print('⚠️ لم يتم إرسال الإشعار (0 مستلمين)');
          print('💡 أسباب محتملة:');
          print('   1. المستخدم لم يسجل الدخول إلى OneSignal');
          print('   2. البريد الإلكتروني غير مطابق');
          return false;
        }
      } else if (response.statusCode == 401) {
        print('❌ خطأ في المصادقة (401) - مفتاح REST API غير صالح');
        print('💡 تأكد من أنك تستخدم REST API Key الصحيح من لوحة التحكم');
        return false;
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