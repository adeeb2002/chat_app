import 'package:ChatApp/Notifications/notifications.dart';
import 'package:ChatApp/Provider/userProvide.dart';
import 'package:ChatApp/Provider/theme_provider.dart';
import 'package:ChatApp/Screen/editProfileScreen.dart';
import 'package:ChatApp/Screen/login.dart';
import 'package:ChatApp/Animation/RouteAnimation.dart';
import 'package:ChatApp/theme/app_theme.dart';
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
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreference();
  }

  Future<void> _loadNotificationPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await NotificationService().setNotificationsEnabled(value);
    await prefs.setBool('notificationsEnabled', value);
    setState(() {
      _notificationsEnabled = value;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'تم تشغيل الإشعارات' : 'تم إيقاف الإشعارات'),
          backgroundColor: value ? AppTheme.successColor : AppTheme.warningColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showAboutDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.chat, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            const Text('ChatApp'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الإصدار 1.0.0', style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Text(
              'تطبيق محادثة فوري مبني باستخدام Flutter و Firebase.',
              style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color),
            ),
            const SizedBox(height: 12),
            Text(
              'المطور: Adeeb',
              style: TextStyle(color: theme.textTheme.bodySmall?.color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

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
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ✅ الملف الشخصي
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                      backgroundImage: currentUser?.imageUrl != null && currentUser!.imageUrl!.isNotEmpty
                          ? NetworkImage(currentUser.imageUrl!)
                          : null,
                      child: (currentUser?.imageUrl == null || currentUser!.imageUrl!.isEmpty)
                          ? Text(
                              currentUser?.displayName.isNotEmpty == true
                                  ? currentUser!.displayName[0].toUpperCase()
                                  : 'U',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
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
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentUser?.phone ?? '',
                            style: theme.textTheme.bodySmall,
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

          // ✅ الإعدادات الأساسية
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.person, color: theme.colorScheme.primary, size: 22),
                  ),
                  title: const Text('تعديل الملف الشخصي', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('الاسم، الصورة، البريد الإلكتروني', style: theme.textTheme.bodySmall),
                  trailing: const Icon(Icons.chevron_left, color: Colors.grey),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                    );
                  },
                ),
                const Divider(height: 1, indent: 60),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.notifications, color: theme.colorScheme.primary, size: 22),
                  ),
                  title: const Text('الإشعارات', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    _notificationsEnabled ? 'تشغيل' : 'إيقاف',
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: Switch(
                    value: _notificationsEnabled,
                    onChanged: _toggleNotifications,
                  ),
                ),
                const Divider(height: 1, indent: 60),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.dark_mode, color: theme.colorScheme.primary, size: 22),
                  ),
                  title: const Text('الوضع المظلم', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    isDark ? 'مفعل' : 'غير مفعل',
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: Switch(
                    value: isDark,
                    onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ✅ أقسام إضافية
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.share, color: theme.colorScheme.primary, size: 22),
                  ),
                  title: const Text('مشاركة التطبيق', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('ادع أصدقائك لتجربة التطبيق', style: theme.textTheme.bodySmall),
                  trailing: const Icon(Icons.chevron_left, color: Colors.grey),
                  onTap: () async {
                    final uri = Uri.parse('https://github.com/adeeb2002/chat_app');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                ),
                const Divider(height: 1, indent: 60),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.info, color: theme.colorScheme.primary, size: 22),
                  ),
                  title: const Text('حول التطبيق', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('الإصدار 1.0.0', style: theme.textTheme.bodySmall),
                  trailing: const Icon(Icons.chevron_left, color: Colors.grey),
                  onTap: _showAboutDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ✅ تسجيل الخروج
          Card(
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout, color: AppTheme.errorColor),
              ),
              title: Text(
                'تسجيل الخروج',
                style: TextStyle(
                  color: isDark ? Colors.red.shade300 : Colors.red[700],
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
}
