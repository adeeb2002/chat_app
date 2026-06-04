import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Provider/instagram/instagram_providers.dart';
import '../Widgets/instagram/instagram_login_button.dart';
import '../Widgets/instagram/instagram_posts_grid.dart';
import '../Widgets/instagram/instagram_profile_header.dart';
import '../Widgets/instagram/shimmer_widgets.dart';


class InstagramScreen extends ConsumerWidget {
  const InstagramScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(instagramAuthProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Instagram',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (authState.isAuthenticated)
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: () => _showLogoutDialog(context, ref),
              tooltip: 'تسجيل الخروج',
            ),
        ],
      ),
      body: _buildBody(authState, ref),
    );
  }

  Widget _buildBody(AuthState authState, WidgetRef ref) {
    // Initial Loading
    if (authState.status == AuthStatus.initial ||
        authState.status == AuthStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Not Authenticated
    if (!authState.isAuthenticated) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: const InstagramLoginButton(),
        ),
      );
    }

    // Authenticated
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(instagramUserProvider);
        await ref.read(instagramMediaProvider.notifier).refresh();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // Profile Header
            _ProfileHeaderSection(),

            // Divider
            const Divider(height: 1),

            // Posts Grid
            const SizedBox(height: 8),
            const InstagramPostsGrid(),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'تسجيل الخروج',
          textDirection: TextDirection.rtl,
        ),
        content: const Text(
          'هل تريد تسجيل الخروج من حساب Instagram؟',
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(instagramAuthProvider.notifier).signOut();
            },
            child: const Text('خروج'),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeaderSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(instagramUserProvider);

    return userAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: ShimmerProfileHeader(),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: Colors.red[300], size: 48),
            const SizedBox(height: 12),
            Text(
              'فشل تحميل البيانات',
              style: TextStyle(color: Colors.grey[700]),
              textDirection: TextDirection.rtl,
            ),
            TextButton.icon(
              onPressed: () => ref.invalidate(instagramUserProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
      data: (user) => InstagramProfileHeader(user: user),
    );
  }
}