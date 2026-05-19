import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Notifications/CacheService.dart';
import '../model/chat.dart';
import '../model/Message.dart';

var unreadCount = 0;

// Provider لقاعدة البيانات
final firebaseDatabaseProvider = Provider<FirebaseDatabase>((ref) {
  return FirebaseDatabase.instance;
});

final unreadCountMessages = StateProvider<int>((ref) {
  return unreadCount;
});

final cacheServiceProvider = Provider<AdvancedCacheService>((ref) {
  return AdvancedCacheService();
});
// Provider لخدمة المحادثات
final chatServiceProvider = Provider<ChatService>((ref) {
  final db = ref.watch(firebaseDatabaseProvider);
  return ChatService(db);
});

// ✅ Provider لمراقبة حالة الحظر في الوقت الفعلي
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

// Stream Provider للمحادثات - نسخة مطورة تدعم إعادة الإحياء التلقائي عند استقبال رسائل جديدة
// ✅ Provider للمحادثات مع دعم الأوفلاين
final chatsProvider = StreamProvider.family<List<Chat>, String>((ref, userPhone) {
  final db = FirebaseDatabase.instance;
  final cacheService = ref.watch(cacheServiceProvider);

  final controller = StreamController<List<Chat>>.broadcast();

  // ✅ 1. عرض البيانات من الكاش فوراً (إذا وجدت)
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (cacheService.hasCachedData()) {
      final cachedChats = cacheService.getCachedChats();
      if (cachedChats.isNotEmpty) {
        print('📱 عرض ${cachedChats.length} محادثة من الكاش المحلي');
        controller.add(cachedChats);
      }
    }
  });

  // ✅ 2. إذا كان هناك اتصال، استمع للتحديثات من Firebase
  if (cacheService.isOnline) {
    final listener = db.ref('chats').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
      final List<Chat> chats = [];

      data.forEach((chatId, chatData) {
        final chatMap = Map<String, dynamic>.from(chatData);
        final participants = List<String>.from(chatMap['participants'] ?? []);
        final deletedFor = Map<String, dynamic>.from(chatMap['deletedFor'] ?? {});

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
            clearedFor: Map<String, dynamic>.from(chatMap['clearedFor'] ?? {}),
            isBlocked: chatMap['isBlocked'] ?? false,
            blockedBy: chatMap['blockedBy'],
            isDeletedChatForYou: deletedFor.containsKey(userPhone),
          );
          chats.add(chat);
        }
      });

      chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      // ✅ حفظ البيانات في الكاش
      cacheService.cacheChats(chats);

      controller.add(chats);
    });

    ref.onDispose(() {
      listener.cancel();
      controller.close();
    });
  } else {
    // ✅ 3. وضع الأوفلاين - اعرض فقط البيانات المخزنة
    print('⚠️ وضع الأوفلاين - عرض البيانات المخزنة فقط');
    controller.close();
  }

  return controller.stream;
});

class ChatService {
  final FirebaseDatabase db;

  ChatService(this.db);

  // تنظيف رقم الهاتف لإنشاء معرف المحادثة بأمان
  String _cleanPhone(String phone){
    return phone.replaceAll('+', 'p');
  }

  // إنشاء معرف محادثة فريد وآمن يعتمد على أرقام الهواتف مرتبة أبجدياً
  String _generateChatId(String phone1, String phone2) {
    final List<String> phones = [phone1, phone2]..sort();
    final String clean1 = _cleanPhone(phones[0]);
    final String clean2 = _cleanPhone(phones[1]);
    return '${clean1}_$clean2';
  }

