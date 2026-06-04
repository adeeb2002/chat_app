// lib/services/share_service.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ShareService {
  static final ShareService _instance = ShareService._internal();
  factory ShareService() => _instance;
  ShareService._internal();

  // ✅ روابط التطبيق (استبدلها بروابط تطبيقك الحقيقية)
  static const String playStoreUrl = 'https://play.google.com/store/apps/details?id=com.example.chatapp';
  static const String appStoreUrl = 'https://apps.apple.com/app/id123456789';
  static const String appWebsite = 'https://your-chat-app.com';

  /// ✅ مشاركة التطبيق عبر واتساب
  Future<void> shareOnWhatsApp(BuildContext context) async {
    final String message = _getShareMessage();

    // محاولة فتح واتساب مباشرة
    final whatsappUrl = 'whatsapp://send?text=${Uri.encodeComponent(message)}';

    try {
      if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
        await launchUrl(Uri.parse(whatsappUrl));
      } else {
        // إذا لم يكن واتساب مثبتاً، نفتح متجر التطبيقات
        _showWhatsAppNotInstalledDialog(context);
      }
    } catch (e) {
      _showWhatsAppNotInstalledDialog(context);
    }
  }

  /// ✅ مشاركة التطبيق عبر واتساب Business
  Future<void> shareOnWhatsAppBusiness(BuildContext context) async {
    final String message = _getShareMessage();

    final whatsappBusinessUrl = 'whatsapp://send?text=${Uri.encodeComponent(message)}';

    try {
      if (await canLaunchUrl(Uri.parse(whatsappBusinessUrl))) {
        await launchUrl(Uri.parse(whatsappBusinessUrl));
      } else {
        _showWhatsAppNotInstalledDialog(context);
      }
    } catch (e) {
      _showWhatsAppNotInstalledDialog(context);
    }
  }

  /// ✅ المشاركة عبر أي تطبيق (قائمة عامة)
  Future<void> shareGeneral(BuildContext context) async {
    final String message = _getShareMessage();

    await Share.share(
      message,
      subject: 'حمّل تطبيق المحادثات الآن!',
    );
  }

  /// ✅ مشاركة رابط التحميل فقط
  Future<void> shareDownloadLink(BuildContext context) async {
    final String link = _getDownloadLink();

    await Share.share(
      '🔥 حمّل تطبيق المحادثات الآن!\n\n$link',
      subject: 'تحميل تطبيق المحادثات',
    );
  }

  /// ✅ مشاركة مع صور (لوجو التطبيق)
  Future<void> shareWithImage(BuildContext context, String imagePath) async {
    final String message = _getShareMessage();
    final xFile = XFile(imagePath);

    await Share.shareXFiles(
      [xFile],
      text: message,
      subject: 'حمّل تطبيق المحادثات الآن!',
    );
  }

  /// ✅ رسالة المشاركة
  String _getShareMessage() {
    return '''
📱 **تطبيق المحادثات - تواصل بكل سهولة!**

✨ **مميزات التطبيق:**
• 💬 محادثات فورية وآمنة
• 🔒 تشفير كامل للرسائل
• 📸 مشاركة الصور والملفات
• 🎤 رسائل صوتية
• 👥 محادثات جماعية
• 🔔 إشعارات فورية

📥 **حمّل التطبيق الآن:**
${_getDownloadLink()}

🌟 انضم إلى آلاف المستخدمين وتواصل مع أحبائك!
    ''';
  }

  /// ✅ رابط التحميل حسب نظام التشغيل
  String _getDownloadLink() {
    if (Platform.isAndroid) {
      return playStoreUrl;
    } else if (Platform.isIOS) {
      return appStoreUrl;
    } else {
      return appWebsite;
    }
  }

  /// ✅ عرض نافذة عند عدم وجود واتساب
  void _showWhatsAppNotInstalledDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('واتساب غير مثبت'),
        content: const Text('لا يوجد تطبيق واتساب على جهازك. هل تريد مشاركة الرابط بطريقة أخرى؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              shareGeneral(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('مشاركة عامة'),
          ),
        ],
      ),
    );
  }

  /// ✅ مشاركة رمز الصديق (Invite Code)
  Future<void> shareInviteCode(BuildContext context, String inviteCode) async {
    final String message = '''
🎁 **انضم إليَّ على تطبيق المحادثات!**

استخدم رمز الدعوة الخاص بي: **$inviteCode**

📥 حمّل التطبيق الآن:
${_getDownloadLink()}

🔑 أدخل الرمز عند التسجيل وستحصل على مكافأة!
    ''';

    await Share.share(message, subject: 'انضم إلى تطبيق المحادثات');
  }
}