import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../model/instagram/instagram_user_model.dart';
import 'shimmer_widgets.dart';

class InstagramProfileHeader extends StatelessWidget {
  final InstagramUser user;

  const InstagramProfileHeader({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Profile Picture
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
                    color: theme.scaffoldBackgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: user.profilePictureUrl != null
                        ? CachedNetworkImageProvider(user.profilePictureUrl!)
                        : null,
                    child: user.profilePictureUrl == null
                        ? const Icon(Icons.person, size: 50, color: Colors.grey)
                        : null,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFF0095F6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Username
          Text(
            '@${user.username}',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          if (user.name != null) ...[
            const SizedBox(height: 4),
            Text(
              user.name!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],

          if (user.biography != null && user.biography!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              user.biography!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.rtl,
            ),
          ],

          if (user.website != null && user.website!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.link, size: 16, color: Color(0xFF0095F6)),
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

          const SizedBox(height: 24),

          // Stats Row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? const Color(0xFF1F2C33)
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  count: user.formattedPosts,
                  label: 'المنشورات',
                ),
                _Divider(),
                _StatItem(
                  count: user.formattedFollowers,
                  label: 'المتابعون',
                ),
                _Divider(),
                _StatItem(
                  count: user.formattedFollowing,
                  label: 'يتابع',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String count;
  final String label;

  const _StatItem({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
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

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey.withValues(alpha: 0.3),
    );
  }
}