// lib/screens/login_screen.dart

import 'package:ChatApp/Animation/RouteAnimation.dart';
import 'package:ChatApp/Provider/network_provider.dart';
import 'package:ChatApp/Provider/userProvide.dart';
import 'package:ChatApp/Screen/main_app_shell.dart';
import 'package:ChatApp/model/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {

  // ✅ Login Controllers
  final loginPhoneController = TextEditingController();
  final loginPasswordController = TextEditingController();

  // ✅ Register Controllers
  final registerNameController = TextEditingController();
  final registerPhoneController = TextEditingController();
  final registerEmailController = TextEditingController();
  final registerPasswordController = TextEditingController();
  final registerConfirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isLoginMode = true;

  @override
  void dispose() {
    loginPhoneController.dispose();
    loginPasswordController.dispose();
    registerNameController.dispose();
    registerPhoneController.dispose();
    registerEmailController.dispose();
    registerPasswordController.dispose();
    registerConfirmPasswordController.dispose();
    super.dispose();
  }

  // ✅ حفظ المستخدم داخل Riverpod
  void _setUser(AppUser user) {
    ref.read(appUserDataProvider.notifier).state = user;
    ref.read(appUserPhoneProvider.notifier).state = user.phone;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ✅ تسجيل الدخول عبر Google
  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.loginWithGoogle();

      if (user != null && mounted) {
        _setUser(user);
        _showSuccess("تم تسجيل الدخول عبر Google ✅");

        Navigator.pushAndRemoveUntil(
          context,
          RouteAnimation.slideFromRight(const MainAppShell()),
              (route) => false,
        );
      } else {
        _showError("فشل تسجيل الدخول عبر Google");
      }
    } catch (e) {
      _showError("حدث خطأ: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ تسجيل الدخول عبر LinkedIn
  Future<void> _handleLinkedInLogin() async {
    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.loginWithLinkedIn(context);

      if (user != null && mounted) {
        _setUser(user);
        _showSuccess("تم تسجيل الدخول عبر LinkedIn ✅");

        Navigator.pushAndRemoveUntil(
          context,
          RouteAnimation.slideFromRight(const MainAppShell()),
              (route) => false,
        );
      } else {
        _showError("فشل تسجيل الدخول عبر LinkedIn");
      }
    } catch (e) {
      _showError("حدث خطأ: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ تسجيل الدخول بالهاتف وكلمة المرور
  Future<void> _handleLogin() async {
    final phone = loginPhoneController.text.trim();
    final password = loginPasswordController.text.trim();

    if (phone.isEmpty) {
      _showError('الرجاء إدخال رقم الهاتف');
      return;
    }

    if (password.isEmpty) {
      _showError('الرجاء إدخال كلمة المرور');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.loginWithPhoneAsKey(phone, password);

      if (user != null && mounted) {
        _setUser(user);
        _showSuccess('تم تسجيل الدخول بنجاح ✅');

        Navigator.pushAndRemoveUntil(
          context,
          RouteAnimation.slideFromRight(const MainAppShell()),
              (route) => false,
        );
      } else {
        _showError('بيانات غير صحيحة');
      }
    } catch (e) {
      _showError('حدث خطأ: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ إنشاء حساب جديد
  Future<void> _handleRegister() async {
    final name = registerNameController.text.trim();
    final phone = registerPhoneController.text.trim();
    final email = registerEmailController.text.trim();
    final password = registerPasswordController.text.trim();
    final confirmPassword = registerConfirmPasswordController.text.trim();

    if (name.isEmpty) {
      _showError('الرجاء إدخال الاسم');
      return;
    }

    if (phone.isEmpty) {
      _showError('الرجاء إدخال رقم الهاتف');
      return;
    }

    if (email.isEmpty) {
      _showError('الرجاء إدخال البريد الإلكتروني');
      return;
    }

    if (password.length < 6) {
      _showError('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }

    if (password != confirmPassword) {
      _showError('كلمة المرور غير متطابقة');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.registerWithPhoneAsKey(
        phone,
        email,
        password,
        name,
      );

      if (user != null && mounted) {
        _setUser(user);
        _showSuccess('تم إنشاء الحساب بنجاح ✅');

        Navigator.pushAndRemoveUntil(
          context,
          RouteAnimation.slideFromRight(const MainAppShell()),
              (route) => false,
        );
      } else {
        _showError('فشل إنشاء الحساب');
      }
    } catch (e) {
      _showError('حدث خطأ: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = ref.watch(internetConnectionProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF2196F3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 10,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ✅ الأيقونة
                      const Icon(Icons.chat, size: 60, color: Colors.green),
                      const SizedBox(height: 12),

                      Text(
                        _isLoginMode ? "تسجيل الدخول" : "إنشاء حساب",
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ✅ حقول النص (تسجيل دخول أو تسجيل)
                      if (_isLoginMode) ...[
                        _buildPhoneField(loginPhoneController, "رقم الهاتف", Icons.phone),
                        const SizedBox(height: 12),
                        _buildPasswordField(loginPasswordController),
                      ] else ...[
                        _buildTextField(registerNameController, "الاسم", Icons.person),
                        const SizedBox(height: 12),
                        _buildPhoneField(registerPhoneController, "رقم الهاتف", Icons.phone),
                        const SizedBox(height: 12),
                        _buildTextField(registerEmailController, "البريد الإلكتروني", Icons.email),
                        const SizedBox(height: 12),
                        _buildPasswordField(registerPasswordController),
                        const SizedBox(height: 12),
                        _buildPasswordField(registerConfirmPasswordController, label: "تأكيد كلمة المرور"),
                      ],

                      const SizedBox(height: 20),

                      // ✅ زر رئيسي (دخول / إنشاء حساب)
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : (_isLoginMode ? _handleLogin : _handleRegister),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(
                            _isLoginMode ? "دخول" : "إنشاء حساب",
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ✅ الفاصل (أو)
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'أو',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ✅ أزرار تسجيل الدخول عبر Google و LinkedIn
                      Row(
                        children: [
                          Expanded(
                            child: _buildSocialButton(
                              icon: Icons.g_mobiledata,
                              label: 'Google',
                              color: Colors.red,
                              backgroundColor: Colors.white,
                              borderColor: Colors.grey.shade300,
                              onPressed: _isLoading ? null : _handleGoogleLogin,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildSocialButton(
                              icon: Icons.work_outline,
                              label: 'LinkedIn',
                              color: Colors.blue.shade700,
                              backgroundColor: Colors.white,
                              borderColor: Colors.grey.shade300,
                              onPressed: _isLoading ? null : _handleLinkedInLogin,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 15),

                      // ✅ نص التبديل بين تسجيل الدخول والتسجيل
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                          setState(() {
                            _isLoginMode = !_isLoginMode;
                          });
                        },
                        child: Text(
                          _isLoginMode
                              ? "ليس لديك حساب؟ إنشاء حساب"
                              : "لديك حساب؟ تسجيل الدخول",
                        ),
                      ),

                      // ✅ حالة الاتصال
                      if (!isConnected)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            "⚠ لا يوجد اتصال بالإنترنت",
                            style: TextStyle(color: Colors.red),
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

  // ✅ زر تسجيل الدخول الاجتماعي
  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color backgroundColor,
    required Color borderColor,
    VoidCallback? onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: backgroundColor,
        side: BorderSide(color: borderColor),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),

        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
    );
  }
  Widget _buildPhoneField(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),

        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
    );
  }

  Widget _buildPasswordField(TextEditingController controller, {String label = "كلمة المرور"}) {
    return TextField(
      controller: controller,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.lock),
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        suffixIcon: IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
      ),
    );
  }
}