// lib/Notifications/AdvancedCacheService.dart

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
  static const String messageBoxName = 'messages';
  static const String metadataBoxName = 'metadata';

  final FirebaseDatabase db = FirebaseDatabase.instance;
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = true;

  // ✅ إضافة متغيرات للصناديق
  Box<HiveChat>? _chatsBox;
  Box? _metaBox;
  final Map<String, Box<HiveMessage>> _messagesBoxes = {};

  AdvancedCacheService() {
    _initBoxes();
    _initFirebaseOffline();
    _monitorConnectivity();
  }

  // ✅ تهيئة الصناديق
  Future<void> _initBoxes() async {
    try {
      // ✅ فتح صندوق المحادثات
      if (!Hive.isBoxOpen(chatBoxName)) {
        _chatsBox = await Hive.openBox<HiveChat>(chatBoxName);
        print('✅ تم فتح صندوق المحادثات');
      } else {
        _chatsBox = Hive.box<HiveChat>(chatBoxName);
      }

      // ✅ فتح صندوق البيانات الوصفية
      if (!Hive.isBoxOpen(metadataBoxName)) {
        _metaBox = await Hive.openBox(metadataBoxName);
        print('✅ تم فتح صندوق البيانات الوصفية');
      } else {
        _metaBox = Hive.box(metadataBoxName);
      }
    } catch (e) {
      print('❌ خطأ في فتح الصناديق: $e');
    }
  }

  // ✅ الحصول على صندوق المحادثات (مع التحقق)
  Box<HiveChat> get _getChatsBox {
    if (_chatsBox == null || !_chatsBox!.isOpen) {
      throw Exception('صندوق المحادثات غير مفتوح');
    }
    return _chatsBox!;
  }

  // ✅ الحصول على صندوق البيانات الوصفية
  Box get _getMetaBox {
    if (_metaBox == null || !_metaBox!.isOpen) {
      throw Exception('صندوق البيانات الوصفية غير مفتوح');
    }
    return _metaBox!;
  }

  // ✅ الحصول على صندوق رسائل محادثة معين
  Future<Box<HiveMessage>> _getMessagesBox(String chatId) async {
    final boxName = '${messageBoxName}_$chatId';

    if (_messagesBoxes.containsKey(chatId) && _messagesBoxes[chatId]!.isOpen) {
      return _messagesBoxes[chatId]!;
    }

    if (!Hive.isBoxOpen(boxName)) {
      final box = await Hive.openBox<HiveMessage>(boxName);
      _messagesBoxes[chatId] = box;
      print('✅ تم فتح صندوق رسائل للمحادثة $chatId');
      return box;
    } else {
      final box = Hive.box<HiveMessage>(boxName);
      _messagesBoxes[chatId] = box;
      return box;
    }
  }

  void _initFirebaseOffline() {
    try {
      db.ref('chats').keepSynced(true);
      print('✅ Firebase keepSynced enabled');
    } catch (e) {
      print('⚠️ keepSynced error: $e');
    }
  }

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

  Future<void> _syncPendingChanges() async {
    print('🔄 Syncing pending changes...');
  }

  // ✅ حفظ مع Metadata
  Future<void> cacheChats(List<Chat> chats) async {
    try {
      await _initBoxes(); // تأكد من فتح الصناديق

      final box = _getChatsBox;
      final metaBox = _getMetaBox;

      await box.clear();
      for (var chat in chats) {
        await box.put(chat.id, _chatToHiveChat(chat));
      }

      await metaBox.put('last_sync', DateTime.now().toIso8601String());
      await metaBox.put('chats_count', chats.length);

      print('✅ Cached ${chats.length} chats successfully');
    } catch (e) {
      print('❌ Cache error: $e');
    }
  }

  Future<Map<String, dynamic>> getCachedChatsWithMetadata() async {
    try {
      await _initBoxes();

      final box = _getChatsBox;
      final metaBox = _getMetaBox;

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

  // ✅ جلب المحادثات فقط (متزامن - للاستخدام في الـ UI)
  List<Chat> getCachedChats() {
    try {
      if (_chatsBox == null || !_chatsBox!.isOpen) {
        print('⚠️ صندوق المحادثات غير مفتوح');
        return [];
      }

      final box = _chatsBox!;
      final List<Chat> chats = box.values
          .map((hiveChat) => _hiveChatToChat(hiveChat))
          .toList();

      chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      print('📦 تم جلب ${chats.length} محادثة من الكاش');
      return chats;
    } catch (e) {
      print('❌ Cache read error: $e');
      return [];
    }
  }

  // ✅ حفظ محادثة واحدة (متزامن - لا ننتظر الفتح)
  Future<void> cacheSingleChat(Chat chat) async {
    try {
      // ✅ التأكد من فتح الصندوق قبل الاستخدام
      if (_chatsBox == null || !_chatsBox!.isOpen) {
        await _initBoxes();
      }

      if (_chatsBox != null && _chatsBox!.isOpen) {
        await _chatsBox!.put(chat.id, _chatToHiveChat(chat));
        print('✅ Cached single chat: ${chat.id}');
      } else {
        print('⚠️ لا يمكن حفظ المحادثة - الصندوق غير مفتوح');
      }
    } catch (e) {
      print('❌ Single chat cache error: $e');
    }
  }

  // ✅ حذف محادثة
  Future<void> deleteCachedChat(String chatId) async {
    try {
      if (_chatsBox == null || !_chatsBox!.isOpen) {
        await _initBoxes();
      }

      if (_chatsBox != null && _chatsBox!.isOpen) {
        await _chatsBox!.delete(chatId);
        print('✅ Deleted cached chat: $chatId');
      }
    } catch (e) {
      print('❌ Delete cache error: $e');
    }
  }

  List<Chat> searchCachedChats(String query) {
    try {
      if (_chatsBox == null || !_chatsBox!.isOpen) {
        return [];
      }

      final allChats = _chatsBox!.values
          .map((hiveChat) => _hiveChatToChat(hiveChat))
          .toList();

      final results = allChats.where((chat) {
        return chat.lastMessage.toLowerCase().contains(query.toLowerCase());
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
      if (_chatsBox != null && _chatsBox!.isOpen) {
        await _chatsBox!.clear();
      }

      if (_metaBox != null && _metaBox!.isOpen) {
        await _metaBox!.clear();
      }

      // مسح صناديق الرسائل
      for (var box in _messagesBoxes.values) {
        if (box.isOpen) {
          await box.clear();
        }
      }
      _messagesBoxes.clear();

      print('✅ Cache cleared');
    } catch (e) {
      print('❌ Clear cache error: $e');
    }
  }

  bool get isOnline => _isOnline;

  bool hasCachedData() {
    try {
      if (_chatsBox == null || !_chatsBox!.isOpen) {
        return false;
      }
      return _chatsBox!.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    // لا نغلق الصناديق هنا لأنها قد تستخدم في أماكن أخرى
  }

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
      unreadCount: chat.unreadCount is Map
          ? Map<String, int>.from(chat.unreadCount)
          : null,
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
      isBlocked: hiveChat.isBlocked,
      blockedBy: hiveChat.blockedBy,
      isDeletedChatForYou: false,
      unreadCount: hiveChat.unreadCount,
    );
  }

  // ✅ حفظ آخر 50 رسالة فقط
  Future<void> saveMessages(String chatId, List<Message> messages) async {
    try {
      final box = await _getMessagesBox(chatId);
      await box.clear();

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
      final box = await _getMessagesBox(chatId);
      final messages = box.values.map((hiveMsg) => Message(
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
      if (_messagesBoxes.containsKey(chatId)) {
        final box = _messagesBoxes[chatId]!;
        if (box.isOpen) {
          await box.clear();
        }
        _messagesBoxes.remove(chatId);
      }

      final boxName = '${messageBoxName}_$chatId';
      if (Hive.isBoxOpen(boxName)) {
        final box = Hive.box<HiveMessage>(boxName);
        await box.clear();
        await box.close();
      }
      print('✅ تم حذف رسائل المحادثة $chatId من الكاش');
    } catch (e) {
      print('❌ خطأ في حذف رسائل المحادثة من الكاش: $e');
    }
  }

  // ✅ تحديث رسالة في الكاش
  Future<void> updateMessageInCache(String chatId, String messageId, String newBody, int editedAt) async {
    try {
      final box = await _getMessagesBox(chatId);
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
      final box = await _getMessagesBox(chatId);
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