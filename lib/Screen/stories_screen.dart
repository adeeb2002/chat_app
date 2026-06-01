import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../Provider/statusProvider.dart';
import '../Provider/userProvide.dart';
import '../model/status.dart';
import '../model/user.dart';
import 'createStatusScreen.dart';
import 'viewStatusScreen.dart';

class StoriesScreen extends ConsumerStatefulWidget {
  const StoriesScreen({super.key});

  @override
  ConsumerState<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends ConsumerState<StoriesScreen> {
  @override
  Widget build(BuildContext context) {
    final allStatusesAsync = ref.watch(allStatusesProvider);
    final currentUserAsync = ref.watch(appUserDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('القصص'),
      ),
      body: allStatusesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ في تحميل القصص: $e')),
        data: (statuses) {
          if (statuses.isEmpty) {
            return _buildEmptyState();
          }

          final currentUser = currentUserAsync;
          final currentUserId = currentUser?.id;

          final myStatuses = statuses
              .where((s) => s.userId == currentUserId)
              .toList();
          final otherStatuses = statuses
              .where((s) => s.userId != currentUserId)
              .toList();

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _buildMyStorySection(myStatuses, currentUser),
              const Divider(height: 1),
              if (otherStatuses.isNotEmpty)
                _buildOtherStoriesSection(otherStatuses),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.circle_outlined, size: 80, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(
            'لا توجد قصص حالياً',
            style: TextStyle(fontSize: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'أنشئ أول قصة الآن',
            style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateStatusScreen()),
            ),
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('إضافة قصة'),
          ),
        ],
      ),
    );
  }

  Widget _buildMyStorySection(List<Status> myStatuses, AppUser? currentUser) {
    final theme = Theme.of(context);
    final userImageUrl = currentUser?.imageUrl;
    final userDisplayName = currentUser?.displayName ?? 'قصتي';
    final primaryColor = theme.colorScheme.primary;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (myStatuses.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ViewStatusScreen(status: myStatuses.first),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateStatusScreen()),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: myStatuses.isNotEmpty
                        ? primaryColor
                        : Colors.grey.shade300,
                    child: CircleAvatar(
                      radius: 26,
                      backgroundImage:
                          userImageUrl != null && userImageUrl.isNotEmpty
                          ? NetworkImage(userImageUrl)
                          : null,
                      child: (userImageUrl == null || userImageUrl.isEmpty)
                          ? Icon(Icons.person, size: 28, color: theme.colorScheme.onPrimary)
                          : null,
                    ),
                  ),
                  if (myStatuses.isEmpty)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.surface,
                            width: 2,
                          ),
                        ),
                        child: const Icon(Icons.add, size: 14, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userDisplayName,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      myStatuses.isNotEmpty
                          ? 'اضغط لعرض قصتك'
                          : 'اضغط لإضافة قصة',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (myStatuses.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${myStatuses.length}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtherStoriesSection(List<Status> statuses) {
    final theme = Theme.of(context);
    final Map<String, Status> latestStatusPerUser = {};
    for (final status in statuses) {
      if (!latestStatusPerUser.containsKey(status.userId)) {
        latestStatusPerUser[status.userId] = status;
      } else {
        final existing = latestStatusPerUser[status.userId]!;
        if (status.timestamp.millisecondsSinceEpoch >
            existing.timestamp.millisecondsSinceEpoch) {
          latestStatusPerUser[status.userId] = status;
        }
      }
    }

    final groupedStatuses = latestStatusPerUser.values.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'قصص الأصدقاء',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        ...groupedStatuses.map((status) => _buildStoryTile(status)),
      ],
    );
  }

  Widget _buildStoryTile(Status status) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ViewStatusScreen(status: status)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: primaryColor,
                    child: CircleAvatar(
                      radius: 22,
                      backgroundImage:
                          status.userImageUrl != null &&
                              status.userImageUrl!.isNotEmpty
                          ? NetworkImage(status.userImageUrl!)
                          : NetworkImage(status.imageUrl!),
                      child:
                          status.userImageUrl == null ||
                              status.userImageUrl!.isEmpty
                          ? Text(
                              status.userDisplayName.isNotEmpty
                                  ? status.userDisplayName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimary,
                              ),
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.surface,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.userDisplayName,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTimeAgo(status.timestamp),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.circle, size: 8, color: primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return 'منذ ${(difference.inDays / 7).floor()} أسابيع';
    } else if (difference.inDays >= 1) {
      return 'منذ ${difference.inDays} يوم${difference.inDays == 1 ? '' : 'ين'}';
    } else if (difference.inHours >= 1) {
      return 'منذ ${difference.inHours} ساعة${difference.inHours == 1 ? '' : 'ات'}';
    } else if (difference.inMinutes >= 1) {
      return 'منذ ${difference.inMinutes} دقيقة${difference.inMinutes == 1 ? '' : 'ق'}';
    } else {
      return 'الآن';
    }
  }
}
