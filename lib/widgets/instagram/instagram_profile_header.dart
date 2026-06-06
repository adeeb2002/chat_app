import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../model/instagram/instagram_user_model.dart';

class InstagramProfileHeader extends StatelessWidget {
  final InstagramUser user;

  const InstagramProfileHeader({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Avatar
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF833AB4),
                      Color(0xFFFD1D1D),
                      Color(0xFFF77737),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF121212) : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 52,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: user.profilePictureUrl != null
                        ? CachedNetworkImageProvider(
                        user.profilePictureUrl!)
                        : null,
                    child: user.profilePictureUrl == null
                        ? const Icon(Icons.person,
                        size: 52, color: Colors.grey)
                        : null,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Username
          Text(
            '@${user.username}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          if (user.name?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              user.name!,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],

          if (user.biography?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text(
              user.biography!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.5),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.rtl,
            ),
          ],

          if (user.website?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.link_rounded,
                    size: 16, color: Color(0xFF0095F6)),
                const SizedBox(width: 4),
                Text(
                  user.website!,
                  style: const TextStyle(
                    color: Color(0xFF0095F6),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),

          // Stats
          Container(
            padding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color:
              isDark ? const Color(0xFF1F2C33) : Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatItem(
                    value: user.formattedPosts,
                    label: 'منشور'),
                Container(
                    width: 1,
                    height: 36,
                    color: Colors.grey.withValues(alpha: 0.3)),
                _StatItem(
                    value: user.formattedFollowers,
                    label: 'متابع'),
                Container(
                    width: 1,
                    height: 36,
                    color: Colors.grey.withValues(alpha: 0.3)),
                _StatItem(
                    value: user.formattedFollowing,
                    label: 'يتابع'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}