import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:hive/hive.dart';
import '../hiveModle/HiveChat.dart';
import '../hiveModle/HiveMessage.dart';
import '../model/Message.dart';
import '../model/chat.dart';

class AdvancedCacheService {
  static const String chatBoxName = 'chats';
  static const String metadataBoxName = 'metadata';

  final FirebaseDatabase db = FirebaseDatabase.instance;
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = true;

  AdvancedCacheService() {
    _initFirebaseOffline();
    _monitorConnectivity();
  }

  void _initFirebaseOffline() {
    try {
      db.ref('chats').keepSynced(true);
      print('✅ Firebase keepSynced enabled');
    } catch (e) {
      print('⚠️ keepSynced error: $e');
    }
  }

  // ✅ مراقبة حالة الإنترنت
  void _monitorConnectivity() {
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((result) {
          _isOnline = !result.contains(ConnectivityResult.none);
          print('🌐 Network status: ${_isOnline ? "Online" : "Offline"}');

          if (_isOnline) {
            _syncPendingChanges();
          }
        });
  }

  // ✅ مزامنة التغييرات المعلقة
  Future<void> _syncPendingChanges() async {
    // يمكنك إضافة منطق المزامنة هنا
    print('🔄 Syncing pending changes...');
  }

  // ✅ حفظ مع Metadata
  Future<void> cacheChats(List<Chat> chats) async {
    try {
      final box = Hive.box<HiveChat>(chatBoxName);
      final metaBox = await Hive.openBox(metadataBoxName);

      // حفظ المحادثات
      await box.clear();
      for (var chat in chats) {
        await box.put(chat.id, _chatToHiveChat(chat));
      }

      // حفظ معلومات التحديث
      await metaBox.put('last_sync', DateTime.now().toIso8601String());
      await metaBox.put('chats_count', chats.length);

      print('✅ Cached ${chats.length} chats successfully');
    } catch (e) {
      print('❌ Cache error: $e');
    }
  }

  // ✅ جلب مع معلومات الحالة
  Future<Map<String, dynamic>> getCachedChatsWithMetadata() async {
    try {
      final box = Hive.box<HiveChat>(chatBoxName);
      final metaBox = await Hive.openBox(metadataBoxName);

      final List<Chat> chats = box.values
          .map((hiveChat) => _hiveChatToChat(hiveChat))
          .toList();

      chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      final lastSync = metaBox.get('last_sync');

      return {
        'chats': chats,
        'count': chats.length,
        'lastSync': lastSync,
        'isOnline': _isOnline,
      };
    } catch (e) {
      print('❌ Cache read error: $e');
      return {
        'chats': <Chat>[],
        'count': 0,
        'lastSync': null,
        'isOnline': _isOnline,
      };
    }
  }

  // ✅ جلب المحادثات فقط
  List<Chat> getCachedChats() {
    try {
      final box = Hive.box<HiveChat>(chatBoxName);
      final List<Chat> chats = box.values
          .map((hiveChat) => _hiveChatToChat(hiveChat))
          .toList();

      chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return chats;
    } catch (e) {
      print('❌ Cache read error: $e');
      return [];
    }
  }

  // ✅ حفظ محادثة واحدة
  Future<void> cacheSingleChat(Chat chat) async {
    try {
      final box = Hive.box<HiveChat>(chatBoxName);
      await box.put(chat.id, _chatToHiveChat(chat));
      print('✅ Cached single chat: ${chat.id}');
    } catch (e) {
      print('❌ Single chat cache error: $e');
    }
  }

  // ✅ حذف محادثة
  Future<void> deleteCachedChat(String chatId) async {
    try {
      final box = Hive.box<HiveChat>(chatBoxName);
      await box.delete(chatId);
      print('✅ Deleted cached chat: $chatId');
    } catch (e) {
      print('❌ Delete cache error: $e');
    }
  }

  // ✅ البحث في المحادثات المخزنة
  List<Chat> searchCachedChats(String query) {
    try {
      final box = Hive.box<HiveChat>(chatBoxName);
      final allChats = box.values
          .map((hiveChat) => _hiveChatToChat(hiveChat))
          .toList();

      final results = allChats.where((chat) {
        return chat.lastMessage?.toLowerCase().contains(query.toLowerCase()) ??
            false;
      }).toList();

      return results;
    } catch (e) {
      print('❌ Search error: $e');
      return [];
    }
  }

  // ✅ مسح الكاش
  Future<void> clearAllCache() async {
    try {
      final box = Hive.box<HiveChat>(chatBoxName);
      final metaBox = await Hive.openBox(metadataBoxName);

      await box.clear();
      await metaBox.clear();

      print('✅ Cache cleared');
    } catch (e) {
      print('❌ Clear cache error: $e');
    }
  }

  // ✅ حالة الاتصال
  bool get isOnline => _isOnline;

