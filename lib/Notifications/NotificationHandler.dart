// lib/services/notifications/notification_handler.dart

import 'package:ChatApp/Screen/chatScreen.dart';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../model/NotificationType.dart';

class NotificationHandler {
  static final NotificationHandler _instance = NotificationHandler._internal();
  factory NotificationHandler() => _instance;
  NotificationHandler._internal();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  bool _isInitialized = false;

  /// تهيئة معالج الإشعارات
  void initialize() {
    if (_isInitialized) {
      print('⚠️ معالج الإشعارات مهيأ مسبقاً');
      return;
    }

    print('🔔 تهيئة معالج الإشعارات...');

    try {
      // الاستماع للنقر على الإشعار
      OneSignal.Notifications.addClickListener(_handleNotificationClick);

      // الاستماع للإشعارات الواردة
      OneSignal.Notifications.addForegroundWillDisplayListener(_handleForegroundNotification);

      _isInitialized = true;
      print('✅ تم تهيئة معالج الإشعارات');
    } catch (e) {
      print('❌ خطأ في تهيئة معالج الإشعارات: $e');
    }
  }

  /// تنظيف الموارد
  void dispose() {
    print('🔴 تنظيف معالج الإشعارات...');
    _isInitialized = false;
  }

  /// معالجة النقر على الإشعار
  void _handleNotificationClick(OSNotificationClickEvent event) {
    print('👆 تم النقر على الإشعار');

    try {
      final additionalData = event.notification.additionalData ?? {};
      print('📦 البيانات المرفقة: $additionalData');

      final payload = NotificationPayload.fromOSNotification(additionalData);
      _navigateBasedOnType(payload);
    } catch (e) {
      print('❌ خطأ في معالجة النقر: $e');
    }
  }

  /// معالجة الإشعار في المقدمة (عرض مخصص)
  void _handleForegroundNotification(OSNotificationWillDisplayEvent event) {
    print('📱 إشعار وارد في المقدمة: ${event.notification.title}');

    try {
      final additionalData = event.notification.additionalData ?? {};
      final payload = NotificationPayload.fromOSNotification(additionalData);

      // عرض الإشعار داخل التطبيق (اختياري)
      //_showInAppNotification(payload);

      // السماح بعرض الإشعار الأصلي
      event.notification.display();
    } catch (e) {
      print('❌ خطأ في معالجة الإشعار الوارد: $e');
    }
  }

  /// التوجيه حسب نوع الإشعار
  void _navigateBasedOnType(NotificationPayload payload) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      print('⚠️ لا يوجد Context للتنقل');
      return;
    }

    switch (payload.type) {
      case NotificationType.message:
      case NotificationType.messageReply:
      case NotificationType.mention:
        if (payload.chatId != null) {
          _navigateToChat(context, payload.chatId!);
        }
        break;

      case NotificationType.friendRequest:
        _navigateToFriendRequests(context);
        break;

      case NotificationType.friendAccepted:
        if (payload.senderId != null) {
          _navigateToUserProfile(context, payload.senderId!);
        }
        break;

      case NotificationType.groupInvite:
        if (payload.groupId != null) {
          _navigateToGroup(context, payload.groupId!);
        }
        break;
    }
  }

  /// فتح صفحة المحادثة
  void _navigateToChat(BuildContext context, String chatId) {
    print('💬 فتح المحادثة: $chatId');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم فتح المحادثة $chatId')),
    );
  }

  /// فتح صفحة طلبات الصداقة
  void _navigateToFriendRequests(BuildContext context) {
    print('👥 فتح طلبات الصداقة');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('طلبات الصداقة قيد التطوير')),
    );
  }

  /// فتح صفحة ملف المستخدم
  void _navigateToUserProfile(BuildContext context, String userId) {
    print('👤 فتح ملف المستخدم: $userId');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ملف المستخدم $userId قيد التطوير')),
    );
  }

  /// فتح صفحة المجموعة
  void _navigateToGroup(BuildContext context, String groupId) {
    print('👥 فتح المجموعة: $groupId');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('المجموعة $groupId قيد التطوير')),
    );
  }

  /// عرض إشعار داخل التطبيق (Banner أو SnackBar)
 /* void _showInAppNotification(NotificationPayload payload) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              payload.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(payload.body),
          ],
        ),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'فتح',
          onPressed: () => _navigateBasedOnType(payload),
        ),
      ),
    );
  }*/
}