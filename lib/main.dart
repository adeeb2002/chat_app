import 'dart:async';

import 'package:ChatApp/Provider/userProvide.dart';
import 'package:ChatApp/Screen/SplashScreen.dart';
import 'package:ChatApp/Screen/home.dart';
import 'package:ChatApp/Screen/login.dart';
import 'package:ChatApp/hiveModle/HiveMessage.dart';
import 'package:ChatApp/service/firebase_options.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Notifications/CacheService.dart';
import 'Notifications/NotificationHandler.dart';
import 'Notifications/PendingNotificationsService.dart';
import 'Notifications/notifications.dart';
import 'hiveModle/HiveChat.dart';
import 'hiveModle/HiveUser.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // 1️⃣ تحميل .env أولاً
    await dotenv.load(fileName: ".env");
    print('✅ تم تحميل .env');
  } catch (e) {
    print('⚠️ تحذير: خطأ في تحميل .env: $e');
  }

  try {
    // ✅ تهيئة Hive
    await Hive.initFlutter();

    // ✅ تسجيل Adapter HiveChat
    Hive.registerAdapter(HiveChatAdapter());
    Hive.registerAdapter(HiveMessageAdapter());

    // ✅ فتح الصناديق المطلوبة
    await Hive.openBox<HiveChat>(AdvancedCacheService.chatBoxName);
    await Hive.openBox(AdvancedCacheService.metadataBoxName);

    // ✅ تهيئة خدمة الكاش (Singleton)
    final cacheService = AdvancedCacheService();

    // 2️⃣ تهيئة Firebase
    // 🌟 السطر السحري: تفعيل كاش فايربيز الداخلي على الهاتف للعمل أوفلاين
    FirebaseDatabase.instance.setPersistenceEnabled(true);
    FirebaseDatabase.instance.setPersistenceCacheSizeBytes(
      100000000,
    ); // تحديد مساحة الكاش (مثلاً 100 ميجابايت)


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

    // ✅ تنظيف الإشعارات القديمة كل يوم
    Timer.periodic(const Duration(days: 1), (timer) {
      PendingNotificationsService().cleanOldNotifications();
    });
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


  @override
  Widget build(BuildContext context) {


    return MaterialApp(
      navigatorKey: NotificationHandler().navigatorKey,
      title: 'Chat App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green),
      home: SplashScreen()
    );
  }
}
