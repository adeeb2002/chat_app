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

    // ─── أنيميشن الأيقونة (تظهر من المركز مع دوران) ───
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

    // ─── أنيميشن النص (يظهر من الأسفل) ───
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

    // ─── أنيميشن الخط الفاصل (يتوسع) ───
    _dotController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _dotWidth = Tween<double>(begin: 0.0, end: 60.0).animate(
      CurvedAnimation(parent: _dotController, curve: Curves.easeOutCubic),
    );

    // ─── تشغيل الأنيميشنات بالتتابع ───
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
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isLogin') ?? false;
      final userPhone = prefs.getString('phone');
      final userId = prefs.getString('userId');

      if (isLoggedIn && userPhone != null && userId != null) {
        final authService = ref.read(authServiceProvider);
        await authService.updateUserStatus(userId, false);

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
            RouteAnimation.slideFromRight(const HomeScreen()),
            (route) => false,
          );
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            RouteAnimation.slideRightAndFade(const LoginScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          RouteAnimation.slideRightAndFade(const LoginScreen()),
          (route) => false,
        );
      }
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

              // ─── الأيقونة ───
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

              // ─── اسم التطبيق ───
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

              // ─── الخط الفاصل ───
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

              // ─── الشعار ───
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

              // ─── مؤشر التحميل ───
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
