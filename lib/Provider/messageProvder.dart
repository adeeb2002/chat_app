import 'dart:async';
import 'dart:convert';
import 'package:ChatApp/Provider/userProvide.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

import '../Notifications/CacheService.dart';
import '../Notifications/PendingNotificationsService.dart';
import '../Notifications/notifications.dart';
import '../model/Message.dart';

final firebaseDatabaseProvider = Provider<FirebaseDatabase>((ref) {
  return FirebaseDatabase.instance;
});

final messageServiceProvider = Provider<MessageService>((ref) {
  final db = ref.watch(firebaseDatabaseProvider);
  return MessageService(db);
});

final messagesProvider = StreamProvider.family<List<Message>, String>((ref, chatId) {
  final db = FirebaseDatabase.instance;
  final cacheService = AdvancedCacheService();
  final currentUserPhone = ref.watch(appUserPhoneProvider);

  final controller = StreamController<List<Message>>.broadcast();

  // ✅ 1. عرض الرسائل المخزنة محلياً فوراً
  Future.delayed(Duration.zero, () async {
    final cachedMessages = await _loadCachedMessages(chatId);
    if (cachedMessages.isNotEmpty && !controller.isClosed) {
      print('📱 عرض ${cachedMessages.length} رسالة من الكاش المحلي للمحادثة $chatId');
      controller.add(cachedMessages);
    }
  });

  // ✅ 2. إذا كان هناك اتصال، استمع للرسائل الجديدة
  final isOnline = cacheService.isOnline;

  if (isOnline) {
    final listener = db.ref('chats').child(chatId).child('messages').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};

      final messages = data.entries.map((entry) {
        return Message.fromMap(entry.value as Map<dynamic, dynamic>);
      }).toList();

      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // ✅ حفظ في الكاش
      _saveMessagesToCache(chatId, messages);

      if (!controller.isClosed) {
        controller.add(messages);
      }
    });

    ref.onDispose(() {
      listener.cancel();
      controller.close();
    });
  } else {
    // ✅ إذا كان أوفلاين، أغلق الـ Stream بعد عرض الكاش
    print('⚠️ وضع الأوفلاين - عرض الرسائل المخزنة فقط للمحادثة $chatId');
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!controller.isClosed) {
        controller.close();
      }
    });
  }

  return controller.stream;
});

// ✅ دالة لجلب الرسائل من الكاش
Future<List<Message>> _loadCachedMessages(String chatId) async {
  try {
    final cacheService = AdvancedCacheService();
    return await cacheService.getCachedMessages(chatId);
  } catch (e) {
    print('❌ خطأ في جلب الرسائل من الكاش: $e');
    return [];
  }
}

// ✅ دالة لحفظ الرسائل في الكاش
Future<void> _saveMessagesToCache(String chatId, List<Message> messages) async {
  try {
    final cacheService = AdvancedCacheService();
    await cacheService.saveMessages(chatId, messages);
  } catch (e) {
    print('❌ خطأ في حفظ الرسائل في الكاش: $e');
  }
}

void _markUnreadMessages(
    FirebaseDatabase db,
    String chatId,
    String currentUserPhone,
    List<Message> messages,
    ) {
  final unreadMessages = messages.where((msg) =>
  msg.resevUser == currentUserPhone && !msg.isRead
  ).toList();

  if (unreadMessages.isNotEmpty) {
    final messagesRef = db.ref('chats').child(chatId).child('messages');
    for (var message in unreadMessages) {
      messagesRef.child(message.id).update({'isRead': true});
    }
  }
}

final currentUserPhoneProvider = StateProvider<String?>((ref) => null);

class MessageService {
  final FirebaseDatabase db;

  MessageService(this.db);


  Future<void> sendMessage(Message message,String messageId) async {
    if (!message.isValid) {
      throw Exception('بيانات الرسالة غير صالحة');
    }

    try {



      // 1️⃣ أولاً: رفع الرسالة الجديدة داخل عقدة الـ messages
      final chatRef = db.ref('chats').child(message.chatId).child('messages');
      final newMessageRef = chatRef.push();

      final messageWithId = message.toMap();
      messageWithId['id'] = newMessageRef.key;

      await newMessageRef.set(messageWithId);

      // 2️⃣ ثانياً: تنظيف رقم هاتف المستقبل لتحديث العداد الخاص به
      // (لأن الرسائل غير المقروءة تزيد عند الشخص الذي يستقبل الرسالة وليس المرسل)
      final String receiverCleanKey = message.resevUser.replaceAll('+', 'p');

      // 3️⃣ ثالثاً: استخدام Transaction لتحديث بيانات المحادثة وزيادة العداد بأمان
      final chatMainRef = db.ref('chats').child(message.chatId);

      await chatMainRef.runTransaction((Object? chatData) {
        if (chatData == null) {
          return Transaction.abort();
        }

        // تحويل البيانات الحالية للمحادثة إلى Map للتعديل عليها
        final Map<String, dynamic> chatMap = Map<String, dynamic>.from(chatData as Map);

        // تحديث البيانات الأساسية لآخر رسالة
        chatMap['lastMessage'] = message.body;
        chatMap['lastMessageTime'] = message.timestamp;
        chatMap['lastMessageSender'] = message.senderUser;
        chatMap['updatedAt'] = message.timestamp;

        // تهيئة خريطة العدادات إذا لم تكن موجودة مسبقاً
        if (chatMap['unreadCount'] == null) {
          chatMap['unreadCount'] = <String, dynamic>{};
        }

        final Map<String, dynamic> unreadMap = Map<String, dynamic>.from(chatMap['unreadCount']);

        // جلب العداد الحالي للمستقبل وزيادته بـ 1
        final int currentUnread = unreadMap[receiverCleanKey] ?? 0;
        unreadMap[receiverCleanKey] = currentUnread + 1;

        // إعادة تعيين الخريطة المحدثة داخل بيانات المحادثة
        chatMap['unreadCount'] = unreadMap;

        // إرجاع البيانات المحدثة ليتم حفظها في Firebase
        return Transaction.success(chatMap);
      });

      // 4. فحص الاتصال
      print('🔍 فحص حالة الاتصال...');
      bool isConnected = false;
      try {
        isConnected = await InternetConnection().hasInternetAccess.timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            print('⏱️ انتهت مهلة فحص الاتصال');
            return false;
          },
        );
        print('🌐 حالة الاتصال: ${isConnected ? "متصل" : "غير متصل"}');
      } catch (e) {
        print('❌ خطأ في فحص الاتصال: $e');
        isConnected = false;
      }