  // إنشاء محادثة جديدة أو استعادتها إن كانت محذوفة
  Future<String> createChat({
    required String user1Phone,
    required String user2Phone,
    String? initialMessage,
  }) async {
    try {
      if (user1Phone.isEmpty || user2Phone.isEmpty) {
        throw Exception('رقم الهاتف لا يمكن أن يكون فارغاً');
      }
      final dataUser = await db.ref('users').orderByChild('phone').equalTo(user2Phone).get();

      final chatId = _generateChatId(user1Phone, user2Phone);
      final chatRef = db.ref('chats').child(chatId);
      final snapshot = await chatRef.get();

      if (snapshot.exists) {
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
      bool isConnected = false;
      StreamSubscription? connectionSubscription = InternetConnection().onStatusChange.listen((status) {
        isConnected = status == InternetStatus.connected;
      });

      if (dataUser.exists) {
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
          'isSynced': isConnected,
          'unreadCount': {
            _cleanPhone(user1Phone): 0,
            _cleanPhone(user2Phone): 0,
          }
        });

        print('✅ تم إنشاء المحادثة بنجاح: $chatId');
/*
        if (initialMessage != null && initialMessage.isNotEmpty) {
          //final messageService = MessageService(db);
          final message = Message.create(
            senderUser: user1Phone,
            resevUser: user2Phone,
            body: initialMessage,
            chatId: chatId,
            isSynced: isConnected,
          );

          await messageService.sendMessage(message);
        }

 */
      } else {
        Fluttertoast.showToast(msg: 'المستخدم غير موجود في التطبيق');
        return 'noUser';
      }

      return chatId;
    } catch (e) {
      print('❌ خطأ في إنشاء المحادثة: $e');
      throw Exception('فشل إنشاء المحادثة: ${e.toString()}');
    }
  }

  // ✅ دالة لحظر المستخدم
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

  // ✅ دالة لإلغاء حظر المستخدم
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

  // التحقق من حالة حذف المحادثة لمستخدم معين برقم هاتفه
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

  // مسح جميع رسائل المحادثة
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
        'lastMessageId': '',
        'updatedAt': now,
        'clearedAt': now,
      });

      print('✅ تم مسح جميع رسائل المحادثة: $chatId');
    } catch (e) {
      print('❌ خطأ في مسح رسائل المحادثة: $e');
      rethrow;
    }
  }

  // حذف محادثة لمستخدم معين بناءً على رقم هاتفه لضمان الفلترة الصحيحة
  Future<void> deleteChatForUser(String chatId, String userPhone) async {
    try {
      print('🔍 بدء حذف المحادثة للمستخدم: chatId=$chatId, userPhone=$userPhone');

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

  // حذف المحادثة بالكامل من السيرفر لكل الأطراف
  Future<void> deleteChatComplete(String chatId) async {
    try {
      final chatRef = db.ref('chats').child(chatId);
      final snapshot = await chatRef.get();

      if (!snapshot.exists) {
        throw Exception('المحادثة غير موجودة');
      }

      await chatRef.remove();
      print('✅ تم حذف المحادثة بالكامل: $chatId');
    } catch (e) {
      print('❌ خطأ في حذف المحادثة بالكامل: $e');
      rethrow;
    }
  }

  // استعادة محادثة محذوفة لمستخدم معين برقم هاتفه
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

  // ✅ تم التعديل: جلب جميع محادثات المستخدم بناءً على رقم هاتفه (نسخة مستقرة للـ Future)
  Future<List<Chat>> getAllUserChats(String userPhone, {bool includeDeleted = false}) async {
    try {
      final snapshot = await db.ref('chats').get();
      final data = snapshot.value as Map<dynamic, dynamic>? ?? {};
      final List<Chat> chats = [];

      data.forEach((chatId, chatData) {
        final chatMap = Map<String, dynamic>.from(chatData);
        final participants = List<String>.from(chatMap['participants'] ?? []);
        final deletedFor = Map<String, dynamic>.from(chatMap['deletedFor'] ?? {});

        if (participants.contains(userPhone)) {
          if (includeDeleted || !deletedFor.containsKey(userPhone)) {
            final cleanPhoneKey = userPhone.replaceAll('+', 'p');
            final int currentUnread = chatMap['unreadCount']?[cleanPhoneKey] ?? 0;

            chats.add(Chat(
              id: chatId.toString(),
              participants: participants,
              lastMessage: chatMap['lastMessage'] ?? '',
              lastMessageTime: chatMap['lastMessageTime'] ?? 0,
              lastMessageSender: chatMap['lastMessageSender'] ?? '',
              createdAt: chatMap['createdAt'] ?? 0,
              updatedAt: chatMap['updatedAt'] ?? 0,
              deletedFor: deletedFor,
              clearedFor: Map<String, dynamic>.from(chatMap['clearedFor'] ?? {}),
              isBlocked: chatMap['isBlocked'] ?? false,
              blockedBy: chatMap['blockedBy'],
              isDeletedChatForYou: deletedFor.containsKey(userPhone),
              unreadCount: currentUnread,
            ));
          }
        }
      });

      chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return chats;
    } catch (e) {
      print('❌ خطأ في جلب المحادثات: $e');
      return [];
    }
  }

  // دالة إرسال دعوة للمستخدمين غير المسجلين عبر الواتساب مباشرة
  Future<void> sendWhatsAppInvite({required String phoneNumber, required String contactName}) async {
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    if (cleanNumber.startsWith('00')) {
      cleanNumber = cleanNumber.substring(2);
    }
    if (cleanNumber.startsWith('0') && !cleanNumber.startsWith('00')) {
      cleanNumber = '970${cleanNumber.substring(1)}';
    }

    final String message = "مرحباً $contactName! 👋\n"
        "أنا أستخدم تطبيق ChatApp الجديد للمحادثات السريعة والآمنة 🚀.\n"
        "لقد أضفتك للتو من جهات الاتصال لدي، قم بتحميل التطبيق الآن ولنبدأ الدردشة:\n"
        "👉 [رابط تحميل تطبيقك هنا]";

    final Uri whatsappUri = Uri.parse(
        'https://wa.me/$cleanNumber?text=${Uri.encodeComponent(message)}'
    );

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
        print("✅ تم فتح الواتساب بنجاح لإرسال الدعوة لـ $cleanNumber");
      } else {
        print("❌ لا يمكن فتح الرابط، جاري محاولة الفتح بالرابط البديل");
        final Uri backupUri = Uri.parse('https://api.whatsapp.com/send?phone=$cleanNumber&text=${Uri.encodeComponent(message)}');
        await launchUrl(backupUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print("❌ خطأ أثناء محاولة فتح الواتساب: $e");
    }
  }
}

/*
// خدمة الرسائل
class MessageService {
  final FirebaseDatabase db;

  MessageService(this.db);

  Future<void> sendMessage(Message message) async {
    if (!message.isValid) {
      throw Exception('بيانات الرسالة غير صالحة');
    }

    try {
      final chatRef = db.ref('chats').child(message.chatId).child('messages');
      final newMessageRef = chatRef.push();

      final messageWithId = message.toMap();
      messageWithId['id'] = newMessageRef.key;

      await newMessageRef.set(messageWithId);

      // تحديث بيانات المحادثة الأساسية عند إرسال رسالة جديدة
      await db.ref('chats').child(message.chatId).update({
        'lastMessage': message.body,
        'lastMessageTime': message.timestamp,
        'lastMessageSender': message.senderUser,
        'updatedAt': message.timestamp,
      });
    } catch (e) {
      print('❌ خطأ في إرسال الرسالة: $e');
      rethrow;
    }
  }

  // ✅ تحديث دالة القراءة لتتوافق مع معيار رقم الهاتف بالكامل
  Future<void> markMessagesAsRead(String chatId, String userPhone) async {
    try {
      final messagesRef = db.ref('chats').child(chatId).child('messages');
      final snapshot = await messagesRef.get();

      if (!snapshot.exists) return;

      final messages = snapshot.value as Map<dynamic, dynamic>? ?? {};
      final updates = <String, dynamic>{};

      messages.forEach((key, value) {
        final messageData = Map<String, dynamic>.from(value);
        // التحقق باستخدام رقم الهاتف المستقبل للرسالة
        if (messageData['resevUser'] == userPhone && messageData['isRead'] != true) {
          updates['$key/isRead'] = true;
        }
      });

      if (updates.isNotEmpty) {
        await messagesRef.update(updates);
      }
    } catch (e) {
      print('❌ خطأ في تحديث حالة القراءة للرسائل: $e');
    }
  }

}

 */