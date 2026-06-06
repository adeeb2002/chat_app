import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../model/instagram/instagram_media_model.dart';

class InstagramStoriesRow extends StatelessWidget {
  final List<InstagramMedia> stories;

  const InstagramStoriesRow({super.key, required this.stories});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Text(
            'القصص',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textDirection: TextDirection.rtl,
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: stories.length,
            itemBuilder: (context, index) {
              return _StoryItem(story: stories[index]);
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _StoryItem extends StatelessWidget {
  final InstagramMedia story;

  const _StoryItem({required this.story});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showStory(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
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
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: story.thumbnailUrl != null
                      ? CachedNetworkImageProvider(story.thumbnailUrl!)
                      : story.mediaUrl != null
                      ? CachedNetworkImageProvider(story.mediaUrl!)
                      : null,
                  child: story.thumbnailUrl == null && story.mediaUrl == null
                      ? const Icon(Icons.photo, color: Colors.grey)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 72,
              child: Text(
                story.isVideo ? '🎬 فيديو' : '📷 قصة',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStory(BuildContext context) {
    if (story.mediaUrl == null) return;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: story.displayUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }
}