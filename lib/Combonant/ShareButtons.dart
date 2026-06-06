// lib/widgets/share_buttons.dart

import 'package:flutter/material.dart';
import '../service/share_service.dart';

class ShareButtons extends StatelessWidget {
  final bool showIcons;
  final double iconSize;
  final Color iconColor;

  const ShareButtons({
    super.key,
    this.showIcons = true,
    this.iconSize = 30,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ✅ زر مشاركة على واتساب
        _buildShareButton(
          context: context,
          icon: Icons.chat,
          label: 'مشاركة على واتساب',
          color: const Color(0xFF25D366),
          onTap: () => ShareService().shareOnWhatsApp(context),
        ),
        const SizedBox(height: 12),

        // ✅ زر مشاركة عامة
        _buildShareButton(
          context: context,
          icon: Icons.share,
          label: 'مشاركة عامة',
          color: Colors.blue,
          onTap: () => ShareService().shareGeneral(context),
        ),
        const SizedBox(height: 12),

        // ✅ زر مشاركة رابط التحميل
        _buildShareButton(
          context: context,
          icon: Icons.link,
          label: 'مشاركة رابط التحميل',
          color: Colors.purple,
          onTap: () => ShareService().shareDownloadLink(context),
        ),
      ],
    );
  }

  Widget _buildShareButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showIcons) Icon(icon, color: iconColor, size: iconSize),
            if (showIcons) const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ✅ زر مشاركة بسيط (دائري)
class ShareFloatingButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const ShareFloatingButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed ?? () => ShareService().shareGeneral(context),
      backgroundColor: Colors.green,
      child: const Icon(Icons.share, color: Colors.white),
    );
  }
}

/// ✅ زر مشاركة على واتساب بشكل دائري
class WhatsAppShareButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const WhatsAppShareButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed ?? () => ShareService().shareOnWhatsApp(context),
      backgroundColor: const Color(0xFF25D366),
      child: const Icon(Icons.chat, color: Colors.white),
    );
  }
}