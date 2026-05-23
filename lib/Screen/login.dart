import 'dart:async';

import 'package:ChatApp/Provider/userProvide.dart';
import 'package:ChatApp/Screen/home.dart';
import 'package:ChatApp/model/user.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isRegisterMode = false;

  bool isConnected = false;
  StreamSubscription? connectionSubscription;

  @override
  void initState() {
    super.initState();
    connectionSubscription = InternetConnection().onStatusChange.listen((status) async {
      final hasConnection = status == InternetStatus.connected;

      if (isConnected != hasConnection) {
        if (mounted) {
          setState(() {
            isConnected = hasConnection;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    connectionSubscription?.cancel();
    super.dispose();
  }

  // ✅ حفظ جلسة المستخدم
  Future<void> _saveUserSession(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLogin', true);
    await prefs.setString('phone', user.phone); // ✅ تخزين رقم الهاتف
    await prefs.setString('userEmail', user.email ?? '');
    await prefs.setString('userId', user.id ?? '');
    await prefs.setString('userName', user.displayName);

    ref.read(appUserDataProvider.notifier).state = user;
    ref.read(appUserPhoneProvider.notifier).state = user.phone; // ✅ استخدام رقم الهاتف
  }

  // ✅ دالة التحقق من الاتصال
  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;

    // ✅ تصحيح: إذا كان لا يوجد اتصال، أظهر رسالة
    if (!isConnected) {
      _showSnackBar('لا يوجد اتصال بالإنترنت، تأكد من اتصالك');
      return;
    }

    if (_isRegisterMode) {
      _handleRegister(
        nameController.text.trim(),
        phoneController.text.trim(),
        passwordController.text.trim(),
      );
    } else {
      _handleLogin();
    }
  }

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.login(
        phoneController.text.trim(),
        passwordController.text.trim(),
        context,
      );

      if (user != null && mounted) {
        await _saveUserSession(user);
        final isLoggedIn = await authService.checkLogin();

        if (isLoggedIn && mounted) {
          _showSnackBar('تم تسجيل الدخول بنجاح', isError: false);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        } else {
          _showSnackBar('فشل تسجيل الدخول. تحقق من بياناتك');
        }
      } else {
        _showSnackBar('فشل تسجيل الدخول. تحقق من بياناتك');
      }
    } catch (e) {
      _showSnackBar('حدث خطأ: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRegister(String displayName, String phone, String password) async {
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.register(phone, password, context);

      if (user != null && mounted) {
        if (displayName.isNotEmpty) {
          await FirebaseDatabase.instance
              .ref('users')
              .child(user.id!)
              .update({'displayName': displayName.trim()}); // ✅ استخدام displayName

          final updatedUser = AppUser(
            id: user.id,
            email: user.email,
            phone: phone,
            displayName: displayName.trim(),
            isOnline: true,
            lastSeen: DateTime.now().millisecondsSinceEpoch,
          );
          await _saveUserSession(updatedUser);
        } else {
          await _saveUserSession(user);
        }

        final isLoggedIn = await authService.checkLogin();
        if (isLoggedIn && mounted) {
          _showSnackBar('تم إنشاء الحساب بنجاح', isError: false);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      } else {
        _showSnackBar('فشل إنشاء الحساب. حاول مرة أخرى');
      }
    } catch (e) {
      _showSnackBar('حدث خطأ: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4CAF50), Color(0xFF2196F3)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // الأيقونة
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: _isRegisterMode ? 65 : 80,
                          height: _isRegisterMode ? 65 : 80,
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isRegisterMode ? Icons.person_add : Icons.chat_bubble,
                            size: _isRegisterMode ? 40 : 50,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 15),

                        // العنوان
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _isRegisterMode ? 'إنشاء حساب جديد' : 'مرحباً بك في تطبيق المحادثات',
                            key: ValueKey<bool>(_isRegisterMode),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isRegisterMode ? 'قم بملء البيانات للتسجيل' : 'سجل الدخول للاستمرار',
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        const SizedBox(height: 25),

                        // ✅ حقل الاسم (يظهر في وضع التسجيل فقط)
                        if (_isRegisterMode) ...[
                          TextFormField(
                            controller: nameController,
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              labelText: 'الاسم',
                              hintText: 'أدخل اسمك الكامل',
                              prefixIcon: const Icon(Icons.person, color: Colors.green),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                            validator: (value) {
                              if (_isRegisterMode && (value == null || value.isEmpty)) {
                                return 'الرجاء إدخال الاسم';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ✅ حقل رقم الهاتف (بدون maxLength)
                        TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          enabled: !_isLoading,
                          decoration: InputDecoration(
                            labelText: 'رقم الهاتف',
                            hintText: '0590000000 أو +970590000000',
                            prefixIcon: const Icon(Icons.phone, color: Colors.green),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                            helperText: 'أدخل رقم الهاتف بصيغة 059xxxxxxx أو +97059xxxxxxx',
                            helperMaxLines: 2,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'الرجاء إدخال رقم الهاتف';
                            }
                            // ✅ تنظيف الرقم من المسافات
                            final cleanPhone = value.trim().replaceAll(' ', '');

                            // ✅ التحقق من صحة الرقم
                            if (cleanPhone.startsWith('+')) {
                              if (cleanPhone.length < 12) {
                                return 'رقم الهاتف غير صالح (يجب أن يكون 12 رقم على الأقل مع +)';
                              }
                            } else {
                              if (cleanPhone.length < 10) {
                                return 'رقم الهاتف غير صالح (يجب أن يكون 10 أرقام على الأقل)';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // حقل كلمة المرور
                        TextFormField(
                          controller: passwordController,
                          obscureText: _obscurePassword,
                          enabled: !_isLoading,
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            hintText: '********',
                            prefixIcon: const Icon(Icons.lock, color: Colors.green),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'الرجاء إدخال كلمة المرور';
                            }
                            if (value.length < 6) {
                              return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // حقل تأكيد كلمة المرور (يظهر في وضع التسجيل فقط)
                        if (_isRegisterMode) ...[
                          TextFormField(
                            controller: confirmPasswordController,
                            obscureText: _obscurePassword,
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              labelText: 'تأكيد كلمة المرور',
                              hintText: '********',
                              prefixIcon: const Icon(Icons.lock_outline, color: Colors.green),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                            validator: (value) {
                              if (_isRegisterMode && (value == null || value.isEmpty)) {
                                return 'الرجاء تأكيد كلمة المرور';
                              }
                              if (_isRegisterMode && value != passwordController.text) {
                                return 'كلمة المرور غير متطابقة';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                        ],

                        // نسيت كلمة المرور
                        if (!_isRegisterMode)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: _isLoading ? null : () => _showSnackBar('سيتم إرسال رابط إعادة تعيين كلمة المرور'),
                              child: const Text('نسيت كلمة المرور؟'),
                            ),
                          ),
                        const SizedBox(height: 10),

                        // ✅ زر التحكم الرئيسي
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                                : AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                _isRegisterMode ? 'إنشاء حساب' : 'تسجيل الدخول',
                                key: ValueKey<bool>(_isRegisterMode),
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ✅ نص التبديل بين تسجيل الدخول والتسجيل
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_isRegisterMode ? 'لديك حساب بالفعل؟' : 'ليس لديك حساب؟'),
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                setState(() {
                                  _isRegisterMode = !_isRegisterMode;
                                  // ✅ تنظيف حقول الأخطاء عند التبديل
                                  _formKey.currentState?.reset();
                                });
                              },
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Text(
                                  _isRegisterMode ? 'تسجيل الدخول' : 'إنشاء حساب جديد',
                                  key: ValueKey<bool>(_isRegisterMode),
                                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // ✅ عرض حالة الاتصال في الأسفل
                        if (!isConnected)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.orange[200]!),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.wifi_off, size: 16, color: Colors.orange[700]),
                                  const SizedBox(width: 8),
                                  Text(
                                    'لا يوجد اتصال بالإنترنت',
                                    style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}