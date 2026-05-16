// cache_service.dart
import 'package:firebase_database/firebase_database.dart';
import 'package:hive/hive.dart';

import '../model/chat.dart';

class CacheService {
  static const String chatBoxName = 'chats_cache';
  final FirebaseDatabase db=FirebaseDatabase.instance;


  ChatService() {
    // ✅ هذا السطر يخبر Firebase بضرورة الاحتفاظ بنسخة محلية ومزامنتها في الخلفية
    db.ref('chats').keepSynced(true);
  }

  // حفظ المحادثات
  Future<void> cacheChats(List<Chat> chats) async {
    final box = await Hive.openBox(chatBoxName);
    final data = chats.map((e) => e.toMap()).toList();
    await box.put('my_chats', data);
  }

  // جلب المحادثات المخزنة
  Future<List<Chat>> getCachedChats() async {
    final box = await Hive.openBox(chatBoxName);
    final data = box.get('my_chats') as List?;
    if (data == null) return [];
    return data.map((e) => Chat.fromMap(Map<String, dynamic>.from(e))).toList();
  }
}