import 'dart:async';
import 'package:ChatApp/Provider/network_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Notifications/notifications.dart';
import '../model/user.dart';
import '../service/hash_service.dart';

// Providers
final appUserDataProvider = StateProvider<AppUser?>((ref) => null);
final appUserPhoneProvider = StateProvider<String?>((ref) => null);
final isLoadingProvider = StateProvider<bool>((ref) => false);
final isLoginProvider = StateProvider<bool>((ref) => false);
final currentReceiverProvider = StateProvider<AppUser?>((ref) => null);

final authServiceProvider = Provider<AuthService>((ref) {
  final db = FirebaseDatabase.instance;
  final authService = AuthService(db);

  ref.listen<bool>(internetConnectionProvider, (prev, next) {
    authService.isConnected = next;
    if (next && authService._currentUserId != null) {
      authService.goOnline(authService._currentUserId!);
    } else if (!next && authService._currentUserId != null) {
      // لا نفعل شيء هنا - onDisconnect سيتولى الأمر
      // لكن نحدث محلياً فقط
      authService._saveUserStatusLocally(false);
    }
  });

  return authService;
});

final currentUserStreamProvider = StreamProvider<AppUser?>((ref) {
  final service = ref.watch(authServiceProvider);
  return service.watchCurrentUser();
});

final userDataProvider = FutureProvider.family<AppUser?, String>((ref, phone) async {
  final service = ref.watch(authServiceProvider);
  return await service.getUserByPhone(phone);
});

// ✅ Provider جديد: استماع مباشر لحالة المستخدم من Firebase
final userPresenceStreamProvider = StreamProvider.family<AppUser?, String>((ref, userId) {
  final db = FirebaseDatabase.instance;
  return db.ref('users').child(userId).onValue.map((event) {
    final snapshot = event.snapshot;
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      return AppUser.fromMap(userId, data);
    }
    return null;
  });
});

class AuthService {
  final FirebaseDatabase db;
  bool isConnected = true;
  String? _currentUserId;

  Timer? _onlineStatusTimer;
  StreamSubscription? _connectedSubscription;

  AuthService(this.db) {
    _setupLifecycleObserver();
  }

  // ✅ مراقبة دورة حياة التطبيق
  void _setupLifecycleObserver() {
    WidgetsBinding.instance.addObserver(AppLifecycleObserver(this));
  }

  // ✅ إعداد Firebase Presence مع onDisconnect
  void setupPresence(String userId) {
    if (userId.isEmpty) return;

    _currentUserId = userId;
    final userStatusRef = db.ref('users/$userId');
    final connectedRef = db.ref('.info/connected');

    // إلغاء أي استماع سابق
    _connectedSubscription?.cancel();

    // الاستماع لحالة اتصال الجهاز بسيرفرات Firebase
    _connectedSubscription = connectedRef.onValue.listen((event) {
      final connected = event.snapshot.value as bool? ?? false;

      if (connected) {
        print('🔵 متصل بـ Firebase');

        // 1. تحديث حالة Online
        userStatusRef.update({
          'isOnline': true,
          'lastSeen': ServerValue.timestamp,
        });

        // 2. ⭐ الأهم: أخبر Firebase ماذا يفعل إذا انقطع الاتصال فجأة!
        userStatusRef.onDisconnect().update({
          'isOnline': false,
          'lastSeen': ServerValue.timestamp,
        });

        _saveUserStatusLocally(true);

        // 3. بدء نبضات Ping
        _startOnlineStatusPing(userId);
      } else {
        print('🔴 غير متصل بـ Firebase');
        _stopOnlineStatusPing();
        _saveUserStatusLocally(false);
      }
    });
  }

