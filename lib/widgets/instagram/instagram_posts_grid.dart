import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../Provider/instagram/instagram_providers.dart';
import '../../model/instagram/instagram_media_model.dart';
import 'shimmer_widgets.dart';
/*
class InstagramPostsGridSliver extends ConsumerStatefulWidget {
  const InstagramPostsGridSliver({super.key});

  @override
  ConsumerState<InstagramPostsGridSliver> createState() =>
      _InstagramPostsGridSliverState();
}

class _InstagramPostsGridSliverState
    extends ConsumerState<InstagramPostsGridSliver> {
  @override
  Widget build(BuildContext context) {
    final mediaState = ref.watch(instagramMediaProvider);

    if (mediaState.isLoading) {
      return const SliverToBoxAdapter(child: ShimmerPostsGrid());
    }

    if (mediaState.error != null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.error_outline,
                  color: Colors.red[300], size: 48),
              const SizedBox(height: 12),
              const Text(
                'فشل تحميل المنشورات',
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () =>
                    ref.read(instagramMediaProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (mediaState.items.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: Column(
            children: [
              Icon(Icons.photo_library_outlined,
                  size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'لا توجد منشورات بعد',
                style: TextStyle(color: Colors.grey),
                textDirection: TextDirection.rtl,
              ),
            ],
          ),
        ),
      );
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: mediaState.items.length,
          itemBuilder: (context, index) {
            // تحميل المزيد عند الاقتراب من النهاية
            if (index == mediaState.items.length - 3) {
              //ref.read(instagramMediaProvider.notifier).loadMore();
            }
            return _PostItem(media: mediaState.items[index]);
          },
        ),

        if (mediaState.isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor:
                  AlwaysStoppedAnimation(Color(0xFF833AB4)),
                ),
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

class _PostItem extends StatelessWidget {
  final InstagramMedia media;

  const _PostItem({required this.media});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: media.displayUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) =>
                Container(color: Colors.grey[200]),
            errorWidget: (_, __, ___) => Container(
              color: Colors.grey[200],
              child: const Icon(Icons.broken_image_outlined,
                  color: Colors.grey),
            ),
          ),

          // Type indicator
          if (media.isVideo || media.isCarousel)
            Positioned(
              top: 6,
              right: 6,
              child: Icon(
                media.isVideo
                    ? Icons.play_circle_fill_rounded
                    : Icons.collections_rounded,
                color: Colors.white,
                size: 20,
                shadows: const [
                  Shadow(color: Colors.black54, blurRadius: 4),
                ],
              ),
            ),

          // Likes on hover
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showDetail(context),
                splashColor: Colors.white.withValues(alpha: 0.15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PostDetailSheet(media: media),
    );
  }
}

class _PostDetailSheet extends StatelessWidget {
  final InstagramMedia media;

  const _PostDetailSheet({required this.media});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius:
          const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: CachedNetworkImage(
                          imageUrl: media.displayUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Stats
                    Row(
                      children: [
                        _buildStat(
                          Icons.favorite_rounded,
                          media.likeCount,
                          Colors.red,
                        ),
                        const SizedBox(width: 16),
                        _buildStat(
                          Icons.chat_bubble_outline_rounded,
                          media.commentsCount,
                          Colors.blue,
                        ),
                        const Spacer(),
                        if (media.timestamp != null)
                          Text(
                            _timeAgo(media.timestamp!),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),

                    if (media.caption?.isNotEmpty == true) ...[
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        media.caption!,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, int count, Color color) {
    return Row(
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(width: 4),
        Text(
          count.toString(),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}س';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}ش';
    if (diff.inDays > 0) return '${diff.inDays}ي';
    if (diff.inHours > 0) return '${diff.inHours}س';
    return '${diff.inMinutes}د';
  }
}

 */