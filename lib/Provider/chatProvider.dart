// lib/Provider/chatProvider.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../model/chat.dart';
import '../model/Message.dart';
import '../Notifications/CacheService.dart';
import '../Notifications/PendingNotificationsService.dart';
import '../Notifications/notifications.dart';

final firebaseDatabaseProvider = Provider<FirebaseDatabase>((ref) {
  return FirebaseDatabase.instance;
});

final chatServiceProvider = Provider<ChatService>((ref) {
  final db = ref.watch(firebaseDatabaseProvider);
  return ChatService(db);
});

final chatBlockStatusProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, chatId) {
  final db = ref.watch(firebaseDatabaseProvider);

  final controller = StreamController<Map<String, dynamic>?>.broadcast();

  final listener = db.ref('chats').child(chatId).onValue.listen((event) {
    final data = event.snapshot.value as Map<dynamic, dynamic>?;
    if (data == null) {
      controller.add(null);
      return;
    }

    controller.add({
      'isBlocked': data['isBlocked'] ?? false,
      'blockedBy': data['blockedBy'],
      'blockedAt': data['blockedAt'],
    });
  });

  ref.onDispose(() {
    listener.cancel();
    controller.close();
  });

  return controller.stream;
});

final chatsProvider = StreamProvider.family<List<Chat>, String>((ref, userPhone) {
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('🔍 [chatsProvider] بدء الاستماع للمحادثات');
  print('📱 رقم المستخدم الحالي: $userPhone');

  final db = ref.watch(firebaseDatabaseProvider);
  final cacheService = AdvancedCacheService();

  final controller = StreamController<List<Chat>>.broadcast();

  // ✅ عرض البيانات من الكاش فوراً
  Future.delayed(Duration.zero, () async {
    print('📦 [chatsProvider] فحص الكاش المحلي...');
    final hasCache = cacheService.hasCachedData();
    print('📦 هل يوجد كاش؟ $hasCache');

    if (hasCache) {
      final cachedChats = cacheService.getCachedChats();
      print('📦 عدد المحادثات في الكاش: ${cachedChats.length}');
      if (cachedChats.isNotEmpty) {
        print('📱 عرض ${cachedChats.length} محادثة من الكاش المحلي');
        controller.add(cachedChats);
      } else {
        print('⚠️ الكاش موجود لكنه فارغ');
      }
    } else {
      print('⚠️ لا يوجد كاش محلي');
    }
  });

  // ✅ الاستماع للتغييرات من Firebase
  print('🔥 [chatsProvider] الاستماع إلى Firebase...');
  final listener = db.ref('chats').onValue.listen((event) {
    final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
    final List<Chat> chats = [];

    print('🔥 عدد المحادثات في Firebase: ${data.length}');

    data.forEach((chatId, chatData) {
      final chatMap = Map<String, dynamic>.from(chatData);
      final participants = List<String>.from(chatMap['participants'] ?? []);
      final deletedFor = Map<String, dynamic>.from(chatMap['deletedFor'] ?? {});
      final clearedFor = Map<String, dynamic>.from(chatMap['clearedFor'] ?? {});

      print('🔍 محادثة $chatId:');
      print('   - المشاركون: $participants');
      print('   - المحذوفة للمستخدم: ${deletedFor.containsKey(userPhone)}');

      if (participants.contains(userPhone) && !deletedFor.containsKey(userPhone)) {
        final chat = Chat(
          id: chatId.toString(),
          participants: participants,
          lastMessage: chatMap['lastMessage'] ?? '',
          lastMessageTime: chatMap['lastMessageTime'] ?? 0,
          lastMessageSender: chatMap['lastMessageSender'] ?? '',
          createdAt: chatMap['createdAt'] ?? 0,
          updatedAt: chatMap['updatedAt'] ?? 0,
          deletedFor: deletedFor,
          clearedFor: clearedFor,
          isBlocked: chatMap['isBlocked'] ?? false,
          blockedBy: chatMap['blockedBy'],
          isDeletedChatForYou: deletedFor.containsKey(userPhone),
          unreadCount: chatMap['unreadCount'] is Map
              ? Map<String, dynamic>.from(chatMap['unreadCount'])
              : (chatMap['unreadCount'] ?? 0),
        );

        chats.add(chat);
        print('   ✅ تم إضافة المحادثة');

        // ✅ حفظ المحادثة في الكاش
        cacheService.cacheSingleChat(chat);
      } else {
        print('   ❌ لم يتم إضافة المحادثة (المستخدم ليس مشاركاً أو محذوفة)');
      }
    });

    chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    print('📊 عدد المحادثات بعد التصفية: ${chats.length}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    controller.add(chats);
  });

  ref.onDispose(() {
    listener.cancel();
    controller.close();
  });

  return controller.stream;
});

class ChatService {
  final FirebaseDatabase db;

  ChatService(this.db);

  String _cleanPhone(String phone) {
    return phone
        .replaceAll('+', 'p')
        .replaceAll('@', '_at_')
        .replaceAll('.', '_dot_');
  }

  String _generateChatId(String phone1, String phone2) {
    final List<String> phones = [phone1, phone2]..sort();
    final String clean1 = _cleanPhone(phones[0]);
    final String clean2 = _cleanPhone(phones[1]);
    return '${clean1}_$clean2';
  }

  Future<String> createChat({
    required String user1Phone,
    required String user2Phone,
    String? initialMessage,
  }) async {
    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📝 إنشاء محادثة جديدة');
      print('📱 المستخدم 1: $user1Phone');
      print('📱 المستخدم 2: $user2Phone');

      if (user1Phone.isEmpty || user2Phone.isEmpty) {
        throw Exception('رقم الهاتف لا يمكن أن يكون فارغاً');
      }

      final chatId = _generateChatId(user1Phone, user2Phone);
      print('🆔 معرف المحادثة: $chatId');

      final chatRef = db.ref('chats').child(chatId);
      final snapshot = await chatRef.get();

      if (snapshot.exists) {
        print('⚠️ المحادثة موجودة مسبقاً');
        final chatData = snapshot.value as Map<dynamic, dynamic>?;
        final deletedFor = Map<String, dynamic>.from(chatData?['deletedFor'] ?? {});

        if (deletedFor.containsKey(user1Phone)) {
          deletedFor.remove(user1Phone);
          await chatRef.update({
            'deletedFor': deletedFor,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          });
          print('✅ تم استعادة المحادثة للمستخدم $user1Phone');
        }

        print('✅ المحادثة موجودة مسبقاً: $chatId');
        return chatId;
      }

      final now = DateTime.now().millisecondsSinceEpoch;

      await chatRef.set({
        'participants': [user1Phone, user2Phone],
        'createdAt': now,
        'updatedAt': now,
        'lastMessage': initialMessage ?? '',
        'lastMessageTime': now,
        'lastMessageSender': user1Phone,
        'deletedFor': {},
        'clearedFor': {},
        'isBlocked': false,
        'blockedBy': null,
        'unreadCount': {},
      });

      print('✅ تم إنشاء المحادثة بنجاح: $chatId');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return chatId;
    } catch (e) {
      print('❌ خطأ في إنشاء المحادثة: $e');
      throw Exception('فشل إنشاء المحادثة: ${e.toString()}');
    }
  }

  Future<void> blockUser(String chatId, String myPhone) async {
    try {
      final chatRef = db.ref('chats').child(chatId);
      await chatRef.update({
        'isBlocked': true,
        'blockedBy': myPhone,
        'blockedAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      print('✅ تم حظر المستخدم بواسطة $myPhone');
    } catch (e) {
      print('❌ خطأ في حظر المستخدم: $e');
      rethrow;
    }
  }

  Future<void> unblockUser(String chatId, String myPhone) async {
    try {
      final chatRef = db.ref('chats').child(chatId);
      await chatRef.update({
        'isBlocked': false,
        'blockedBy': null,
        'unblockedAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      print('✅ تم إلغاء حظر المستخدم بواسطة $myPhone');
    } catch (e) {
      print('❌ خطأ في إلغاء حظر المستخدم: $e');
      rethrow;
    }
  }

  Future<bool> isChatDeletedForUser(String chatId, String userPhone) async {
    try {
      final snapshot = await db
          .ref('chats')
          .child(chatId)
          .child('deletedFor')
          .child(userPhone)
          .get();
      return snapshot.exists;
    } catch (e) {
      print('❌ خطأ في التحقق من حالة الحذف: $e');
      return false;
    }
  }

  Future<void> clearChat(String chatId) async {
    try {
      final chatRef = db.ref('chats').child(chatId);
      final snapshot = await chatRef.get();

      if (!snapshot.exists) {
        throw Exception('المحادثة غير موجودة');
      }

      final messagesRef = chatRef.child('messages');
      await messagesRef.remove();

      final now = DateTime.now().millisecondsSinceEpoch;
      await chatRef.update({
        'lastMessage': '',
        'lastMessageTime': now,
        'lastMessageSender': '',
        'updatedAt': now,
        'clearedAt': now,
      });

      print('✅ تم مسح جميع رسائل المحادثة: $chatId');
    } catch (e) {
      print('❌ خطأ في مسح رسائل المحادثة: $e');
      rethrow;
    }
  }

  Future<void> deleteChatForUser(String chatId, String userPhone) async {
    try {
      final chatRef = db.ref('chats').child(chatId);
      final snapshot = await chatRef.get();

      if (!snapshot.exists) {
        throw Exception('المحادثة غير موجودة');
      }

      final chatData = snapshot.value as Map<dynamic, dynamic>?;
      if (chatData == null) {
        throw Exception('بيانات المحادثة غير صالحة');
      }

      final deletedFor = Map<String, dynamic>.from(chatData['deletedFor'] ?? {});
      deletedFor[userPhone] = DateTime.now().millisecondsSinceEpoch;

      await chatRef.update({
        'deletedFor': deletedFor,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      print('✅ تم حذف المحادثة بنجاح للمستخدم $userPhone');
    } catch (e) {
      print('❌ خطأ في حذف المحادثة للمستخدم: $e');
      rethrow;
    }
  }

  Future<void> restoreDeletedChat(String chatId, String userPhone) async {
    try {
      final chatRef = db.ref('chats').child(chatId);
      final snapshot = await chatRef.get();

      if (!snapshot.exists) {
        throw Exception('المحادثة غير موجودة');
      }

      final chatData = snapshot.value as Map<dynamic, dynamic>?;
      if (chatData == null) {
        throw Exception('بيانات المحادثة غير صالحة');
      }

      final deletedFor = Map<String, dynamic>.from(chatData['deletedFor'] ?? {});

      if (deletedFor.containsKey(userPhone)) {
        deletedFor.remove(userPhone);
        await chatRef.update({
          'deletedFor': deletedFor,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
        print('✅ تم استعادة المحادثة للمستخدم $userPhone');
      }
    } catch (e) {
      print('❌ خطأ في استعادة المحادثة: $e');
      rethrow;
    }
  }

  String extractPhoneFromChatId(String chatId, String currentUserPhone) {
    final parts = chatId.split('_');
    for (var part in parts) {
      try {
        String restored = part
            .replaceAll('p', '+')
            .replaceAll('_at_', '@')
            .replaceAll('_dot_', '.');

        if (restored != currentUserPhone && restored.isNotEmpty) {
          return restored;
        }
      } catch (e) {
        continue;
      }
    }
    return '';
  }
}