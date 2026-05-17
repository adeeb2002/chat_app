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

  /// تهيئة معالج الإشعارات
  void initialize() {
    print('🔔 تهيئة معالج الإشعارات...');

    // الاستماع للنقر على الإشعار (التطبيق مغلق أو في الخلفية)
    OneSignal.Notifications.addClickListener(_handleNotificationClick);

    // الاستماع للإشعارات الواردة (التطبيق مفتوح)
    //OneSignal.Notifications.addForegroundWillDisplayListener(_handleForegroundNotification);

    print('✅ تم تهيئة معالج الإشعارات');
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
    // استبدل بالمسار الصحيح لصفحة المحادثة
    Navigator.of(context).pushNamed('/chat', arguments: {'chatId': chatId});
   // Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(chat: chat, receiverEmail: receiverEmail)))
  }

  /// فتح صفحة طلبات الصداقة
  void _navigateToFriendRequests(BuildContext context) {
    print('👥 فتح طلبات الصداقة');
    Navigator.of(context).pushNamed('/friend-requests');
  }

  /// فتح صفحة ملف المستخدم
  void _navigateToUserProfile(BuildContext context, String userId) {
    print('👤 فتح ملف المستخدم: $userId');
    Navigator.of(context).pushNamed('/profile', arguments: {'userId': userId});
  }

  /// فتح صفحة المجموعة
  void _navigateToGroup(BuildContext context, String groupId) {
    print('👥 فتح المجموعة: $groupId');
    Navigator.of(context).pushNamed('/group', arguments: {'groupId': groupId});
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