import 'dart:async';
import 'package:ChatApp/Provider/network_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Notifications/notifications.dart';
import '../model/user.dart';
import '../service/hash_service.dart';
import '../service/linkedin_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Timer? _onlineStatusTimer;
  StreamSubscription? _connectedSubscription;
  String? _changePhoneVerificationId;


  AuthService(this.db) {
    _setupLifecycleObserver();
  }

  // ✅ مراقبة دورة حياة التطبيق
  void _setupLifecycleObserver() {
    WidgetsBinding.instance.addObserver(AppLifecycleObserver(this));
  }

  Future<User?> firebaseAuthLoginWithEmail(
      String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } catch (e) {
      print('Firebase Auth Error: $e');
      return null;
    }
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
    return _firebaseAuth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;

      final snapshot =
      await db.ref('users').child(firebaseUser.uid).get();

      if (snapshot.exists) {
        final data =
        Map<String, dynamic>.from(snapshot.value as Map);
        return AppUser.fromMap(firebaseUser.uid, data);
      }

      return null;
    });
  }

  Future<AppUser?> loginWithPhoneAsKey(
     String phone,
     String firebasePassword,
  ) async {
    try {
      // ✅ 1. جلب بيانات المستخدم باستخدام phone مباشرة
      final snapshot = await db.ref('users').child(phone).get();

      if (!snapshot.exists) {
        throw Exception("بيانات غير صحيحة");
      }

      final userData =
      Map<String, dynamic>.from(snapshot.value as Map);

      final email = userData['email'];

      // ✅ 2. تسجيل دخول Firebase
      final credential =
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: firebasePassword,
      );

      if (credential.user == null) {
        throw Exception("فشل تسجيل الدخول");
      }

      // ✅ 3. تأكد أن UID مطابق
      if (credential.user!.uid != userData['uid']) {
        throw Exception("خطأ في تطابق الحساب");
      }

      final user = AppUser.fromMap(phone, userData);

      _currentUserId = phone;

      await _saveLoginState(true, user);
      setupPresence(phone);

      return user;
    } catch (e) {
      print("❌ Login Error: $e");
      return null;
    }
  }
  Future<AppUser?> registerWithPhoneAsKey(
     String phone,
     String email,
     String firebasePassword,
     String displayName,
  ) async {
    try {
      // ✅ إنشاء مستخدم Firebase
      final credential =
      await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: firebasePassword,
      );

      final uid = credential.user!.uid;

      // ✅ تخزين في DB باستخدام phone كمفتاح
      await db.ref('users').child(phone).set({
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'phone': phone,
        'phoneVerified': true,
        'isOnline': true,
        'lastSeen': ServerValue.timestamp,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });

      final user = AppUser(
        id: phone, // ✅ المفتاح أصبح phone
        email: email,
        phone: phone,
        displayName: displayName,
        isOnline: true,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );

      _currentUserId = phone;

      await _saveLoginState(true, user);
      setupPresence(phone);

      return user;
    } catch (e) {
      print("❌ Register Error: $e");
      return null;
    }
  }

  Future<AppUser?> loginWithGoogle() async {
    try {
      // ✅ 1. اختيار حساب Google
      final GoogleSignInAccount? googleUser =
      await _googleSignIn.signIn();

      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      // ✅ 2. إنشاء Credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // ✅ 3. تسجيل الدخول في FirebaseAuth
      final userCredential =
      await _firebaseAuth.signInWithCredential(credential);

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) return null;

      final uid = firebaseUser.uid;

      // ✅ 4. تحقق إذا المستخدم موجود في Realtime Database
      final snapshot = await db.ref('users').child(uid).get();

      if (snapshot.exists) {
        final data =
        Map<String, dynamic>.from(snapshot.value as Map);

        final user = AppUser.fromMap(uid, data);

        _currentUserId = uid;
        await _saveLoginState(true, user);
        setupPresence(uid);

        return user;
      }

      // ✅ 5. إنشاء مستخدم جديد
      final newUser = AppUser(
        id: uid,
        email: firebaseUser.email,
        phone: '',
        displayName: firebaseUser.displayName ?? 'Google User',
        imageUrl: firebaseUser.photoURL,
        isOnline: true,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );

      await db.ref('users').child(uid).set({
        ...newUser.toMap(),
        'provider': 'google',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });

      _currentUserId = uid;
      await _saveLoginState(true, newUser);
      setupPresence(uid);

      return newUser;
    } catch (e) {
      print("❌ Google Login Error: $e");
      return null;
    }
  }

  Future<void> sendChangePhoneOTP(String newPhone) async {
    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: newPhone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _firebaseAuth.currentUser!
            .linkWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        print("❌ Phone verification failed: $e");
      },
      codeSent: (String verificationId, int? resendToken) {
        _changePhoneVerificationId = verificationId;
        print("✅ OTP Sent for phone change");
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _changePhoneVerificationId = verificationId;
      },
    );
  }

  Future<bool> verifyAndChangePhone({
    required String oldPhone,
    required String newPhone,
    required String smsCode,
  }) async {
    try {
      // ✅ 1. تأكد أن الرقم الجديد غير مستخدم
      final newPhoneSnapshot =
      await db.ref('users').child(newPhone).get();

      if (newPhoneSnapshot.exists) {
        throw Exception("الرقم الجديد مستخدم مسبقاً");
      }

      // ✅ 2. تحقق OTP
      final credential = PhoneAuthProvider.credential(
        verificationId: _changePhoneVerificationId!,
        smsCode: smsCode,
      );

      await _firebaseAuth.currentUser!
          .linkWithCredential(credential);

      // ✅ 3. جلب بيانات المستخدم القديمة
      final oldSnapshot =
      await db.ref('users').child(oldPhone).get();

      if (!oldSnapshot.exists) {
        throw Exception("الحساب غير موجود");
      }

      final userData =
      Map<String, dynamic>.from(oldSnapshot.value as Map);

      // ✅ 4. نقل البيانات إلى الرقم الجديد
      await db.ref('users').child(newPhone).set({
        ...userData,
        'phone': newPhone,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // ✅ 5. حذف الحساب القديم
      await db.ref('users').child(oldPhone).remove();

      // ✅ 6. تحديث Presence
      _currentUserId = newPhone;
      setupPresence(newPhone);

      print("✅ تم تغيير رقم الهاتف بأمان");

      return true;
    } catch (e) {
      print("❌ Change Phone Error: $e");
      return false;
    }
  }

  Future<AppUser?> loginWithLinkedIn(BuildContext context) async {
    try {
      final linkedInData = await LinkedInService().login();
      if (linkedInData == null) return null;

      final linkedinId = linkedInData['sub'];
      final email = linkedInData['email'];
      final name = linkedInData['name'];
      final image = linkedInData['picture'];

      // هل المستخدم موجود؟
      final snapshot = await db
          .ref('users')
          .orderByChild('linkedinId')
          .equalTo(linkedinId)
          .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map;
        final entry = data.entries.first;
        final userId = entry.key;

        final user = AppUser.fromMap(userId, Map.from(entry.value));

        _currentUserId = userId;
        await _saveLoginState(true, user);
        setupPresence(userId);

        return user;
      }

      // إنشاء مستخدم جديد
      final newUserRef = db.ref('users').push();

      final newUser = AppUser(
        id: newUserRef.key,
        phone: '',
        email: email,
        displayName: name,
        imageUrl: image,
        isOnline: true,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );

      await newUserRef.set({
        ...newUser.toMap(),
        'linkedinId': linkedinId,
        'provider': 'linkedin',
      });

      _currentUserId = newUserRef.key;
      await _saveLoginState(true, newUser);
      setupPresence(_currentUserId!);

      return newUser;
    } catch (e) {
      print('LinkedIn Auth Error: $e');
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

    await _firebaseAuth.signOut(); // ✅ مهم جداً

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    _currentUserId = null;

    await NotificationService().logoutUser();

    print('✅ تم تسجيل الخروج بنجاح');
  }

  Future<bool> checkLogin() async {
    final user = _firebaseAuth.currentUser;
    return user != null;
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