  // ✅ نبضات دورية للتأكد من أن المستخدم لا يزال متصلاً
  void _startOnlineStatusPing(String userId) {
    _stopOnlineStatusPing();

    _onlineStatusTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (_currentUserId != null && isConnected) {
        try {
          await db.ref('users/$userId').update({
            'lastSeen': ServerValue.timestamp,
            'isOnline': true,
          });

          // إعادة تسجيل onDisconnect بعد كل تحديث
          await db.ref('users/$userId').onDisconnect().update({
            'isOnline': false,
            'lastSeen': ServerValue.timestamp,
          });

          print('💓 Ping: تم تحديث حالة المستخدم');
        } catch (e) {
          print('❌ خطأ في Ping: $e');
        }
      }
    });
  }

  void _stopOnlineStatusPing() {
    _onlineStatusTimer?.cancel();
    _onlineStatusTimer = null;
  }

  // ✅ تحويل المستخدم إلى Online
  Future<void> goOnline(String userId) async {
    if (userId.isEmpty) return;

    try {
      await db.ref('users/$userId').update({
        'isOnline': true,
        'lastSeen': ServerValue.timestamp,
      });

      // إعادة تسجيل onDisconnect
      await db.ref('users/$userId').onDisconnect().update({
        'isOnline': false,
        'lastSeen': ServerValue.timestamp,
      });

      await _saveUserStatusLocally(true);
      print('✅ تم تحويل المستخدم إلى Online');
    } catch (e) {
      print('❌ خطأ في goOnline: $e');
    }
  }

  // ✅ تحويل المستخدم إلى Offline
  Future<void> goOffline(String userId) async {
    if (userId.isEmpty) return;

    try {
      // إلغاء onDisconnect أولاً
      await db.ref('users/$userId').onDisconnect().cancel();

      // تحديث الحالة
      await db.ref('users/$userId').update({
        'isOnline': false,
        'lastSeen': ServerValue.timestamp,
      });

      await _saveUserStatusLocally(false);
      print('✅ تم تحويل المستخدم إلى Offline');
    } catch (e) {
      print('❌ خطأ في goOffline: $e');
    }
  }

  // ✅ تحديث حالة المستخدم (للتوافق مع الكود القديم)
  Future<void> updateUserStatus(String userId, bool isOnline) async {
    if (isOnline) {
      await goOnline(userId);
    } else {
      await goOffline(userId);
    }
  }

  // ✅ حفظ حالة المستخدم محلياً
  Future<void> _saveUserStatusLocally(bool isOnline) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isUserOnline', isOnline);
      await prefs.setInt('lastSeen', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('❌ خطأ في حفظ الحالة محلياً: $e');
    }
  }

  // ✅ استعادة الحالة المحلية
  Future<bool> getLocalUserStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('isUserOnline') ?? false;
    } catch (e) {
      return false;
    }
  }

  Stream<AppUser?> watchCurrentUser() {
    return Stream.periodic(const Duration(seconds: 3), (_) async {
      final isLoggedIn = await checkLogin();
      if (isLoggedIn && _currentUserId != null) {
        return await getUserById(_currentUserId!);
      }
      return null;
    }).asyncMap((event) => event);
  }

  Future<AppUser?> login(String phone, String password, BuildContext context) async {
    try {
      final snapshot = await db.ref('users').orderByChild('phone').equalTo(phone).get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        if (data.isNotEmpty) {
          final entry = data.entries.first;
          final userId = entry.key.toString();
          final userData = Map<String, dynamic>.from(entry.value);

          final hashedInputPassword = HashService.hashPassword(password);

          if (userData['password'] == hashedInputPassword || userData['password'] == password) {
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

            await _saveLoginState(true, user);
            await Future.delayed(const Duration(milliseconds: 500));

            // ✅ إعداد Presence بعد تسجيل الدخول
            setupPresence(userId);

            await NotificationService().loginUser(user.phone);

            return user;
          } else {
            throw Exception('كلمة المرور غير صحيحة');
          }
        }
      }
      return await register(phone, password, context);
    } catch (e) {
      print('❌ خطأ في تسجيل الدخول: $e');
      return null;
    }
  }

  Future<AppUser?> register(String phone, String password, BuildContext context) async {
    try {
      final response = await db.ref('users').orderByChild('phone').equalTo(phone).get();

      if (response.exists) {
        return await login(phone, password, context);
      }

      final newUserRef = db.ref('users').push();

      final newUser = AppUser(
        id: newUserRef.key,
        email: 'example@gmail.com',
        phone: phone,
        displayName: phone,
        isOnline: true,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
        password: HashService.hashPassword(password),
      );

      await newUserRef.set(newUser.toMap());
      _currentUserId = newUserRef.key;

      await _saveLoginState(true, newUser);

      // ✅ إعداد Presence بعد التسجيل
      setupPresence(_currentUserId!);

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

  Future<void> logout() async {
    _stopOnlineStatusPing();
    _connectedSubscription?.cancel();

    if (_currentUserId != null) {
      await goOffline(_currentUserId!);
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
      final snapshot = await db.ref('users').orderByChild('phone').equalTo(phone).get();

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
      final snapshot = await db.ref('users').orderByChild('phone').equalTo(phone).get();

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

  Future<void> updateUserProfile(String userId, {String? name, String? email, String? imageUrl}) async {
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

  Future<bool> changePassword(String userId, String oldPassword, String newPassword) async {
    try {
      final snapshot = await db.ref('users').child(userId).get();

      if (!snapshot.exists) {
        throw Exception('المستخدم غير موجود');
      }

      final userData = Map<String, dynamic>.from(snapshot.value as Map);

      final hashedOldInput = HashService.hashPassword(oldPassword);
      if (userData['password'] != hashedOldInput && userData['password'] != oldPassword) {
        throw Exception('كلمة المرور القديمة غير صحيحة');
      }

      await db.ref('users').child(userId).update({
        'password': HashService.hashPassword(newPassword),
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
          final participants = List<String>.from(chatData['participants'] ?? []);

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

  void dispose() {
    _stopOnlineStatusPing();
    _connectedSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(AppLifecycleObserver(this));
  }
}

// ✅ مراقب دورة حياة التطبيق
class AppLifecycleObserver with WidgetsBindingObserver {
  final AuthService authService;

  AppLifecycleObserver(this.authService);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('📱 دورة حياة التطبيق: $state');

    switch (state) {
      case AppLifecycleState.resumed:
      // التطبيق عاد للForeground
        if (authService._currentUserId != null && authService.isConnected) {
          authService.goOnline(authService._currentUserId!);
        }
        break;

      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      // التطبيق ذهب للBackground
        if (authService._currentUserId != null) {
          authService.goOffline(authService._currentUserId!);
        }
        break;

      case AppLifecycleState.detached:
      // التطبيق تم فصله
        if (authService._currentUserId != null) {
          authService.goOffline(authService._currentUserId!);
        }
        break;
    }
  }
}

final authStateProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(authServiceProvider);
  return Stream.periodic(const Duration(seconds: 2), (_) async {
    return await service.checkLogin();
  }).asyncMap((event) => event);
});

final cachedUserProvider = FutureProvider<AppUser?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final phone = prefs.getString('phone') ?? '';
  final userEmail = prefs.getString('userEmail');
  final userId = prefs.getString('userId');
  final userName = prefs.getString('userName');
  final isOnline = prefs.getBool('isUserOnline') ?? false;
  final lastSeen = prefs.getInt('lastSeen') ?? 0;

  if (userId != null && userId.isNotEmpty) {
    return AppUser(
      id: userId,
      email: userEmail ?? 'example@gmail.com',
      phone: phone,
      displayName: userName ?? phone,
      isOnline: isOnline,
      lastSeen: lastSeen,
    );
  }

  return null;
});