import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../model/instagram/message_models.dart';
import '../../service/instagram/instagram_api_service.dart';

class InstagramProvider with ChangeNotifier {
  final InstagramApiService _apiService = InstagramApiService();

  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _errorMessage;
  User? _currentUser;

  List<InboxThread> _threads = [];
  bool _isLoadingThreads = false;

  Map<String, List<Message>> _messagesCache = {};
  Map<String, List<User>> _threadUsersCache = {};
  bool _isLoadingMessages = false;

  // Getters
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  bool get isLoadingThreads => _isLoadingThreads;
  bool get isLoadingMessages => _isLoadingMessages;
  String? get errorMessage => _errorMessage;
  User? get currentUser => _currentUser;
  List<InboxThread> get threads => _threads;
  InstagramApiService get apiService => _apiService;

  Future<void> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (_isLoggedIn) {
      final username = prefs.getString('username');
      final userId = prefs.getString('userId');
      final fullName = prefs.getString('fullName');
      final profilePic = prefs.getString('profilePic');

      if (username != null && userId != null) {
        _currentUser = User(
          userId: userId,
          username: username,
          fullName: fullName ?? '',
          profilePicUrl: profilePic,
        );
        _apiService.userId = userId;
        _apiService.username = username;
      }
    }

    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _apiService.login(username, password);

      if (result['success']) {
        _isLoggedIn = true;
        _currentUser = User.fromJson(result['user']);
        _errorMessage = null;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('username', _currentUser!.username);
        await prefs.setString('userId', _currentUser!.userId);
        await prefs.setString('fullName', _currentUser!.fullName);
        if (_currentUser!.profilePicUrl != null) {
          await prefs.setString('profilePic', _currentUser!.profilePicUrl!);
        }

        _isLoading = false;
        notifyListeners();

        await loadThreads();

        return true;
      } else {
        _errorMessage = result['message'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'خطأ غير متوقع: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadThreads({bool refresh = false}) async {
    if (_isLoadingThreads && !refresh) return;

    _isLoadingThreads = true;
    if (refresh) {
      _threads.clear();
    }
    notifyListeners();

    try {
      final result = await _apiService.getInbox();

      if (result['success']) {
        _threads = (result['threads'] as List)
            .map((t) => InboxThread.fromJson(t as Map<String, dynamic>))
            .toList();
        _errorMessage = null;
      } else {
        _errorMessage = 'فشل جلب المحادثات';
      }
    } catch (e) {
      _errorMessage = 'خطأ: ${e.toString()}';
    } finally {
      _isLoadingThreads = false;
      notifyListeners();
    }
  }

  Future<List<Message>> loadMessages(String threadId,
      {bool refresh = false}) async {
    if (_isLoadingMessages && !refresh) {
      return _messagesCache[threadId] ?? [];
    }

    _isLoadingMessages = true;
    notifyListeners();

    try {
      final result = await _apiService.getThreadMessages(threadId);

      if (result['success']) {
        List<Message> messages = (result['messages'] as List)
            .map((m) => Message.fromJson(m as Map<String, dynamic>))
            .toList();

        _messagesCache[threadId] = messages;
        _threadUsersCache[threadId] = (result['users'] as List)
            .map((u) => User.fromJson(u as Map<String, dynamic>))
            .toList();

        _errorMessage = null;

        _isLoadingMessages = false;
        notifyListeners();

        return messages;
      } else {
        _errorMessage = 'فشل جلب الرسائل';
        _isLoadingMessages = false;
        notifyListeners();
        return [];
      }
    } catch (e) {
      _errorMessage = 'خطأ: ${e.toString()}';
      _isLoadingMessages = false;
      notifyListeners();
      return [];
    }
  }

  Future<bool> sendMessage(String threadId, String message) async {
    try {
      final result = await _apiService.sendMessage(threadId, message);

      if (result['success']) {
        await loadMessages(threadId, refresh: true);
        return true;
      }

      _errorMessage = result['message'];
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'خطأ في الإرسال';
      notifyListeners();
      return false;
    }
  }

  List<User> getThreadUsers(String threadId) {
    return _threadUsersCache[threadId] ?? [];
  }

  List<Message> getCachedMessages(String threadId) {
    return _messagesCache[threadId] ?? [];
  }

  Future<void> logout() async {
    await _apiService.logout();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    _isLoggedIn = false;
    _currentUser = null;
    _threads.clear();
    _messagesCache.clear();
    _threadUsersCache.clear();
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}