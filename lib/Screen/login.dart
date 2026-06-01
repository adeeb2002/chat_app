// lib/screens/login_screen.dart

import 'dart:async';
import 'package:ChatApp/Animation/RouteAnimation.dart';
import 'package:ChatApp/Provider/network_provider.dart';
import 'package:ChatApp/Provider/userProvide.dart';
import 'package:ChatApp/Screen/main_app_shell.dart';
import 'package:ChatApp/model/user.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../service/hash_service.dart';

import '../Combonant/login/LoginWidget.dart';
import '../Combonant/login/RegisterWidget.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {

  // Controllers for Login
  final loginPhoneController = TextEditingController();
  final loginPasswordController = TextEditingController();

  // Controllers for Register
  final registerNameController = TextEditingController();
  final registerPhoneController = TextEditingController();
  final registerPasswordController = TextEditingController();
  final registerConfirmPasswordController = TextEditingController();

  // Controllers for Forgot Password
  final forgotPhoneController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmNewPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isLoginMode = true; // true = Login, false = Register
  bool _isForgotPasswordMode = false;
  bool _isVerifyingPhone = false;
  bool _phoneVerified = false;
  String? _verifiedUserEmail;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    loginPhoneController.dispose();
    loginPasswordController.dispose();
    registerNameController.dispose();
    registerPhoneController.dispose();
    registerPasswordController.dispose();
    registerConfirmPasswordController.dispose();
    forgotPhoneController.dispose();
    newPasswordController.dispose();
    confirmNewPasswordController.dispose();
    super.dispose();
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _saveUserSession(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLogin', true);
    await prefs.setString('phone', user.phone);
    await prefs.setString('userEmail', user.email ?? '');
    await prefs.setString('userId', user.id ?? '');
    await prefs.setString('userName', user.displayName);

    ref.read(appUserDataProvider.notifier).state = user;
    ref.read(appUserPhoneProvider.notifier).state = user.phone;
  }

  Future<void> _handleLogin() async {
    if (!_isLoginMode) return;

    final phone = loginPhoneController.text.trim();
    final password = loginPasswordController.text.trim();

    if (phone.isEmpty) {
      _showErrorSnackBar('الرجاء إدخال رقم الهاتف');
      return;
    }
    if (password.isEmpty) {
      _showErrorSnackBar('الرجاء إدخال كلمة المرور');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.login(phone, password, context);

      if (user != null && mounted) {
        await _saveUserSession(user);
        final isLoggedIn = await authService.checkLogin();

        if (isLoggedIn && mounted) {
          _showSuccessSnackBar('تم تسجيل الدخول بنجاح');
          Navigator.pushAndRemoveUntil(
            context,
            RouteAnimation.slideFromRight(MainAppShell()),
            (route) => false,
          );
        } else {
          _showErrorSnackBar('فشل تسجيل الدخول. تحقق من بياناتك');
        }
      } else {
        _showErrorSnackBar('فشل تسجيل الدخول. تحقق من بياناتك');
      }
    } catch (e) {
      _showErrorSnackBar('حدث خطأ: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRegister() async {
    if (_isLoginMode) return;

    final name = registerNameController.text.trim();
    final phone = registerPhoneController.text.trim();
    final password = registerPasswordController.text.trim();
    final confirmPassword = registerConfirmPasswordController.text.trim();

    if (name.isEmpty) {
      _showErrorSnackBar('الرجاء إدخال الاسم');
      return;
    }
    if (phone.isEmpty) {
      _showErrorSnackBar('الرجاء إدخال رقم الهاتف');
      return;
    }
    if (password.isEmpty) {
      _showErrorSnackBar('الرجاء إدخال كلمة المرور');
      return;
    }
    if (password.length < 6) {
      _showErrorSnackBar('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }
    if (password != confirmPassword) {
      _showErrorSnackBar('كلمة المرور غير متطابقة');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.register(phone, password, context);

      if (user != null && mounted && user.id != null) {
        await FirebaseDatabase.instance
            .ref('users')
            .child(user.id!)
            .update({'displayName': name});

        final updatedUser = AppUser(
          id: user.id,
          email: user.email,
          phone: phone,
          displayName: name,
          isOnline: true,
          lastSeen: DateTime.now().millisecondsSinceEpoch,
        );
        await _saveUserSession(updatedUser);

        final isLoggedIn = await authService.checkLogin();
        if (isLoggedIn && mounted) {
          _showSuccessSnackBar('تم إنشاء الحساب بنجاح');
          Navigator.pushAndRemoveUntil(
            context,
            RouteAnimation.slideFromRight(MainAppShell()),(route) => false,
          );
        }
      } else {
        _showErrorSnackBar('فشل إنشاء الحساب. حاول مرة أخرى');
      }
    } catch (e) {
      _showErrorSnackBar('حدث خطأ: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyPhoneNumber() async {
    final phone = forgotPhoneController.text.trim();
    if (phone.isEmpty) {
      _showErrorSnackBar('الرجاء إدخال رقم الهاتف');
      return;
    }

    setState(() => _isVerifyingPhone = true);

    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('users')
          .orderByChild('phone')
          .equalTo(phone)
          .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        if (data.isNotEmpty) {
          final entry = data.entries.first;
          final userData = Map<String, dynamic>.from(entry.value);

          setState(() {
            _phoneVerified = true;
            _verifiedUserEmail = userData['email'];
          });

          _showSuccessSnackBar('تم التحقق من رقم الهاتف بنجاح');
        } else {
          _showErrorSnackBar('لا يوجد حساب مرتبط بهذا الرقم');
        }
      } else {
        _showErrorSnackBar('لا يوجد حساب مرتبط بهذا الرقم');
      }
    } catch (e) {
      _showErrorSnackBar('حدث خطأ أثناء التحقق: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isVerifyingPhone = false);
    }
  }

  Future<void> _resetPassword() async {
    final newPassword = newPasswordController.text.trim();
    final confirmPassword = confirmNewPasswordController.text.trim();
    final phone = forgotPhoneController.text.trim();

    if (newPassword.isEmpty) {
      _showErrorSnackBar('الرجاء إدخال كلمة المرور الجديدة');
      return;
    }
    if (newPassword.length < 3) {
      _showErrorSnackBar('كلمة المرور يجب أن تكون 3 أحرف على الأقل');
      return;
    }
    if (newPassword != confirmPassword) {
      _showErrorSnackBar('كلمة المرور غير متطابقة');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('users')
          .orderByChild('phone')
          .equalTo(phone)
          .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        if (data.isNotEmpty) {
          final entry = data.entries.first;
          final userId = entry.key.toString();

          await FirebaseDatabase.instance
              .ref('users')
              .child(userId)
              .update({
            'password': HashService.hashPassword(newPassword),
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          });

          _showSuccessSnackBar('تم تغيير كلمة المرور بنجاح');

          setState(() {
            _isForgotPasswordMode = false;
            _phoneVerified = false;
            _verifiedUserEmail = null;
            forgotPhoneController.clear();
            newPasswordController.clear();
            confirmNewPasswordController.clear();
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('حدث خطأ أثناء تغيير كلمة المرور: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _backToLogin() {
    setState(() {
      _isForgotPasswordMode = false;
      _phoneVerified = false;
      _verifiedUserEmail = null;
      forgotPhoneController.clear();
      newPasswordController.clear();
      confirmNewPasswordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = ref.watch(internetConnectionProvider);

    if (_isForgotPasswordMode) {
      return _buildForgotPasswordScreen();
    }

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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ✅ الأيقونة
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: _isLoginMode ? 80 : 65,
                        height: _isLoginMode ? 80 : 65,
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isLoginMode ? Icons.chat_bubble : Icons.person_add,
                          size: _isLoginMode ? 50 : 40,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 15),

                      // ✅ العنوان
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _isLoginMode ? 'مرحباً بك في تطبيق المحادثات' : 'إنشاء حساب جديد',
                          key: ValueKey<bool>(_isLoginMode),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isLoginMode ? 'سجل الدخول للاستمرار' : 'قم بملء البيانات للتسجيل',
                        style: const TextStyle(color: Colors.grey, fontSize: 14,
                          fontWeight: FontWeight.bold,),
                      ),
                      const SizedBox(height: 25),

                      // ✅ عرض Widget تسجيل الدخول أو إنشاء الحساب
                      _isLoginMode
                          ? LoginWidget(
                        phoneController: loginPhoneController,
                        passwordController: loginPasswordController,
                        obscurePassword: _obscurePassword,
                        onToggleVisibility: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                        onForgotPassword: () {
                          setState(() => _isForgotPasswordMode = true);
                        },
                      )
                          : RegisterWidget(
                        nameController: registerNameController,
                        phoneController: registerPhoneController,
                        passwordController: registerPasswordController,
                        confirmPasswordController: registerConfirmPasswordController,
                        obscurePassword: _obscurePassword,
                        onToggleVisibility: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),

                      const SizedBox(height: 16),

                      // ✅ زر التحكم الرئيسي
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : (_isLoginMode ? _handleLogin : _handleRegister),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : Text(
                            _isLoginMode ? 'تسجيل الدخول' : 'إنشاء حساب',
                            style: const TextStyle(fontSize: 18,
                              fontWeight: FontWeight.bold,),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ✅ نص التبديل بين تسجيل الدخول والتسجيل
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_isLoginMode ? 'ليس لديك حساب؟' : 'لديك حساب بالفعل؟'),
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                              setState(() {
                                _isLoginMode = !_isLoginMode;
                              });
                            },
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                _isLoginMode ? 'إنشاء حساب جديد' : 'تسجيل الدخول',
                                key: ValueKey<bool>(_isLoginMode),
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // ✅ عرض حالة الاتصال
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
                                  style: TextStyle(fontSize: 12, color: Colors.orange[700],
                                    fontWeight: FontWeight.bold,),
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
    );
  }

  // ✅ شاشة نسيت كلمة السر
  Widget _buildForgotPasswordScreen() {
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_reset,
                          size: 40,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        'نسيت كلمة المرور',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _phoneVerified
                            ? 'قم بإدخال كلمة المرور الجديدة'
                            : 'أدخل رقم هاتفك لإعادة تعيين كلمة المرور',
                        style: const TextStyle(color: Colors.grey, fontSize: 14,
                          fontWeight: FontWeight.bold,),
                      ),
                      const SizedBox(height: 25),

                      if (!_phoneVerified) ...[
                        TextFormField(
                          controller: forgotPhoneController,
                          keyboardType: TextInputType.phone,
                          enabled: !_isVerifyingPhone && !_isLoading,
                          decoration: InputDecoration(
                            labelText: 'رقم الهاتف',
                            hintText: '0590000000',
                            prefixIcon: const Icon(Icons.phone, color: Colors.orange),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (_phoneVerified && _verifiedUserEmail != null && _verifiedUserEmail!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.email, size: 20, color: Colors.blue),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'البريد الإلكتروني المرتبط',
                                      style: TextStyle(fontSize: 12, color: Colors.blue,
                                        fontWeight: FontWeight.bold,),
                                    ),
                                    Text(
                                      _verifiedUserEmail!,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (_phoneVerified && (_verifiedUserEmail == null || _verifiedUserEmail!.isEmpty))
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 20, color: Colors.orange),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'لا يوجد بريد إلكتروني مرتبط بهذا الرقم، يمكنك تغيير كلمة المرور مباشرة',
                                  style: TextStyle(fontSize: 12, color: Colors.orange[700],
                                    fontWeight: FontWeight.bold,),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),

                      if (_phoneVerified) ...[
                        TextFormField(
                          controller: newPasswordController,
                          obscureText: _obscurePassword,
                          enabled: !_isLoading,
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور الجديدة',
                            hintText: '********',
                            prefixIcon: const Icon(Icons.lock, color: Colors.orange),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: confirmNewPasswordController,
                          obscureText: _obscurePassword,
                          enabled: !_isLoading,
                          decoration: InputDecoration(
                            labelText: 'تأكيد كلمة المرور الجديدة',
                            hintText: '********',
                            prefixIcon: const Icon(Icons.lock_outline, color: Colors.orange),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : (_phoneVerified ? _resetPassword : _verifyPhoneNumber),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _phoneVerified ? Colors.green : Colors.orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: _isLoading || _isVerifyingPhone
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : Text(
                            _phoneVerified ? 'تغيير كلمة المرور' : 'التحقق من الرقم',
                            style: const TextStyle(fontSize: 18,
                              fontWeight: FontWeight.bold,),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: _isLoading ? null : _backToLogin,
                            child: Row(
                              children: [
                                const Icon(Icons.arrow_back, size: 16),
                                const SizedBox(width: 4),
                                const Text('العودة إلى تسجيل الدخول'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
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