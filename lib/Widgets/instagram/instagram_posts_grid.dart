import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../Provider/instagram/instagram_providers.dart';
import '../../model/instagram/instagram_media_model.dart';
import 'shimmer_widgets.dart';

class InstagramPostsGrid extends ConsumerStatefulWidget {
  const InstagramPostsGrid({super.key});

  @override
  ConsumerState<InstagramPostsGrid> createState() => _InstagramPostsGridState();
}

class _InstagramPostsGridState extends ConsumerState<InstagramPostsGrid> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(instagramMediaProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaState = ref.watch(instagramMediaProvider);

    return mediaState.when(
      loading: () => const ShimmerPostsGrid(),
      error: (error, _) => _ErrorWidget(
        message: error.toString(),
        onRetry: () => ref.read(instagramMediaProvider.notifier).refresh(),
      ),
      data: (media) {
        if (media.isEmpty) {
          return const _EmptyPostsWidget();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'المنشورات',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  Text(
                    '${media.length} منشور',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),

            GridView.builder(
              controller: _scrollController,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 3,
                mainAxisSpacing: 3,
              ),
              itemCount: media.length,
              itemBuilder: (context, index) {
                return _PostGridItem(media: media[index]);
              },
            ),

            // Load More Indicator
            if (ref.watch(instagramMediaProvider.notifier).isLoadingMore)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),

            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}

class _PostGridItem extends StatelessWidget {
  final InstagramMedia media;

  const _PostGridItem({required this.media});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showMediaDetail(context),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: media.displayUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              color: Colors.grey[200],
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              color: Colors.grey[200],
              child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
            ),
          ),

          // Overlay Icons
          Positioned(
            top: 6,
            right: 6,
            child: _MediaTypeIcon(mediaType: media.mediaType),
          ),

          // Hover Overlay
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showMediaDetail(context),
              splashColor: Colors.white.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }

  void _showMediaDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MediaDetailSheet(media: media),
    );
  }
}

class _MediaTypeIcon extends StatelessWidget {
  final MediaType mediaType;

  const _MediaTypeIcon({required this.mediaType});

  @override
  Widget build(BuildContext context) {
    IconData? icon;
    switch (mediaType) {
      case MediaType.video:
        icon = Icons.play_circle_fill_rounded;
        break;
      case MediaType.carouselAlbum:
        icon = Icons.collections_rounded;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Icon(icon, color: Colors.white, size: 20,
      shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
    );
  }
}

class _MediaDetailSheet extends StatelessWidget {
  final InstagramMedia media;

  const _MediaDetailSheet({required this.media});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: media.displayUrl,
                      fit: BoxFit.cover,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Stats
                  Row(
                    children: [
                      _StatChip(
                        icon: Icons.favorite_rounded,
                        count: media.likeCount,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 12),
                      _StatChip(
                        icon: Icons.chat_bubble_rounded,
                        count: media.commentsCount,
                        color: const Color(0xFF0095F6),
                      ),
                      const Spacer(),
                      if (media.timestamp != null)
                        Text(
                          _formatDate(media.timestamp!),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),

                  if (media.caption != null &&
                      media.caption!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      media.caption!,
                      style: const TextStyle(fontSize: 14),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()} سنة';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} شهر';
    if (diff.inDays > 0) return '${diff.inDays} يوم';
    if (diff.inHours > 0) return '${diff.inHours} ساعة';
    return '${diff.inMinutes} دقيقة';
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 4),
        Text(
          count.toString(),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _EmptyPostsWidget extends StatelessWidget {
  const _EmptyPostsWidget();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'لا توجد منشورات بعد',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorWidget({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'حدث خطأ في تحميل المنشورات',
            style: TextStyle(color: Colors.grey[700]),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}