  // ✅ التحقق من البيانات
  bool hasCachedData() {
    try {
      final box = Hive.box<HiveChat>(chatBoxName);
      return box.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // ✅ تنظيف الموارد
  void dispose() {
    _connectivitySubscription?.cancel();
  }

  // ✅ دوال التحويل
  HiveChat _chatToHiveChat(Chat chat) {
    return HiveChat(
      id: chat.id,
      participants: chat.participants,
      lastMessage: chat.lastMessage,
      lastMessageTime: chat.lastMessageTime,
      lastMessageSender: chat.lastMessageSender,
      createdAt: chat.createdAt,
      updatedAt: chat.updatedAt,
      deletedFor: chat.deletedFor,
      clearedFor: chat.clearedFor,
      isBlocked: chat.isBlocked ?? false,
      blockedBy: chat.blockedBy,
    );
  }

  Chat _hiveChatToChat(HiveChat hiveChat) {
    return Chat(
        id: hiveChat.id,
        participants: hiveChat.participants,
        lastMessage: hiveChat.lastMessage,
        lastMessageTime: hiveChat.lastMessageTime,
        lastMessageSender: hiveChat.lastMessageSender,
        createdAt: hiveChat.createdAt,
        updatedAt: hiveChat.updatedAt,
        deletedFor: hiveChat.deletedFor,
        clearedFor: hiveChat.clearedFor,
        isBlocked: hiveChat.isBlocked ?? false,
        blockedBy: hiveChat.blockedBy,
        isDeletedChatForYou: false
    );
  }

  // ✅ حفظ آخر 50 رسالة فقط (لتجنب تراكم البيانات)
  Future<void> saveMessages(String chatId, List<Message> messages) async {
    try {
      final box = await Hive.openBox<HiveMessage>('messages_$chatId');
      await box.clear();

      // ✅ حفظ آخر 50 رسالة فقط
      final lastMessages = messages.length > 50
          ? messages.sublist(messages.length - 50)
          : messages;

      for (var message in lastMessages) {
        final hiveMessage = HiveMessage.fromMessage(message);
        await box.put(message.id, hiveMessage);
      }

      print('✅ تم حفظ ${lastMessages.length} رسالة في الكاش للمحادثة $chatId');
    } catch (e) {
      print('❌ خطأ في حفظ الرسائل: $e');
    }
  }

    // ✅ جلب رسائل محادثة من الكاش
    Future<List<Message>> getCachedMessages(String chatId) async {
      try {
        final boxExists = await Hive.boxExists('messages_$chatId');
        if (!boxExists) return [];

        final box = await Hive.openBox<HiveMessage>('messages_$chatId');
        final messages = box.values.map((hiveMsg) =>
            Message(
              id: hiveMsg.id,
              senderUser: hiveMsg.senderUser,
              resevUser: hiveMsg.resevUser,
              body: hiveMsg.body,
              chatId: hiveMsg.chatId,
              timestamp: hiveMsg.timestamp,
              isRead: hiveMsg.isRead,
              isDeleted: hiveMsg.isDeleted,
              isSynced: hiveMsg.isSynced,
              editedAt: hiveMsg.editedAt,
            )).toList();

        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        print('📦 تم جلب ${messages.length} رسالة من الكاش للمحادثة $chatId');
        return messages;
      } catch (e) {
        print('❌ خطأ في جلب الرسائل من الكاش: $e');
        return [];
      }
    }

    // ✅ حذف رسائل محادثة من الكاش
    Future<void> deleteCachedMessages(String chatId) async {
      try {
        final boxExists = await Hive.boxExists('messages_$chatId');
        if (boxExists) {
          final box = await Hive.openBox<HiveMessage>('messages_$chatId');
          await box.clear();
          await box.close();
          print('✅ تم حذف رسائل المحادثة $chatId من الكاش');
        }
      } catch (e) {
        print('❌ خطأ في حذف رسائل المحادثة من الكاش: $e');
      }
    } // ✅ تحديث رسالة في الكاش
    Future<void> updateMessageInCache(String chatId, String messageId,
        String newBody, int editedAt) async {
      try {
        final box = await Hive.openBox<HiveMessage>('messages_$chatId');
        final message = box.get(messageId);

        if (message != null) {
          final updatedMessage = message.copyWith(
            body: newBody,
            editedAt: editedAt.toString(),
          );
          await box.put(messageId, updatedMessage);
          print('✅ تم تحديث الرسالة في الكاش');
        }
      } catch (e) {
        print('❌ خطأ في تحديث الرسالة في الكاش: $e');
      }
    }

// ✅ حذف رسالة من الكاش
    Future<void> deleteMessageFromCache(String chatId, String messageId) async {
      try {
        final box = await Hive.openBox<HiveMessage>('messages_$chatId');
        final message = box.get(messageId);

        if (message != null) {
          final updatedMessage = message.copyWith(
            isDeleted: true,
            body: 'تم حذف هذه الرسالة',
          );
          await box.put(messageId, updatedMessage);
          print('✅ تم تحديث حالة الحذف في الكاش');
        }
      } catch (e) {
        print('❌ خطأ في حذف الرسالة من الكاش: $e');
      }
    }

}