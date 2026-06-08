import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../Provider/youtube/youtube_provider.dart';
import '../../widgets/youtube/error_widget.dart';
import '../../widgets/youtube/loading_widget.dart';
import '../../widgets/youtube/search_bar_widget.dart';
import '../../widgets/youtube/video_card_widget.dart';
import 'video_player_screen.dart';

class YoutubeHomeScreen extends ConsumerWidget {
  const YoutubeHomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(isLoadingProvider);
    final errorMessage = ref.watch(errorProvider);
    final videos = ref.watch(videosProvider);
    final isSearchMode = ref.watch(isSearchModeProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final notifier = ref.read(youtubeProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(
        isSearchMode: isSearchMode,
        notifier: notifier,
      ),
      body: Column(
        children: [
          // Search Bar
          SearchBarWidget(
            onSearch: notifier.searchVideos,
            onClear: notifier.goHome,
          ),

          // Category Chip
          _buildCategoryLabel(isSearchMode, searchQuery),

          // Content
          Expanded(
            child: _buildContent(
              context: context,
              ref: ref,
              isLoading: isLoading,
              errorMessage: errorMessage,
              videos: videos,
              notifier: notifier,
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar({
    required bool isSearchMode,
    required YoutubeNotifier notifier,
  }) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'YouTube',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 20,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
      actions: [
        if (isSearchMode)
          IconButton(
            icon: const Icon(Icons.home_outlined, color: Colors.black54),
            onPressed: notifier.goHome,
            tooltip: 'الرئيسية',
          ),
        IconButton(
          icon: const Icon(Icons.refresh_outlined, color: Colors.black54),
          onPressed: notifier.loadTrendingVideos,
          tooltip: 'تحديث',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildCategoryLabel(bool isSearchMode, String searchQuery) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSearchMode ? Colors.blue : Colors.red,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSearchMode ? Icons.search : Icons.local_fire_department,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  isSearchMode
                      ? 'نتائج: "$searchQuery"'
                      : 'الأكثر مشاهدة',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required WidgetRef ref,
    required bool isLoading,
    required String errorMessage,
    required videos,
    required YoutubeNotifier notifier,
  }) {
    // Skeleton Loading
    if (isLoading) {
      return ListView.builder(
        itemCount: 5,
        itemBuilder: (_, __) => const VideoCardSkeleton(),
      );
    }

    // Error
    if (errorMessage.isNotEmpty) {
      return AppErrorWidget(
        message: errorMessage,
        onRetry: notifier.loadTrendingVideos,
      );
    }

    // Empty
    if (videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'لا توجد فيديوهات',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Videos List
    return RefreshIndicator(
      color: Colors.red,
      onRefresh: notifier.loadTrendingVideos,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        itemCount: videos.length,
        cacheExtent: 600,
        itemBuilder: (context, index) {
          return VideoCardWidget(
            video: videos[index],
            onTap: () {
              notifier.selectVideo(videos[index]);
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => VideoPlayerScreen(video: videos[index]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}