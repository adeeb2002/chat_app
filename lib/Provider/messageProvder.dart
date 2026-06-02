// lib/Provider/messageProvider.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../Notifications/CacheService.dart';
import '../Notifications/PendingNotificationsService.dart';
import '../Notifications/notifications.dart';
import '../model/Message.dart';
import '../service/NetworkOptimizationService.dart';

final messageDatabaseProvider = Provider<FirebaseDatabase>((ref) {
  return FirebaseDatabase.instance;
});

final messageServiceProvider = Provider<MessageService>((ref) {
  final db = ref.watch(messageDatabaseProvider);
  return MessageService(db);
});

final messagesProvider = StreamProvider.family<List<Message>, String>((ref, chatId) {
  final db = FirebaseDatabase.instance;
  final cacheService = AdvancedCacheService();

  final controller = StreamController<List<Message>>.broadcast();

  // ✅ عرض الرسائل المخزنة محلياً فوراً
  Future.delayed(Duration.zero, () async {
    final cachedMessages = await cacheService.getCachedMessages(chatId);
    if (cachedMessages.isNotEmpty && !controller.isClosed) {
      print('📱 عرض ${cachedMessages.length} رسالة من الكاش المحلي للمحادثة $chatId');
      controller.add(cachedMessages);
    }
  });

  // ✅ الاستماع للرسائل الجديدة من Firebase
  final listener = db.ref('chats').child(chatId).child('messages').onValue.listen((event) {
    try {
      final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};

      final messages = data.entries.map((entry) {
        if (entry.value is! Map) return null;
        return Message.fromMap(entry.value as Map<dynamic, dynamic>);
      }).whereType<Message>().toList();

      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // ✅ حفظ في الكاش
      cacheService.saveMessages(chatId, messages);

      if (!controller.isClosed) {
        controller.add(messages);
      }
    } catch (e) {
      print('❌ خطأ في معالجة الرسائل: $e');
    }
  }, onError: (error) {
    print('❌ خطأ في استماع Firebase: $error');
  });

  ref.onDispose(() {
    listener.cancel();
    controller.close();
  });

  return controller.stream;
});

class MessageService {
  final FirebaseDatabase db;

  MessageService(this.db);

  Future<void> sendMessage(Message message, String messageId) async {
    if (!message.isValid) {
      throw Exception('بيانات الرسالة غير صالحة');
    }

    final networkService = NetworkOptimizationService();

    try {
      final chatRef = db.ref('chats').child(message.chatId).child('messages');
      final newMessageRef = chatRef.child(messageId);

      final messageData = message.toJson();
      messageData['id'] = messageId;

      // ✅ استخدام NetworkOptimizationService
      await networkService.executeRequest(
            () => newMessageRef.set(messageData),
        debugName: 'sendMessage_$messageId',
        priority: true, // أولوية عالية للإرسال
      );

      // ✅ تحديث المحادثة
      final chatMainRef = db.ref('chats').child(message.chatId);
      final receiverCleanKey = message.resevUser.replaceAll('+', 'p');

      await networkService.executeRequest(
            () => chatMainRef.runTransaction((Object? chatData) {
          if (chatData == null) return Transaction.abort();

          final Map<String, dynamic> chatMap = Map<String, dynamic>.from(chatData as Map);

          chatMap['lastMessage'] = message.type == MessageType.image ? '📷 صورة' : message.body;
          chatMap['lastMessageTime'] = message.timestamp;
          chatMap['lastMessageSender'] = message.senderUser;
          chatMap['updatedAt'] = message.timestamp;

          if (chatMap['unreadCount'] == null) {
            chatMap['unreadCount'] = <String, dynamic>{};
          }

          final Map<String, dynamic> unreadMap = Map<String, dynamic>.from(chatMap['unreadCount']);
          final int currentUnread = unreadMap[receiverCleanKey] ?? 0;
          unreadMap[receiverCleanKey] = currentUnread + 1;
          chatMap['unreadCount'] = unreadMap;

          return Transaction.success(chatMap);
        }),
        debugName: 'updateChat_${message.chatId}',
        priority: false, // أولوية منخفضة للتحديث
      );

      final notificationBody = message.type == MessageType.image ? '📷 صورة' : message.body;

      // ✅ إرسال الإشعار (فقط إذا الاتصال جيد)
      if (networkService.isConnected && !networkService.isSlowConnection) {
        final success = await NotificationService().sendMessageNotification(
          targetPhone: message.resevUser,
          senderName: message.senderUser,
          messageBody: notificationBody,
          chatId: message.chatId,
          messageId: messageId,
        );

        if (!success) {
          await _addToPendingQueue(message, messageId, notificationBody);
        }
      } else {
        await _addToPendingQueue(message, messageId, notificationBody);
      }

      print('✅ تم إرسال الرسالة بنجاح');
    } catch (e) {
      print('❌ خطأ في إرسال الرسالة: $e');
      rethrow;
    }
  }

