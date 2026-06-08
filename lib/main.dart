import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ChatApp/Screen/SplashScreen.dart';
import 'package:ChatApp/hiveModle/HiveMessage.dart';
import 'package:ChatApp/service/firebase_options.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/adapters.dart';

import 'Notifications/CacheService.dart';
import 'Notifications/NotificationHandler.dart';
import 'Notifications/PendingNotificationsService.dart';
import 'Notifications/notifications.dart';
import 'hiveModle/HiveChat.dart';
import 'Provider/theme_provider.dart';
import 'service/NetworkOptimizationService.dart'; // ✅ NEW
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('🚀 بدء تهيئة التطبيق...');

  // ✅ 0. تحميل المتغيرات البيئية
  try {
    await dotenv.load(fileName: 'data.env');
    print('✅ تم تحميل ملف .env');
  } catch (e) {
    print('❌ خطأ في تحميل .env: $e');
  }

  // ✅ 1. تهيئة Hive (لا تحتاج إنترنت)
  try {
    await Hive.initFlutter();
    Hive.registerAdapter(HiveChatAdapter());
    Hive.registerAdapter(HiveMessageAdapter());
    await Hive.openBox<HiveChat>(AdvancedCacheService.chatBoxName);
    await Hive.openBox(AdvancedCacheService.metadataBoxName);
    print('✅ تم تهيئة Hive بنجاح');
  } catch (e) {
    print('❌ خطأ في تهيئة Hive: $e');
  }


  // ✅ 2. تهيئة خدمة تحسين الشبكة (قبل Firebase)
  try {
    await NetworkOptimizationService().initialize();
    print('✅ تم تهيئة NetworkOptimizationService');
  } catch (e) {
    print('❌ خطأ في NetworkOptimizationService: $e');
  }

  // ✅ 3. تهيئة Firebase (مع معالجة الأخطاء)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final database = FirebaseDatabase.instance;
    database.setPersistenceEnabled(true);
    database.setPersistenceCacheSizeBytes(100000000);

    // ✅ تقليل عدد الـ sync في حالة الاتصال البطيء
    if (!NetworkOptimizationService().isSlowConnection) {
      database.ref('chats').keepSynced(true);
    }

    print('✅ تم تهيئة Firebase بنجاح');
  } catch (e) {
    print('⚠️ Firebase لم يُهيأ: $e');
    print('✅ سيستمر التطبيق في الوضع Offline');
  }

  // ✅ 4. تهيئة الإشعارات (مع معالجة الأخطاء)
  try {
    await NotificationService().initialize();
    print('✅ تم تهيئة OneSignal بنجاح');
  } catch (e) {
    print('⚠️ خطأ في تهيئة OneSignal: $e');
  }

  try {
    NotificationHandler().initialize();
    print('✅ تم تهيئة معالج الإشعارات بنجاح');
  } catch (e) {
    print('⚠️ خطأ في معالج الإشعارات: $e');
  }

  // ✅ 5. بدء مراقبة الإشعارات المعلقة
  try {
    PendingNotificationsService().startMonitoring();
    Timer.periodic(const Duration(days: 1), (timer) {
      PendingNotificationsService().cleanOldNotifications();
    });
    print('✅ تم بدء مراقبة الإشعارات المعلقة');
  } catch (e) {
    print('⚠️ خطأ في مراقبة الإشعارات: $e');
  }

  print('✅ تم تهيئة التطبيق بنجاح');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      navigatorKey: NotificationHandler().navigatorKey,
      title: 'ChatApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const SplashScreen(),
    );
  }
}