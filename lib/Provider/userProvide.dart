import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Notifications/notifications.dart';
import '../model/user.dart';

// ✅ إعادة تسمية الـ Providers بشكل واضح
final appUserDataProvider = StateProvider<AppUser?>((ref) => null);
final appUserPhoneProvider = StateProvider<String?>((ref) => null);
final isLoadingProvider = StateProvider<bool>((ref) => false);
final isLoginProvider = StateProvider<bool>((ref) => false);
final currentReceiverProvider = StateProvider<AppUser?>((ref) => null);
final internetConnectionProvider = StateProvider<bool>((ref) => true);

// ✅ authServiceProvider
final authServiceProvider = Provider<AuthService>((ref) {
  final db = FirebaseDatabase.instance;
  final connection = ref.watch(internetConnectionProvider);
  return AuthService(db, connection);
});

// Stream Provider للمستخدم
final currentUserStreamProvider = StreamProvider<AppUser?>((ref) {
  final service = ref.watch(authServiceProvider);
  return service.watchCurrentUser();
});

// Provider لجلب بيانات مستخدم
final userDataProvider = FutureProvider.family<AppUser?, String>((
    ref,
    phone,
    ) async {
  final service = ref.watch(authServiceProvider);
  return await service.getUserByPhone(phone);
});

class AuthService {
  final FirebaseDatabase db;
  bool isConnected;
  StreamSubscription? _connectionSubscription;
  String? _currentUserId;

  // ✅ StreamController لإعلام التغييرات
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  AuthService(this.db, this.isConnected) {
    _initConnectionListener();
  }

  // ✅ تهيئة مستمع الاتصال (مرة واحدة فقط)
  void _initConnectionListener() {
    _connectionSubscription = InternetConnection().onStatusChange.listen((status) async {
      final hasConnection = status == InternetStatus.connected;

      if (isConnected != hasConnection) {
        isConnected = hasConnection;
        _connectionController.add(isConnected);

        print('🌐 حالة الاتصال تغيرت: ${isConnected ? "متصل" : "غير متصل"}');

        // ✅ عند عودة الاتصال، قم بتحديث حالة المستخدم في Firebase
        if (isConnected && _currentUserId != null) {
          await updateUserStatus(_currentUserId!, true);
        }

        // ✅ حفظ الحالة محلياً
        await saveUserStatusLocally(isConnected);
      }
    });
  }

  // ✅ الحصول على حالة الاتصال الحالية
  bool getConnectionStatus() {
    return isConnected;
  }

  // ✅ إيقاف المستمع عند الحاجة
  void dispose() {
    _connectionSubscription?.cancel();
    _connectionController.close();
  }

  Stream<AppUser?> watchCurrentUser() {
    return Stream.periodic(const Duration(seconds: 2), (_) async {
      final isLoggedIn = await checkLogin();

      if (isLoggedIn && _currentUserId != null) {
        return await getUserById(_currentUserId!);
      }
      return null;
    }).asyncMap((event) => event);
  }

