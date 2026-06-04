

// ========================
// Infrastructure Providers
// ========================
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../model/instagram/instagram_media_model.dart';
import '../../model/instagram/instagram_user_model.dart';
import '../../service/instagram/instagram_api_service.dart';
import '../../service/instagram/instagram_auth_service.dart';
import '../../service/instagram/instagram_repository.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Accept': 'application/json'},
  ));

  // Logging interceptor
  dio.interceptors.add(LogInterceptor(
    requestBody: false,
    responseBody: false,
    error: true,
  ));

  return dio;
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
});

// ========================
// Service Providers
// ========================
final instagramAuthServiceProvider = Provider<InstagramAuthService>((ref) {
  return InstagramAuthService(
    dio: ref.watch(dioProvider),
    secureStorage: ref.watch(secureStorageProvider),
  );
});

final instagramApiServiceProvider = Provider<InstagramApiService>((ref) {
  return InstagramApiService(dio: ref.watch(dioProvider));
});

// ========================
// Repository Provider
// ========================
final instagramRepositoryProvider = Provider<InstagramRepository>((ref) {
  return InstagramRepository(
    authService: ref.watch(instagramAuthServiceProvider),
    apiService: ref.watch(instagramApiServiceProvider),
  );
});

// ========================
// Auth State
// ========================
enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.errorMessage,
  });

  AuthState copyWith({AuthStatus? status, String? errorMessage}) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated;
}

class InstagramAuthNotifier extends StateNotifier<AuthState> {
  final InstagramRepository _repository;

  InstagramAuthNotifier(this._repository) : super(const AuthState()) {
    _checkExistingAuth();
  }

  Future<void> _checkExistingAuth() async {
    state = state.copyWith(status: AuthStatus.loading);
    final isValid = await _repository.isTokenValid();
    state = state.copyWith(
      status: isValid ? AuthStatus.authenticated : AuthStatus.unauthenticated,
    );
  }

  Future<void> signIn() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _repository.signIn();
      state = state.copyWith(status: AuthStatus.authenticated);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
    state = state.copyWith(status: AuthStatus.unauthenticated);
  }
}

final instagramAuthProvider =
StateNotifierProvider<InstagramAuthNotifier, AuthState>((ref) {
  return InstagramAuthNotifier(ref.watch(instagramRepositoryProvider));
});

// ========================
// User Profile Provider
// ========================
final instagramUserProvider = FutureProvider<InstagramUser>((ref) async {
  final authState = ref.watch(instagramAuthProvider);
  if (!authState.isAuthenticated) throw Exception('غير مسجل الدخول');
  return ref.watch(instagramRepositoryProvider).getUserProfile();
});

// ========================
// Media Provider (مع Pagination)
// ========================
class InstagramMediaNotifier
    extends StateNotifier<AsyncValue<List<InstagramMedia>>> {
  final InstagramRepository _repository;
  String? _nextCursor;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  InstagramMediaNotifier(this._repository)
      : super(const AsyncValue.loading()) {
    loadMedia();
  }

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  Future<void> loadMedia() async {
    try {
      state = const AsyncValue.loading();
      _nextCursor = null;
      _hasMore = true;

      final response = await _repository.getUserMedia(limit: 12);
      _nextCursor = response.nextCursor;
      _hasMore = response.hasMore;
      state = AsyncValue.data(response.data);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore) return;
    if (state is! AsyncData) return;

    _isLoadingMore = true;
    try {
      final response = await _repository.getUserMedia(
        cursor: _nextCursor,
        limit: 12,
      );
      _nextCursor = response.nextCursor;
      _hasMore = response.hasMore;

      final currentList = (state as AsyncData<List<InstagramMedia>>).value;
      state = AsyncValue.data([...currentList, ...response.data]);
    } catch (e) {
      // لا نعرض error عند pagination
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> refresh() => loadMedia();
}

final instagramMediaProvider = StateNotifierProvider<InstagramMediaNotifier,
    AsyncValue<List<InstagramMedia>>>((ref) {
  final authState = ref.watch(instagramAuthProvider);
  if (!authState.isAuthenticated) {
    return InstagramMediaNotifier(ref.watch(instagramRepositoryProvider));
  }
  return InstagramMediaNotifier(ref.watch(instagramRepositoryProvider));
});