      if (isConnected) {
        print('📤 محاولة إرسال الإشعار فوراً...');
        try {
          print('🎯 المستلم: ${message.resevUser}');

          final success = await NotificationService().sendMessageNotification(
            targetPhone: message.resevUser,
            senderName: message.senderUser,
            messageBody: message.body,
            chatId: message.chatId,
            messageId: messageId,
          );


          print('success $success');

          if (success) {
            print('✅✅✅ تم إرسال الإشعار بنجاح ✅✅✅');
          } else {
            print('⚠️ فشل إرسال الإشعار، إضافة للقائمة...');
            await _addToPendingQueue(message, messageId);
          }


        } catch (e) {
          print('❌ خطأ في إرسال الإشعار: $e');
          print('📝 إضافة الإشعار إلى قائمة الانتظار...');
          await _addToPendingQueue(message, messageId);
        }
      } else {
        print('📵 لا يوجد اتصال، إضافة الإشعار إلى قائمة الانتظار...');
        await _addToPendingQueue(message, messageId);
      }

      print('✅ تم إرسال الرسالة وزيادة عداد الرسائل غير المقروءة للمستقبل');
    } catch (e) {
      print('❌ خطأ في إرسال الرسالة وتحديث العداد: $e');
      rethrow;
    }
  }

  // ✅ إضافة الإشعار إلى قائمة الانتظار
  Future<void> _addToPendingQueue(Message message, String messageId) async {
    try {
      print('📋 إضافة الإشعار إلى قائمة الانتظار...');
      await PendingNotificationsService().addPendingNotification(
        chatId: message.chatId,
        messageId: messageId,
        senderPhone: message.senderUser,
        receiverPhone: message.resevUser,
        messageBody: message.body,
        timestamp: message.timestamp,
      );
      print('✅ تم إضافة الإشعار إلى القائمة بنجاح');
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
      final messageRef = db
          .ref('chats')
          .child(chatId)
          .child('messages')
          .child(messageId);

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

      final chatRef = db.ref('chats').child(chatId);
      final chatSnapshot = await chatRef.get();
      final lastMessageId = chatSnapshot.child('lastMessageId').value;

      if (lastMessageId == messageId) {
        await chatRef.update({
          'lastMessage': newBody,
          'lastMessageTime': now,
        });
      }

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
      final messageRef = db
          .ref('chats')
          .child(chatId)
          .child('messages')
          .child(messageId);

      if (forEveryone) {
        await messageRef.update({
          'isDeleted': true,
          'body': 'تم حذف هذه الرسالة',
          'deletedAt': DateTime.now().millisecondsSinceEpoch,
        });
        print('✅ تم حذف الرسالة للجميع');
      } else {
        await messageRef.update({
          'isDeleted': true,
          'deletedAt': DateTime.now().millisecondsSinceEpoch,
        });
        print('✅ تم حذف الرسالة للمستخدم فقط');
      }
    } catch (e) {
      print('❌ خطأ في حذف الرسالة: $e');
      rethrow;
    }
  }

  Future<void> markMessagesAsRead(String chatId, String userPhone) async {
    try {
      final chatRef= db.ref('chats').child(chatId);
      final messagesRef = db.ref('chats').child(chatId).child('messages');
      final snapshot = await messagesRef.get();

      if (!snapshot.exists) return;

      final messages = snapshot.value as Map<dynamic, dynamic>? ?? {};
      final updates = <String, dynamic>{};

      messages.forEach((key, value) {
        final messageData = Map<String, dynamic>.from(value);
        if (messageData['resevUser'] == userPhone &&
            messageData['isRead'] != true) {
          updates['$key/isRead'] = true;
        }
      });

      if (updates.isNotEmpty) {
        await messagesRef.update(updates);
      }


      // تصفير عداد الرسائل غير المقروءة لهذا المستخدم بالتحديد في السيرفر
      final cleanUserPhone = userPhone.replaceAll('+', '_p_');
      await chatRef.child('unreadCount').child(cleanUserPhone).set(0);


    } catch (e) {
      print('❌ خطأ في تحديث حالة القراءة: $e');
    }
  }
}