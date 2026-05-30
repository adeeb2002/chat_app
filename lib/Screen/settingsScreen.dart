import 'package:ChatApp/Provider/userProvide.dart';
import 'package:ChatApp/Screen/login.dart';
import 'package:ChatApp/Animation/RouteAnimation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isLoading = false;

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('تسجيل خروج', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          RouteAnimation.slideRightAndFade(const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(appUserDataProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('الإعدادات'),
        centerTitle: true,
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ✅ الملف الشخصي
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                // TODO: فتح تعديل الملف الشخصي
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: const Color(0xFF075E54).withOpacity(0.1),
                      backgroundImage: currentUser?.imageUrl != null && currentUser!.imageUrl!.isNotEmpty
                          ? NetworkImage(currentUser.imageUrl!)
                          : null,
                      child: (currentUser?.imageUrl == null || currentUser!.imageUrl!.isEmpty)
                          ? Text(
                              currentUser?.displayName.isNotEmpty == true
                                  ? currentUser!.displayName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF075E54),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentUser?.displayName ?? 'مستخدم',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentUser?.phone ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ✅ أقسام الإعدادات
          _buildSection(
            items: [
              _SettingItem(
                icon: Icons.person,
                title: 'تعديل الملف الشخصي',
                subtitle: 'الاسم، الصورة، البريد الإلكتروني',
                onTap: () {
                  // TODO: فتح شاشة تعديل الملف الشخصي
                },
              ),
              _SettingItem(
                icon: Icons.notifications,
                title: 'الإشعارات',
                subtitle: 'إدارة إعدادات الإشعارات',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('قريباً')),
                  );
                },
              ),
              _SettingItem(
                icon: Icons.dark_mode,
                title: 'الوضع المظلم',
                subtitle: 'تغيير مظهر التطبيق',
                trailing: Switch(
                  value: false,
                  onChanged: (_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('قريباً')),
                    );
                  },
                  activeColor: const Color(0xFF075E54),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildSection(
            items: [
              _SettingItem(
                icon: Icons.share,
                title: 'مشاركة التطبيق',
                subtitle: 'ادع أصدقائك لتجربة التطبيق',
                onTap: () async {
                  await _shareApp();
                },
              ),
              _SettingItem(
                icon: Icons.privacy_tip,
                title: 'سياسة الخصوصية',
                subtitle: 'تعرف على كيفية حماية بياناتك',
                onTap: () async {
                  final uri = Uri.parse('https://google.com');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
              ),
              _SettingItem(
                icon: Icons.info,
                title: 'حول التطبيق',
                subtitle: 'الإصدار 1.0.0',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ✅ تسجيل الخروج
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout, color: Colors.red),
              ),
              title: Text(
                'تسجيل الخروج',
                style: TextStyle(
                  color: Colors.red[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_left, color: Colors.grey),
              onTap: _isLoading ? null : _logout,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required List<_SettingItem> items}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final isLast = i == items.length - 1;
          return Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF075E54).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: const Color(0xFF075E54), size: 22),
                ),
                title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: item.subtitle != null
                    ? Text(item.subtitle!, style: TextStyle(fontSize: 12, color: Colors.grey[600]))
                    : null,
                trailing: item.trailing ?? const Icon(Icons.chevron_left, color: Colors.grey),
                onTap: item.onTap,
              ),
              if (!isLast) const Divider(height: 1, indent: 60),
            ],
          );
        }).toList(),
      ),
    );
  }

  Future<void> _shareApp() async {
    try {
      await launchUrl(Uri.parse('https://github.com/adeeb2002/chat_app'));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل المشاركة: $e')),
        );
      }
    }
  }
}

class _SettingItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  _SettingItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
  });
}
