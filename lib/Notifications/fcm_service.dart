// lib/services/fcm_service.dart

import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;

  // إرسال إشعار إلى مستخدم معين
  Future<void> sendNotification({
    required String receiverUserId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // الحصول على FCM token للمستخدم المستلم
      final snapshot = await _db.ref('users').child(receiverUserId).get();
      if (!snapshot.exists) return;

      final userData = snapshot.value as Map<dynamic, dynamic>?;
      final fcmToken = userData?['fcmToken'] as String?;

      if (fcmToken == null || fcmToken.isEmpty) return;

      // إرسال الإشعار عبر FCM
      await _sendFCMMessage(
        token: fcmToken,
        title: title,
        body: body,
        data: data,
      );
    } catch (e) {
      print('❌ Error sending notification: $e');
    }
  }

  // إرسال رسالة FCM
  Future<void> _sendFCMMessage({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    const String serverKey = 'YOUR_SERVER_KEY'; // 🔥 استبدلها بمفتاح الخادم من Firebase Console

    final Map<String, dynamic> message = {
      'to': token,
      'notification': {
        'title': title,
        'body': body,
        'sound': 'default',
      },
      'data': data ?? {},
      'priority': 'high',
    };

    try {
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: json.encode(message),
      );

      if (response.statusCode == 200) {
        print('✅ Notification sent successfully');
      } else {
        print('❌ Failed to send notification: ${response.body}');
      }
    } catch (e) {
      print('❌ Error sending FCM message: $e');
    }
  }
}