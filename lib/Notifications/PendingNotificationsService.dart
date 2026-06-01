// lib/services/pending_notifications_service.dart

import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'notifications.dart';

class PendingNotificationsService {
  static final PendingNotificationsService _instance =
  PendingNotificationsService._internal();
  factory PendingNotificationsService() => _instance;
  PendingNotificationsService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  StreamSubscription<List<ConnectivityResult>>? _connectionSubscription;
  bool _isProcessing = false;

  // ✅ مجموعة لتتبع الإشعارات الجاري معالجتها (لمنع التكرار)
  final Set<String> _processingIds = {};

  Future<void> startMonitoring() async{
    print('🔍 بدء مراقبة الإشعارات المعلقة...');

    _connectionSubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      final hasConnection = result.contains(ConnectivityResult.mobile) || result.contains(ConnectivityResult.wifi);
      if (hasConnection) {
        print('🌐 عاد الاتصال! محاولة إرسال الإشعارات المعلقة...');
        _processPendingNotifications();
      }
    });
  }

  Future<void> addPendingNotification({
    required String chatId,
    required String messageId,
    required String senderPhone,
    required String receiverPhone,
    required String messageBody,
    required int timestamp,
  }) async {
    try {
      print('📝 حفظ إشعار معلق...');
      print('From: $senderPhone');
      print('To: $receiverPhone');

      final notificationRef = _db.ref('pendingNotifications').push();

      await notificationRef.set({
        'chatId': chatId,
        'messageId': messageId,
        'senderPhone': senderPhone,
        'receiverPhone': receiverPhone,
        'messageBody': messageBody,
        'timestamp': timestamp,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'status': 'pending',  // pending, sent, failed
        'attempts': 0,
      });

      print('✅ تم حفظ الإشعار المعلق بنجاح');
    } catch (e) {
      print('❌ خطأ في حفظ الإشعار المعلق: $e');
    }
  }

  Future<void> _processPendingNotifications() async {
    // ✅ منع المعالجة المتزامنة
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

        // ✅ تخطي الإشعارات الجاري معالجتها حالياً
        if (_processingIds.contains(notificationId)) {
          print('⚠️ الإشعار $notificationId قيد المعالجة بالفعل، يتم تخطيه');
          continue;
        }

        _processingIds.add(notificationId);

        final data = Map<String, dynamic>.from(entry.value);

        // ✅ التحقق من الحالة مرة أخرى (قد تكون تغيرت)
        if (data['status'] != 'pending') {
          print('⚠️ الإشعار $notificationId حالته ${data['status']}، يتم تخطيه');
          _processingIds.remove(notificationId);
          continue;
        }

        try {
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          print('📤 إرسال إشعار معلق...');
          print('ID: $notificationId');
          print('From: ${data['senderPhone']}');
          print('To: ${data['receiverPhone']}');
          print('Body: ${data['messageBody']}');
          print('المحاولة: ${(data['attempts'] ?? 0) + 1}');

          final success = await NotificationService().sendMessageNotification(
            targetPhone: data['receiverPhone'],
            senderName: data['senderPhone'],
            messageBody: data['messageBody'],
            chatId: data['chatId'],
            messageId: data['messageId'],
          );

          if (success) {
            // ✅ تحديث الحالة إلى sent وحذف الإشعار فوراً
            await _db
                .ref('pendingNotifications')
                .child(notificationId)
                .update({
              'status': 'sent',
              'sentAt': DateTime.now().millisecondsSinceEpoch,
            });

            // ✅ حذف الإشعار فوراً (بدون تأخير)
            await _db.ref('pendingNotifications').child(notificationId).remove();

            print('✅✅✅ تم إرسال الإشعار المعلق وحذفه بنجاح');
          } else {
            final attempts = (data['attempts'] ?? 0) + 1;
            if(attempts==2 || attempts >= 3) {
              await _db.ref('pendingNotifications')
                  .child(notificationId).remove();
            }
          }
        } catch (e) {
          print('❌ خطأ في إرسال إشعار معلق: $e');

          // ✅ تسجيل الخطأ وزيادة عدد المحاولات
          final attempts = (data['attempts'] ?? 0) + 1;
          await _db
              .ref('pendingNotifications')
              .child(notificationId)
              .update({
            'attempts': attempts,
            'lastError': e.toString(),
            'lastAttempt': DateTime.now().millisecondsSinceEpoch,
          });

          if (attempts >= 3) {
            await _db
                .ref('pendingNotifications')
                .child(notificationId)
                .update({
              'status': 'failed',
              'failedAt': DateTime.now().millisecondsSinceEpoch,
              'failureReason': 'خطأ: ${e.toString()}'
            });
          }
        } finally {
          // ✅ إزالة المعرف من مجموعة المعالجة
          _processingIds.remove(notificationId);
        }

        // ✅ انتظار قليل بين الإشعارات لتجنب الـ rate limiting
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

  // ✅ دالة لإعادة محاولة الإشعارات الفاشلة يدوياً
  Future<void> retryFailedNotifications() async {
    print('🔄 إعادة محاولة إرسال الإشعارات الفاشلة...');

    try {
      final snapshot = await _db
          .ref('pendingNotifications')
          .orderByChild('status')
          .equalTo('failed')
          .get();

      if (!snapshot.exists) {
        print('✅ لا توجد إشعارات فاشلة');
        return;
      }

      final notifications = snapshot.value as Map<dynamic, dynamic>;
      print('📊 عدد الإشعارات الفاشلة: ${notifications.length}');

      for (var entry in notifications.entries) {
        final notificationId = entry.key.toString();

        // ✅ إعادة تعيين الحالة إلى pending
        await _db.ref('pendingNotifications').child(notificationId).update({
          'status': 'pending',
          'attempts': 0,
          'resetAt': DateTime.now().millisecondsSinceEpoch,
        });

        print('✅ تم إعادة تعيين الإشعار $notificationId للمحاولة مرة أخرى');
      }

      // ✅ بدء المعالجة
      await _processPendingNotifications();

    } catch (e) {
      print('❌ خطأ في إعادة محاولة الإشعارات الفاشلة: $e');
    }
  }

  // ✅ دالة لتنظيف الإشعارات القديمة
  Future<void> cleanOldNotifications({int daysOld = 7}) async {
    print('🧹 تنظيف الإشعارات القديمة (أكثر من $daysOld يوم)...');

    try {
      final cutoffTime = DateTime.now().subtract(Duration(days: daysOld)).millisecondsSinceEpoch;

      final snapshot = await _db.ref('pendingNotifications').get();

      if (!snapshot.exists) {
        print('✅ لا توجد إشعارات للتنظيف');
        return;
      }

      final notifications = snapshot.value as Map<dynamic, dynamic>;
      int deletedCount = 0;

      for (var entry in notifications.entries) {
        final notificationId = entry.key.toString();
        final data = Map<String, dynamic>.from(entry.value);

        final createdAt = data['createdAt'] ?? 0;
        final status = data['status'] ?? 'pending';

        // ✅ حذف الإشعارات القديمة أو الناجحة أو الفاشلة
        if (createdAt < cutoffTime ||
            status == 'sent' ||
            (status == 'failed' && createdAt < cutoffTime)) {
          await _db.ref('pendingNotifications').child(notificationId).remove();
          deletedCount++;
        }
      }

      print('✅ تم حذف $deletedCount إشعار قديم');
    } catch (e) {
      print('❌ خطأ في تنظيف الإشعارات القديمة: $e');
    }
  }

  void stopMonitoring() {
    _connectionSubscription?.cancel();
    _processingIds.clear();
    print('🛑 تم إيقاف مراقبة الإشعارات المعلقة');
  }
}