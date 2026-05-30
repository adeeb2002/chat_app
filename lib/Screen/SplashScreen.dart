// lib/screens/splash_simple.dart

import 'dart:async';
import 'package:ChatApp/Animation/RouteAnimation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Provider/userProvide.dart';
import 'home.dart';
import 'login.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _controller.forward();

    _initApp();
  }

  Future<void> _initApp() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isLogin') ?? false;
      final userPhone = prefs.getString('phone');
      final userId = prefs.getString('userId');

      // ✅ تصحيح حالة المستخدم عند بدء التطبيق
      if (isLoggedIn && userPhone != null && userId != null) {
        final authService = ref.read(authServiceProvider);

        // ✅ تعيين المستخدم كـ "غير متصل" مؤقتاً
        await authService.updateUserStatus(userId, false);

        // ✅ بعد ثانيتين، إذا كان هناك اتصال، قم بتعيينه كـ "متصل"
        Future.delayed(const Duration(seconds: 2), () {
          if (authService.isConnected) {
            authService.updateUserStatus(userId, true);
          }
        });
      }

      if (mounted) {
        if (isLoggedIn && userPhone != null && userPhone.isNotEmpty) {
          Navigator.pushAndRemoveUntil(
            context,
            RouteAnimation.slideFromRight(HomeScreen()),
            (route) => false,
          );
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            RouteAnimation.slideRightAndFade(LoginScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      print('❌ [Splash] خطأ: $e');
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          RouteAnimation.slideRightAndFade(LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF075E54), Color(0xFF25D366)],
          ),
        ),
        child: Center(
          child: ScaleTransition(
            scale: _animation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chat_bubble,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  'ChatApp',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 15),
                Container(
                  width: 50,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'تواصل بكل سهولة',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontWeight: FontWeight.bold
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}