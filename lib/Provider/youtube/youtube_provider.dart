import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../model/youtube/video_model.dart';
import '../../service/youtube/youtube_service.dart';

// ==========================================
// State
// ==========================================
class YoutubeState {
  final List<VideoModel> trendingVideos;
  final List<VideoModel> searchResults;
  final VideoModel? selectedVideo;
  final bool isLoadingTrending;
  final bool isSearching;
  final String errorMessage;
  final String searchQuery;
  final bool isSearchMode;

  const YoutubeState({
    this.trendingVideos = const [],
    this.searchResults = const [],
    this.selectedVideo,
    this.isLoadingTrending = false,
    this.isSearching = false,
    this.errorMessage = '',
    this.searchQuery = '',
    this.isSearchMode = false,
  });

  List<VideoModel> get displayedVideos =>
      isSearchMode ? searchResults : trendingVideos;

  bool get isLoading => isLoadingTrending || isSearching;
  bool get hasError => errorMessage.isNotEmpty;
  bool get hasVideos => displayedVideos.isNotEmpty;

  YoutubeState copyWith({
    List<VideoModel>? trendingVideos,
    List<VideoModel>? searchResults,
    VideoModel? selectedVideo,
    bool? isLoadingTrending,
    bool? isSearching,
    String? errorMessage,
    String? searchQuery,
    bool? isSearchMode,
    bool clearSelectedVideo = false,
    bool clearError = false,
  }) {
    return YoutubeState(
      trendingVideos: trendingVideos ?? this.trendingVideos,
      searchResults: searchResults ?? this.searchResults,
      selectedVideo:
      clearSelectedVideo ? null : selectedVideo ?? this.selectedVideo,
      isLoadingTrending: isLoadingTrending ?? this.isLoadingTrending,
      isSearching: isSearching ?? this.isSearching,
      errorMessage: clearError ? '' : errorMessage ?? this.errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      isSearchMode: isSearchMode ?? this.isSearchMode,
    );
  }
}

// ==========================================
// Notifier
// ==========================================
class YoutubeNotifier extends StateNotifier<YoutubeState> {
  final YoutubeService _service;

  YoutubeNotifier(this._service) : super(const YoutubeState()) {
    loadTrendingVideos();
  }

  Future<void> loadTrendingVideos() async {
    state = state.copyWith(
      isLoadingTrending: true,
      clearError: true,
      isSearchMode: false,
    );
    try {
      final videos = await _service.getTrendingVideos();
      state = state.copyWith(
        trendingVideos: videos,
        isLoadingTrending: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingTrending: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> searchVideos(String query) async {
    if (query.trim().isEmpty) return;
    state = state.copyWith(
      isSearching: true,
      clearError: true,
      isSearchMode: true,
      searchQuery: query,
    );
    try {
      final results = await _service.searchVideos(query);
      state = state.copyWith(
        searchResults: results,
        isSearching: false,
      );
    } catch (e) {
      state = state.copyWith(
        isSearching: false,
        errorMessage: e.toString(),
      );
    }
  }

  void selectVideo(VideoModel video) {
    state = state.copyWith(selectedVideo: video);
  }

  void clearSelectedVideo() {
    state = state.copyWith(clearSelectedVideo: true);
  }

  void goHome() {
    state = state.copyWith(
      isSearchMode: false,
      clearError: true,
    );
    if (state.trendingVideos.isEmpty) {
      loadTrendingVideos();
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// ==========================================
// Providers
// ==========================================
final youtubeServiceProvider = Provider<YoutubeService>((ref) {
  final service = YoutubeService();
  ref.onDispose(() => service.dispose());
  return service;
});

final youtubeProvider =
StateNotifierProvider<YoutubeNotifier, YoutubeState>((ref) {
  final service = ref.watch(youtubeServiceProvider);
  return YoutubeNotifier(service);
});

final videosProvider = Provider<List<VideoModel>>((ref) {
  return ref.watch(youtubeProvider).displayedVideos;
});

final isLoadingProvider = Provider<bool>((ref) {
  return ref.watch(youtubeProvider).isLoading;
});

final errorProvider = Provider<String>((ref) {
  return ref.watch(youtubeProvider).errorMessage;
});

final selectedVideoProvider = Provider<VideoModel?>((ref) {
  return ref.watch(youtubeProvider).selectedVideo;
});

final isSearchModeProvider = Provider<bool>((ref) {
  return ref.watch(youtubeProvider).isSearchMode;
});

final searchQueryProvider = Provider<String>((ref) {
  return ref.watch(youtubeProvider).searchQuery;
});