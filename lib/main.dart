import 'package:ChatApp/Provider/userProvide.dart';
import 'package:ChatApp/Screen/home.dart';
import 'package:ChatApp/Screen/login.dart';
import 'package:ChatApp/serives/firebase_options.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Notifications/NotificationHandler.dart';
import 'Notifications/PendingNotificationsService.dart';
import 'Notifications/notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 1️⃣ تحميل .env أولاً
    await dotenv.load(fileName: ".env");
    print('✅ تم تحميل .env');
  } catch (e) {
    print('⚠️ تحذير: خطأ في تحميل .env: $e');
  }

  try {
    // 2️⃣ تهيئة Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ تم تهيئة Firebase بنجاح');
  } catch (e) {
    print('❌ خطأ في تهيئة Firebase: $e');
    print('⚠️ تأكد من وجود google-services.json في android/app/');
  }

  try {
    // 3️⃣ تهيئة OneSignal
    await NotificationService().initialize();
    print('✅ تم تهيئة OneSignal بنجاح');
  } catch (e) {
    print('❌ خطأ في تهيئة OneSignal: $e');
  }

  try {
    // 4️⃣ تهيئة معالج الإشعارات
    NotificationHandler().initialize();
    print('✅ تم تهيئة معالج الإشعارات بنجاح');
  } catch (e) {
    print('❌ خطأ في معالج الإشعارات: $e');
  }

  try {
    // 5️⃣ بدء مراقبة الإشعارات المعلقة
    PendingNotificationsService().startMonitoring();
    print('✅ تم بدء مراقبة الإشعارات المعلقة');
  } catch (e) {
    print('❌ خطأ في مراقبة الإشعارات: $e');
  }

  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  bool _isChecking = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    try {
      final authService = ref.read(authServiceProvider);
      final isLoggedIn = await authService.checkLogin();
      final bool isConnected = await InternetConnection().hasInternetAccess;

      setState(() {
        _isLoggedIn = isLoggedIn;
        _isChecking = false;
      });

      if (!isConnected && isLoggedIn) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => HomeScreen()),
                (route) => false,
          );
        }
      }


      if (isLoggedIn) {
        final prefs = await SharedPreferences.getInstance();
        final userEmail = prefs.getString('userEmail');

        if (userEmail != null) {
          final user = await authService.getUserByEmail(userEmail);

          if (user != null && mounted) {
            ref.read(appUserDataProvider.notifier).state = user;
            ref.read(appUserEmailProvider.notifier).state = user.email;
            ref.read(isLoadingProvider.notifier).state = true;

            // ✅ تسجيل المستخدم في OneSignal
            try {
              await NotificationService().loginUser(user.email);
              print('✅ تم تسجيل ${user.email} في OneSignal');
            } catch (e) {
              print('❌ خطأ في تسجيل OneSignal: $e');
            }
          }
        }
      }
    } catch (e) {
      print('❌ خطأ في فحص حالة المصادقة: $e');
      setState(() {
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MaterialApp(
      navigatorKey: NotificationHandler().navigatorKey,
      title: 'Chat App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green),
      home: _isLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}