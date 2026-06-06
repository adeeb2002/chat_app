// lib/widgets/login_widget.dart

import 'package:flutter/material.dart';

class LoginWidget extends StatelessWidget {
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onToggleVisibility;
  final VoidCallback onForgotPassword;
  final bool isLoading;

  const LoginWidget({
    super.key,
    required this.phoneController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onToggleVisibility,
    required this.onForgotPassword,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // حقل رقم الهاتف
        TextFormField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          enabled: !isLoading,
          decoration: InputDecoration(
            labelText: 'رقم الهاتف',
            hintText: '0590000000',
            prefixIcon: const Icon(Icons.phone, color: Colors.green),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Colors.green, width: 2),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء إدخال رقم الهاتف';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // حقل كلمة المرور
        TextFormField(
          controller: passwordController,
          obscureText: obscurePassword,
          enabled: !isLoading,
          decoration: InputDecoration(
            labelText: 'كلمة المرور',
            hintText: '********',
            prefixIcon: const Icon(Icons.lock, color: Colors.green),
            suffixIcon: IconButton(
              icon: Icon(
                obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey,
              ),
              onPressed: onToggleVisibility,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Colors.green, width: 2),
            ),
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
        const SizedBox(height: 8),

        // زر نسيت كلمة المرور
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: isLoading ? null : onForgotPassword,
            style: TextButton.styleFrom(
              foregroundColor: Colors.orange,
            ),
            child: const Text(
              'نسيت كلمة المرور؟',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }
}