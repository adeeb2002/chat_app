// lib/widgets/register_widget.dart

import 'package:flutter/material.dart';

class RegisterWidget extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool obscurePassword;
  final VoidCallback onToggleVisibility;
  final bool isLoading;

  const RegisterWidget({
    super.key,
    required this.nameController,
    required this.phoneController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.obscurePassword,
    required this.onToggleVisibility,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // حقل الاسم
        TextFormField(
          controller: nameController,
          enabled: !isLoading,
          decoration: InputDecoration(
            labelText: 'الاسم',
            hintText: 'أدخل اسمك الكامل',
            prefixIcon: const Icon(Icons.person, color: Colors.green),
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
              return 'الرجاء إدخال الاسم';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

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
        const SizedBox(height: 16),

        // حقل تأكيد كلمة المرور
        TextFormField(
          controller: confirmPasswordController,
          obscureText: obscurePassword,
          enabled: !isLoading,
          decoration: InputDecoration(
            labelText: 'تأكيد كلمة المرور',
            hintText: '********',
            prefixIcon: const Icon(Icons.lock_outline, color: Colors.green),
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
              return 'الرجاء تأكيد كلمة المرور';
            }
            if (value != passwordController.text) {
              return 'كلمة المرور غير متطابقة';
            }
            return null;
          },
        ),
      ],
    );
  }
}