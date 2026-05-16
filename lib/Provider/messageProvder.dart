import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

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
  final db = ref.watch(firebaseDatabaseProvider);
  final currentUserEmail = ref.watch(currentUserEmailProvider);

  return db.ref('chats').child(chatId).child('messages').limitToLast(50).onValue.map((event) {
    final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};

    final messages = data.entries.map((entry) {
      return Message.fromMap(entry.value as Map<dynamic, dynamic>);
    }).toList();

    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (currentUserEmail != null && messages.isNotEmpty) {
      _markUnreadMessages(db, chatId, currentUserEmail, messages);
    }

    return messages;
  });
});

void _markUnreadMessages(
    FirebaseDatabase db,
    String chatId,
    String currentUserEmail,
    List<Message> messages,
    ) {
  final unreadMessages = messages.where((msg) =>
  msg.resevUser == currentUserEmail && !msg.isRead
  ).toList();

  if (unreadMessages.isNotEmpty) {
    final messagesRef = db.ref('chats').child(chatId).child('messages');
    for (var message in unreadMessages) {
      messagesRef.child(message.id).update({'isRead': true});
    }
  }
}

final currentUserEmailProvider = StateProvider<String?>((ref) => null);

class MessageService {
  final FirebaseDatabase db;

  MessageService(this.db);

  Future<void> sendMassege(Message massege) async {
    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📨 بدء إرسال الرسالة...');
      print('Sender: ${massege.senderUser}');
      print('Receiver: ${massege.resevUser}');
      print('Body: ${massege.body}');

      // 1. إنشاء مرجع جديد للرسالة
      final chatRef = db.ref('chats').child(massege.chatId).child('messages');
      final newMessageRef = chatRef.push();
      final messageId = newMessageRef.key!;

      print('Message ID: $messageId');

      final messageWithId = massege.copyWith(id: messageId);

      // 2. حفظ الرسالة في Firebase
      await newMessageRef.set(messageWithId.toMap());
      print('✅ تم حفظ الرسالة في Firebase');

      // 3. تحديث آخر رسالة في المحادثة
      await db.ref('chats').child(massege.chatId).update({
        'lastMessage': massege.body,
        'lastMessageTime': massege.timestamp,
        'lastMessageSender': massege.senderUser,
        'lastMessageId': messageId,
      });
      print('✅ تم تحديث آخر رسالة في المحادثة');

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
          final senderName = massege.senderUser.split('@').first;

          print('🎯 المستلم: ${massege.resevUser}');
          print('👤 المرسل: $senderName');

          final success = await NotificationService().sendMessageNotification(
            targetEmail: massege.resevUser,
            senderName: senderName,
            messageBody: massege.body,
            chatId: massege.chatId,
            messageId: messageId,
          );

          if (success) {
            print('✅✅✅ تم إرسال الإشعار بنجاح ✅✅✅');
          } else {
            print('⚠️ فشل إرسال الإشعار، إضافة للقائمة...');
            await _addToPendingQueue(massege, messageId);
          }
        } catch (e) {
          print('❌ خطأ في إرسال الإشعار: $e');
          print('📝 إضافة الإشعار إلى قائمة الانتظار...');
          await _addToPendingQueue(massege, messageId);
        }
      } else {
        print('📵 لا يوجد اتصال، إضافة الإشعار إلى قائمة الانتظار...');
        await _addToPendingQueue(massege, messageId);
      }

      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    } catch (e) {
      print('❌❌❌ خطأ فادح في معالجة الرسالة: $e');
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
        senderEmail: message.senderUser,
        receiverEmail: message.resevUser,
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

  Future<void> markMessagesAsRead(String chatId, String userEmail) async {
    try {
      final messagesRef = db.ref('chats').child(chatId).child('messages');
      final snapshot = await messagesRef.get();

      if (!snapshot.exists) return;

      final messages = snapshot.value as Map<dynamic, dynamic>? ?? {};
      final updates = <String, dynamic>{};

      messages.forEach((key, value) {
        final messageData = Map<String, dynamic>.from(value);
        if (messageData['resevUser'] == userEmail &&
            messageData['isRead'] != true) {
          updates['$key/isRead'] = true;
        }
      });

      if (updates.isNotEmpty) {
        await messagesRef.update(updates);
      }

    } catch (e) {
      print('❌ خطأ في تحديث حالة القراءة: $e');
    }
  }
}