  Future<AppUser?> login(
      String phone,
      String password,
      BuildContext context,
      ) async {
    try {
      final snapshot = await db
          .ref('users')
          .orderByChild('phone')
          .equalTo(phone)
          .get();

      print('snapshot data : $snapshot.value');

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        if (data.isNotEmpty) {
          final entry = data.entries.first;
          final userId = entry.key.toString();
          final userData = Map<String, dynamic>.from(entry.value);

          print('${userData['phone']} - ${userData['password']}');

          if (userData['password'] == password) {
            final user = AppUser(
              id: userId,
              phone: phone,
              email: userData['email'] ?? 'example@gmail.com',
              displayName: userData['displayName'] ?? phone,
              imageUrl: userData['imageUrl'],
              isOnline: true,
              lastSeen: DateTime.now().millisecondsSinceEpoch,
            );

            _currentUserId = userId;

            // ✅ فقط إذا كان هناك اتصال، قم بتحديث الحالة في Firebase
            if (isConnected) {
              await updateUserStatus(userId, true);
            }

            await _saveLoginState(true, user);
            await Future.delayed(const Duration(milliseconds: 500));
            await NotificationService().loginUser(user.phone);

            return user;
          } else {
            throw Exception('كلمة المرور غير صحيحة');
          }
        }
      }
      print('phone: $phone');
      return await register(phone, password, context);
    } catch (e) {
      print('❌ خطأ في تسجيل الدخول: $e');
      return null;
    }
  }

  Future<AppUser?> register(
      String phone,
      String password,
      BuildContext context,
      ) async {
    try {
      final response = await FirebaseDatabase.instance
          .ref('users')
          .orderByChild('phone')
          .equalTo(phone)
          .get();

      if (response.exists) {
        print('الرقم موجود من قبل، جاري تسجيل الدخول...');
        return await login(phone, password, context);
      }

      final newUserRef = db.ref('users').push();

      final newUser = AppUser(
        id: newUserRef.key,
        email: 'example@gmail.com',
        phone: phone,
        displayName: phone,
        isOnline: isConnected, // ✅ استخدام حالة الاتصال الحالية
        lastSeen: DateTime.now().millisecondsSinceEpoch,
        password: password,
      );

      await newUserRef.set(newUser.toMap());
      _currentUserId = newUserRef.key;
      await _saveLoginState(true, newUser);
      await NotificationService().loginUser(newUser.phone);

      return newUser;
    } catch (e) {
      print('❌ خطأ في التسجيل: $e');
      return null;
    }
  }

  Future<void> _saveLoginState(bool isLogin, AppUser? user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLogin', isLogin);
    if (user != null) {
      await prefs.setString('phone', user.phone);
      await prefs.setString('userEmail', user.email ?? '');
      await prefs.setString('userId', user.id ?? '');
      await prefs.setString('userName', user.displayName);
    }
  }

  Future<void> saveUserStatusLocally(bool isOnline) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isUserOnline', isOnline);
    await prefs.setInt('lastSeen', DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> logout() async {
    if (_currentUserId != null && isConnected) {
      await updateUserStatus(_currentUserId!, false);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('phone');
    await prefs.remove('isLogin');
    await prefs.remove('userEmail');
    await prefs.remove('userId');
    await prefs.remove('userName');

    _currentUserId = null;
    await NotificationService().logoutUser();

    print('✅ تم تسجيل الخروج بنجاح');
  }

  // ✅ تحديث حالة المستخدم (متصل/غير متصل) في Firebase
  Future<void> updateUserStatus(String userId, bool isOnline) async {
    try {
      // ✅ فقط إذا كان هناك اتصال، قم بتحديث Firebase
      if (isConnected) {
        await db.ref('users').child(userId).update({
          'isOnline': isOnline,
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
        });
        print('✅ تم تحديث حالة المستخدم في Firebase: $isOnline');
      } else {
        print('⚠️ لا يوجد اتصال، تم حفظ الحالة محلياً فقط');
      }

      // ✅ دائماً قم بحفظ الحالة محلياً
      await saveUserStatusLocally(isOnline);
    } catch (e) {
      print('❌ خطأ في تحديث الحالة: $e');
    }
  }

  Future<bool> checkLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLogin = prefs.getBool('isLogin') ?? false;

      if (isLogin) {
        final userPhone = prefs.getString('phone');
        if (userPhone != null && userPhone.isNotEmpty) {
          return true;
        }
      }
      return false;
    } catch (e) {
      print('❌ خطأ في التحقق من تسجيل الدخول: $e');
      return false;
    }
  }

  Future<AppUser?> getUserByPhone(String? phone) async {
    if (phone == null || phone.isEmpty) return null;

    try {
      final snapshot = await db
          .ref('users')
          .orderByChild('phone')
          .equalTo(phone)
          .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        if (data.isNotEmpty) {
          final entry = data.entries.first;
          return AppUser.fromMap(entry.key.toString(), Map.from(entry.value));
        }
      }
      return null;
    } catch (e) {
      print('❌ خطأ في جلب المستخدم: $e');
      return null;
    }
  }

  Future<AppUser?> getUserByPhoneLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('phone');
    if (phone == null || phone.isEmpty) return null;

    try {
      final snapshot = await db
          .ref('users')
          .orderByChild('phone')
          .equalTo(phone)
          .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        if (data.isNotEmpty) {
          final entry = data.entries.first;
          return AppUser.fromMap(entry.key.toString(), Map.from(entry.value));
        }
      }
      return null;
    } catch (e) {
      print('❌ خطأ في جلب المستخدم: $e');
      return null;
    }
  }

  Future<AppUser?> getUserById(String userId) async {
    if (userId.isEmpty) return null;

    try {
      final snapshot = await db.ref('users').child(userId).get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        return AppUser.fromMap(userId, data);
      }
      return null;
    } catch (e) {
      print('❌ خطأ في جلب المستخدم بالـ ID: $e');
      return null;
    }
  }

  Future<void> updateUserProfile(
      String userId, {
        String? name,
        String? email,
        String? imageUrl,
      }) async {
    try {
      final updates = <String, dynamic>{};
      if (email != null) updates['email'] = email;
      if (name != null) updates['displayName'] = name;
      if (imageUrl != null) updates['imageUrl'] = imageUrl;
      updates['updatedAt'] = DateTime.now().millisecondsSinceEpoch;

      await db.ref('users').child(userId).update(updates);
      print('✅ تم تحديث بيانات المستخدم');
    } catch (e) {
      print('❌ خطأ في تحديث بيانات المستخدم: $e');
      rethrow;
    }
  }

  Future<bool> changePassword(
      String userId,
      String oldPassword,
      String newPassword,
      ) async {
    try {
      final snapshot = await db.ref('users').child(userId).get();

      if (!snapshot.exists) {
        throw Exception('المستخدم غير موجود');
      }

      final userData = Map<String, dynamic>.from(snapshot.value as Map);

      if (userData['password'] != oldPassword) {
        throw Exception('كلمة المرور القديمة غير صحيحة');
      }

      await db.ref('users').child(userId).update({
        'password': newPassword,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      print('✅ تم تغيير كلمة المرور بنجاح');
      return true;
    } catch (e) {
      print('❌ خطأ في تغيير كلمة المرور: $e');
      return false;
    }
  }

  Future<bool> deleteAccount(String userId) async {
    try {
      final chatsSnapshot = await db.ref('chats').get();
      if (chatsSnapshot.exists) {
        final chats = chatsSnapshot.value as Map<dynamic, dynamic>? ?? {};

        for (var chatEntry in chats.entries) {
          final chatId = chatEntry.key.toString();
          final chatData = Map<String, dynamic>.from(chatEntry.value);
          final participants = List<String>.from(
            chatData['participants'] ?? [],
          );

          if (participants.contains(userId)) {
            await db.ref('chats').child(chatId).update({
              'deletedFor': {
                ...Map<String, dynamic>.from(chatData['deletedFor'] ?? {}),
                userId: DateTime.now().millisecondsSinceEpoch,
              },
            });
          }
        }
      }

      await db.ref('users').child(userId).remove();
      await logout();

      print('✅ تم حذف الحساب بنجاح');
      return true;
    } catch (e) {
      print('❌ خطأ في حذف الحساب: $e');
      return false;
    }
  }
}

// ✅ Provider مساعد لمراقبة حالة تسجيل الدخول
final authStateProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(authServiceProvider);
  return Stream.periodic(const Duration(seconds: 1), (_) async {
    return await service.checkLogin();
  }).asyncMap((event) => event);
});

// ✅ Provider للحصول على المستخدم الحالي من SharedPreferences
final cachedUserProvider = FutureProvider<AppUser?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final phone = prefs.getString('phone') ?? '';
  final userEmail = prefs.getString('userEmail');
  final userId = prefs.getString('userId');
  final userName = prefs.getString('userName');

  if (userId != null && userId.isNotEmpty) {
    return AppUser(
      id: userId,
      email: userEmail ?? 'example@gmail.com',
      phone: phone,
      displayName: userName ?? phone,
      isOnline: false,
      lastSeen: DateTime.now().millisecondsSinceEpoch,
    );
  }

  return null;
});