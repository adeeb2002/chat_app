import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../Provider/instagram/instagram_providers.dart';

class InstagramLoginButton extends ConsumerWidget {
  const InstagramLoginButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(instagramAuthProvider);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Logo & Title
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF833AB4),
                Color(0xFFFD1D1D),
                Color(0xFFF77737),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: const Icon(
            Icons.camera_alt_rounded,
            color: Colors.white,
            size: 52,
          ),
        ),

        const SizedBox(height: 28),

        Text(
          'Instagram',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'سجّل الدخول لعرض حسابك',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.grey[600],
          ),
          textDirection: TextDirection.rtl,
        ),

        const SizedBox(height: 48),

        // Login Button
        if (authState.isLoading)
          const CircularProgressIndicator()
        else
          SizedBox(
            width: double.infinity,
            height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF833AB4),
                    Color(0xFFFD1D1D),
                    Color(0xFFF77737),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  ref.read(instagramAuthProvider.notifier).signIn();
                },
                icon: const Icon(Icons.login_rounded, color: Colors.white),
                label: const Text(
                  'تسجيل الدخول بـ Instagram',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),

        // Error Message
        if (authState.status == AuthStatus.error) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    authState.errorMessage ?? 'حدث خطأ ما',
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}