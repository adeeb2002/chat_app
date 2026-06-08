import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../Provider/youtube/youtube_provider.dart';
import '../../model/youtube/video_model.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final VideoModel video;

  const VideoPlayerScreen({Key? key, required this.video}) : super(key: key);

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  late YoutubePlayerController _controller;
  bool _isFullScreen = false;
  bool _showDescription = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    _controller = YoutubePlayerController(
      initialVideoId: widget.video.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: true,
        forceHD: false,
        useHybridComposition: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    ref.read(youtubeProvider.notifier).clearSelectedVideo();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentVideo = widget.video;

    return YoutubePlayerBuilder(
      onEnterFullScreen: () {
        setState(() => _isFullScreen = true);
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      },
      onExitFullScreen: () {
        setState(() => _isFullScreen = false);
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      },
      player: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: Colors.red,
        progressColors: const ProgressBarColors(
          playedColor: Colors.red,
          handleColor: Colors.redAccent,
          bufferedColor: Colors.white38,
          backgroundColor: Colors.white24,
        ),
        topActions: [
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              currentVideo.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      builder: (context, player) {
        return Scaffold(
          backgroundColor: Colors.black,
          resizeToAvoidBottomInset: false,
          appBar: _isFullScreen
              ? null
              : AppBar(
            backgroundColor: Colors.black,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'الفيديو',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: () {},
              ),
            ],
          ),
          body: Column(
            children: [
              // Player
              player,

              // Video Details
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        currentVideo.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Stats Row
                      Row(
                        children: [
                          if (currentVideo.viewCount != '0') ...[
                            Icon(
                              Icons.visibility_outlined,
                              color: Colors.grey[400],
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              currentVideo.formattedViewCount,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                          if (currentVideo.formattedDuration.isNotEmpty) ...[
                            Icon(
                              Icons.access_time,
                              color: Colors.grey[400],
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              currentVideo.formattedDuration,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Divider
                      Divider(color: Colors.grey[800], height: 1),
                      const SizedBox(height: 12),

                      // Channel Row
                      _buildChannelRow(currentVideo),
                      const SizedBox(height: 16),

                      // Action Buttons
                      _buildActionButtons(currentVideo),

                      Divider(color: Colors.grey[800], height: 24),

                      // Description
                      _buildDescription(currentVideo),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChannelRow(VideoModel video) {
    return Row(
      children: [
        // Avatar
        CircleAvatar(
          radius: 22,
          backgroundColor: Colors.red,
          child: Text(
            video.channelTitle.isNotEmpty
                ? video.channelTitle[0].toUpperCase()
                : 'Y',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Channel Name
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                video.channelTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                'اضغط للاشتراك',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),

        // Subscribe Button
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: const Text(
            'اشتراك',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(VideoModel video) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildActionChip(
            icon: Icons.thumb_up_outlined,
            label: video.formattedLikeCount.isNotEmpty &&
                video.likeCount != '0'
                ? video.formattedLikeCount
                : 'إعجاب',
            onTap: () {},
          ),
          const SizedBox(width: 8),
          _buildActionChip(
            icon: Icons.thumb_down_outlined,
            label: 'لا يعجبني',
            onTap: () {},
          ),
          const SizedBox(width: 8),
          _buildActionChip(
            icon: Icons.share_outlined,
            label: 'مشاركة',
            onTap: () {},
          ),
          const SizedBox(width: 8),
          _buildActionChip(
            icon: Icons.download_outlined,
            label: 'تنزيل',
            onTap: () {},
          ),
          const SizedBox(width: 8),
          _buildActionChip(
            icon: Icons.playlist_add_outlined,
            label: 'حفظ',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescription(VideoModel video) {
    if (video.description.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _showDescription = !_showDescription),
          child: Row(
            children: [
              const Text(
                'الوصف',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Icon(
                _showDescription
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _showDescription
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: Text(
            video.description,
            style: TextStyle(color: Colors.grey[400], fontSize: 13, height: 1.5),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          secondChild: Text(
            video.description,
            style: TextStyle(color: Colors.grey[400], fontSize: 13, height: 1.5),
          ),
        ),
      ],
    );
  }
}