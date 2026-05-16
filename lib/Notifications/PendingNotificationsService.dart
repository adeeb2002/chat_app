// lib/services/pending_notifications_service.dart

import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'notifications.dart';

class PendingNotificationsService {
  static final PendingNotificationsService _instance =
  PendingNotificationsService._internal();
  factory PendingNotificationsService() => _instance;
  PendingNotificationsService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  StreamSubscription? _connectionSubscription;
  bool _isProcessing = false;

  void startMonitoring() {
    print('🔍 بدء مراقبة الإشعارات المعلقة...');

    _connectionSubscription = InternetConnection().onStatusChange.listen((status) {
      if (status == InternetStatus.connected) {
        print('🌐 عاد الاتصال! محاولة إرسال الإشعارات المعلقة...');
        _processPendingNotifications();
      }
    });
  }

  Future<void> addPendingNotification({
    required String chatId,
    required String messageId,
    required String senderEmail,
    required String receiverEmail,
    required String messageBody,
    required int timestamp,
  }) async {
    try {
      print('📝 حفظ إشعار معلق...');
      print('From: $senderEmail');
      print('To: $receiverEmail');

      final notificationRef = _db.ref('pendingNotifications').push();

      await notificationRef.set({
        'chatId': chatId,
        'messageId': messageId,
        'senderEmail': senderEmail,
        'receiverEmail': receiverEmail,
        'messageBody': messageBody,
        'timestamp': timestamp,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'status': 'pending',
        'attempts': 0,
      });

      print('✅ تم حفظ الإشعار المعلق بنجاح');
    } catch (e) {
      print('❌ خطأ في حفظ الإشعار المعلق: $e');
    }
  }

  Future<void> _processPendingNotifications() async {
    if (_isProcessing) {
      print('⏳ المعالجة جارية بالفعل...');
      return;
    }

    _isProcessing = true;
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🔄 بدء معالجة الإشعارات المعلقة...');

    try {
      final snapshot = await _db
          .ref('pendingNotifications')
          .orderByChild('status')
          .equalTo('pending')
          .get();

      if (!snapshot.exists) {
        print('✅ لا توجد إشعارات معلقة');
        _isProcessing = false;
        return;
      }

      final notifications = snapshot.value as Map<dynamic, dynamic>;
      print('📊 عدد الإشعارات المعلقة: ${notifications.length}');

      for (var entry in notifications.entries) {
        final notificationId = entry.key.toString();
        final data = Map<String, dynamic>.from(entry.value);

        try {
          final senderName = data['senderEmail'].toString().split('@').first;

          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          print('📤 إرسال إشعار معلق...');
          print('ID: $notificationId');
          print('From: ${data['senderEmail']}');
          print('To: ${data['receiverEmail']}');
          print('Body: ${data['messageBody']}');

          // داخل الحلقة التكرارية (Loop) في معالجة الإشعارات المعلقة
          final success = await NotificationService().sendMessageNotification(
            targetEmail: data['receiverEmail'],
            senderName: senderName,
            messageBody: data['messageBody'],
            chatId: data['chatId'],
            messageId: data['messageId'],
          );

          if (success) {
            await _db
                .ref('pendingNotifications')
                .child(notificationId)
                .update({
              'status': 'sent',
              'sentAt': DateTime.now().millisecondsSinceEpoch,
            });

            print('✅✅✅ تم إرسال الإشعار المعلق بنجاح');

            Future.delayed(const Duration(seconds: 5), () {
              _db.ref('pendingNotifications').child(notificationId).remove();
            });
          } else {
            final attempts = (data['attempts'] ?? 0) + 1;
            await _db
                .ref('pendingNotifications')
                .child(notificationId)
                .update({
              'attempts': attempts,
              'lastAttempt': DateTime.now().millisecondsSinceEpoch,
            });

            if (attempts >= 3) {
              await _db
                  .ref('pendingNotifications')
                  .child(notificationId)
                  .update({'status': 'failed'});

              print('❌ فشل إرسال الإشعار بعد 3 محاولات');
            } else {
              print('⚠️ فشل الإرسال، المحاولة $attempts من 3');
            }
          }
        } catch (e) {
          print('❌ خطأ في إرسال إشعار معلق: $e');
        }

        await Future.delayed(const Duration(milliseconds: 500));
      }

      print('✅ انتهت معالجة الإشعارات المعلقة');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    } catch (e) {
      print('❌ خطأ في معالجة الإشعارات المعلقة: $e');
    } finally {
      _isProcessing = false;
    }
  }

  void stopMonitoring() {
    _connectionSubscription?.cancel();
    print('🛑 تم إيقاف مراقبة الإشعارات المعلقة');
  }
}