  Future<void> _addToPendingQueue(Message message, String messageId, String notificationBody) async {
    try {
      await PendingNotificationsService().addPendingNotification(
        chatId: message.chatId,
        messageId: messageId,
        senderPhone: message.senderUser,
        receiverPhone: message.resevUser,
        messageBody: notificationBody, // ✅ استخدام النص المعدل
        timestamp: message.timestamp,
      );
      print('✅ تم إضافة الإشعار إلى قائمة الانتظار');
    } catch (e) {
      print('❌ فشل إضافة الإشعار إلى القائمة: $e');
    }
  }

  Future<void> editMessage({
    required String chatId,
    required String messageId,
    required String newBody,
  }) async {
    try {
      final messageRef = db.ref('chats').child(chatId).child('messages').child(messageId);
      final snapshot = await messageRef.get();

      if (!snapshot.exists) {
        throw Exception('الرسالة غير موجودة');
      }

      final now = DateTime.now().millisecondsSinceEpoch;

      await messageRef.update({
        'body': newBody,
        'editedAt': now,
        'originalBody': snapshot.child('body').value ?? '',
      });

      // ✅ تحديث آخر رسالة في المحادثة إذا كانت هذه هي آخر رسالة
      final chatRef = db.ref('chats').child(chatId);
      final chatSnapshot = await chatRef.get();
      final lastMessage = chatSnapshot.child('lastMessage').value;

      if (lastMessage == snapshot.child('body').value) {
        await chatRef.update({
          'lastMessage': newBody,
          'lastMessageTime': now,
        });
      }

      // ✅ تحديث الكاش المحلي
      final cacheService = AdvancedCacheService();
      await cacheService.updateMessageInCache(chatId, messageId, newBody, now);

      print('✅ تم تعديل الرسالة بنجاح');
    } catch (e) {
      print('❌ خطأ في تعديل الرسالة: $e');
      rethrow;
    }
  }

  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
    bool forEveryone = false,
  }) async {
    try {
      final messageRef = db.ref('chats').child(chatId).child('messages').child(messageId);

      await messageRef.update({
        'isDeleted': true,
        'body': forEveryone ? 'تم حذف هذه الرسالة' : 'تم حذف الرسالة',
        'deletedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // ✅ تحديث الكاش المحلي
      final cacheService = AdvancedCacheService();
      await cacheService.deleteMessageFromCache(chatId, messageId);

      print('✅ تم حذف الرسالة بنجاح');
    } catch (e) {
      print('❌ خطأ في حذف الرسالة: $e');
      rethrow;
    }
  }

  Future<void> markMessagesAsRead(String chatId, String userPhone) async {
    try {
      final messagesRef = db.ref('chats').child(chatId).child('messages');
      final snapshot = await messagesRef.get();

      if (!snapshot.exists) return;

      final messages = snapshot.value as Map<dynamic, dynamic>? ?? {};
      final updates = <String, dynamic>{};

      messages.forEach((key, value) {
        final messageData = Map<String, dynamic>.from(value);
        if (messageData['resevUser'] == userPhone && messageData['isRead'] != true) {
          updates['$key/isRead'] = true;
        }
      });

      if (updates.isNotEmpty) {
        await messagesRef.update(updates);
      }

      // ✅ تصفير عداد الرسائل غير المقروءة
      final cleanUserPhone = userPhone.replaceAll('+', 'p');
      await db.ref('chats').child(chatId).child('unreadCount').child(cleanUserPhone).set(0);

      print('✅ تم تحديث حالة القراءة بنجاح');
    } catch (e) {
      print('❌ خطأ في تحديث حالة القراءة: $e');
    }
  }
}