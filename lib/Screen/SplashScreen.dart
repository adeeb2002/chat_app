import 'dart:async';
import 'package:ChatApp/Animation/RouteAnimation.dart';
import 'package:ChatApp/Provider/network_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Provider/userProvide.dart';
import '../model/user.dart';
import '../service/NetworkOptimizationService.dart';
import 'main_app_shell.dart';
import 'loginScreen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _iconController;
  late AnimationController _textController;
  late AnimationController _dotController;

  late Animation<double> _iconScale;
  late Animation<double> _iconRotation;
  late Animation<Offset> _textSlide;
  late Animation<double> _textFade;
  late Animation<double> _dotWidth;

  @override
  void initState() {
    super.initState();

    _iconController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.elasticOut),
    );

    _iconRotation = Tween<double>(begin: -0.5, end: 0.0).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.easeOutBack),
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );

    _dotController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _dotWidth = Tween<double>(begin: 0.0, end: 60.0).animate(
      CurvedAnimation(parent: _dotController, curve: Curves.easeOutCubic),
    );

    _startAnimations();
    _initApp();
  }

  Future<void> _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _iconController.forward();

    await Future.delayed(const Duration(milliseconds: 600));
    _textController.forward();

    await Future.delayed(const Duration(milliseconds: 300));
    _dotController.forward();
  }

  Future<void> _initApp() async {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🚀 بدء تهيئة التطبيق في SplashScreen');

    // ✅ الانتظار لإظهار الـ Animation
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    try {
      // ✅ 1. قراءة البيانات المحلية أولاً
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isLogin') ?? false;
      final userPhone = prefs.getString('phone');
      final userId = prefs.getString('userId');
      final userName = prefs.getString('userName');
      final userEmail = prefs.getString('userEmail');

      print('📱 البيانات المحلية:');
      print('   - isLoggedIn: $isLoggedIn');
      print('   - userPhone: $userPhone');

      if (!isLoggedIn || userPhone == null || userId == null) {
        print('⚠️ المستخدم غير مسجل، الانتقال إلى LoginScreen');
        _navigateToLogin();
        return;
      }

      // ✅ 2. إنشاء كائن المستخدم من البيانات المحلية
      final localUser = AppUser(
        id: userId,
        phone: userPhone,
        email: userEmail,
        displayName: userName ?? userPhone,
        isOnline: false,
      );

      ref.read(appUserDataProvider.notifier).state = localUser;
      ref.read(appUserPhoneProvider.notifier).state = userPhone;

      print('✅ تم تحميل بيانات المستخدم من الذاكرة المحلية');

      // ✅ 3. التحقق من حالة الاتصال
      final networkService = NetworkOptimizationService();
      final isOnline = networkService.isConnected;
      final isSlowConnection = networkService.isSlowConnection;

      print('🌐 حالة الاتصال: ${isOnline ? "متصل" : "غير متصل"}');
      if (isSlowConnection) {
        print('🐌 اتصال بطيء - تم تفعيل الوضع الموفر');
      }

      // ✅ 4. إذا كان متصلاً، تحديث الحالة (مع Timeout)
      if (isOnline) {
        try {
          print('🔄 تحديث حالة المستخدم...');
          final authService = ref.read(authServiceProvider);

          // ✅ استخدام NetworkOptimizationService للتحكم
          await networkService.executeRequest(
                () async => authService.setupPresence(userId),
            debugName: 'setupPresence',
            priority: true,
          );

          // ✅ جلب أحدث بيانات (فقط إذا الاتصال جيد)
          if (!isSlowConnection) {
            final freshUser = await networkService.executeRequest(
                  () => authService.getUserByPhone(userPhone),
              debugName: 'getUserByPhone',
            );

            if (freshUser != null && mounted) {
              ref.read(appUserDataProvider.notifier).state =
                  freshUser.copyWith(isOnline: true);
              print('✅ تم تحديث بيانات المستخدم من Firebase');
            }
          }
        } catch (e) {
          print('⚠️ تعذر الاتصال بـ Firebase: $e');
          print('✅ الاستمرار في الوضع Offline');
        }
      } else {
        print('📴 الاستمرار في الوضع Offline');
      }

      // ✅ 5. الانتقال إلى الشاشة الرئيسية
      if (mounted) {
        print('✅ الانتقال إلى MainAppShell');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        Navigator.pushAndRemoveUntil(
          context,
          RouteAnimation.slideFromRight(const MainAppShell()),
              (route) => false,
        );
      }
    } catch (e) {
      print('❌ خطأ في تهيئة التطبيق: $e');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      if (mounted) {
        _navigateToLogin();
      }
    }
  }

  void _navigateToLogin() {
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        RouteAnimation.slideRightAndFade(const LoginScreen()),
            (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _iconController.dispose();
    _textController.dispose();
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF075E54),
              Color(0xFF128C7E),
              Color(0xFF25D366),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),

              AnimatedBuilder(
                animation: _iconController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _iconScale.value,
                    child: Transform.rotate(
                      angle: _iconRotation.value,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                    ),
                    child: const Icon(
                      Icons.chat_rounded,
                      size: 65,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              SlideTransition(
                position: _textSlide,
                child: FadeTransition(
                  opacity: _textFade,
                  child: const Text(
                    'ChatApp',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              AnimatedBuilder(
                animation: _dotController,
                builder: (context, child) {
                  return Container(
                    width: _dotWidth.value,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              SlideTransition(
                position: _textSlide,
                child: FadeTransition(
                  opacity: _textFade,
                  child: Text(
                    'تواصل بكل سهولة',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.85),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 3),

              FadeTransition(
                opacity: _textFade,
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}