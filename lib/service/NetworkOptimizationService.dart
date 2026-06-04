import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkOptimizationService {
  static final NetworkOptimizationService _instance = NetworkOptimizationService._internal();
  factory NetworkOptimizationService() => _instance;
  NetworkOptimizationService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;

  // ✅ حالة الاتصال
  bool _isConnected = false;
  bool _isSlowConnection = false;

  // ✅ للتحكم في عدد المحاولات المتزامنة
  int _maxConcurrentRequests = 3;
  int _currentRequests = 0;

  // ✅ قائمة انتظار للطلبات
  final List<Function> _requestQueue = [];

  // ✅ Timeout للطلبات
  Duration _requestTimeout = const Duration(seconds: 15);

  bool get isConnected => _isConnected;
  bool get isSlowConnection => _isSlowConnection;

  /// ✅ تهيئة الخدمة
  Future<void> initialize() async {
    print('🔧 تهيئة NetworkOptimizationService...');

    // ✅ تفعيل Firebase Offline Persistence
    try {
      _db.setPersistenceEnabled(true);
      _db.setPersistenceCacheSizeBytes(100 * 1024 * 1024); // 100 MB
      print('✅ تم تفعيل Firebase Offline Persistence');
    } catch (e) {
      print('⚠️ Firebase Persistence مفعل مسبقاً');
    }

    // ✅ مراقبة حالة الاتصال
    Connectivity().onConnectivityChanged.listen((result) async {
      final hadConnection = _isConnected;
      _isConnected = result.contains(ConnectivityResult.mobile) ||
          result.contains(ConnectivityResult.wifi);

      if (_isConnected) {
        // ✅ فحص سرعة الاتصال
        await _checkConnectionSpeed();

        if (!hadConnection) {
          print('🌐 عاد الاتصال بالإنترنت');
          _processQueue();
        }
      } else {
        print('📴 انقطع الاتصال بالإنترنت');
        _isSlowConnection = false;
      }
    });

    // ✅ فحص الحالة الحالية
    final result = await Connectivity().checkConnectivity();
    _isConnected = result.contains(ConnectivityResult.mobile) ||
        result.contains(ConnectivityResult.wifi);

    if (_isConnected) {
      await _checkConnectionSpeed();
    }
  }

  /// ✅ فحص سرعة الاتصال
  Future<void> _checkConnectionSpeed() async {
    try {
      final stopwatch = Stopwatch()..start();

      // ✅ طلب بسيط لقياس السرعة
      await _db.ref('.info/connected').get().timeout(
        const Duration(seconds: 3),
      );

      stopwatch.stop();
      final latency = stopwatch.elapsedMilliseconds;

      // ✅ تحديد إذا كان الاتصال بطيء
      if (latency > 2000) {
        _isSlowConnection = true;
        _maxConcurrentRequests = 1; // طلب واحد فقط
        _requestTimeout = const Duration(seconds: 30);
        print('🐌 اتصال بطيء جداً (${latency}ms) - تم تفعيل الوضع البطيء');
      } else if (latency > 1000) {
        _isSlowConnection = true;
        _maxConcurrentRequests = 2;
        _requestTimeout = const Duration(seconds: 20);
        print('⚠️ اتصال بطيء (${latency}ms)');
      } else {
        _isSlowConnection = false;
        _maxConcurrentRequests = 3;
        _requestTimeout = const Duration(seconds: 15);
        print('✅ اتصال جيد (${latency}ms)');
      }
    } catch (e) {
      print('⚠️ فشل فحص سرعة الاتصال: $e');
      _isSlowConnection = true;
      _maxConcurrentRequests = 1;
    }
  }

  /// ✅ تنفيذ طلب مع التحكم في التزامن
  Future<T?> executeRequest<T>(
      Future<T> Function() request, {
        String? debugName,
        bool priority = false,
      }) async {
    if (!_isConnected) {
      print('📴 لا يوجد اتصال، تخطي الطلب: ${debugName ?? "unknown"}');
      return null;
    }

    // ✅ إذا كان الطلب ذو أولوية، نفذه مباشرة
    if (priority && _currentRequests < _maxConcurrentRequests) {
      return await _executeWithTimeout(request, debugName);
    }

    // ✅ إذا وصلنا للحد الأقصى، أضف للقائمة
    if (_currentRequests >= _maxConcurrentRequests) {
      print('⏳ الطلبات ممتلئة، إضافة للقائمة: ${debugName ?? "unknown"}');

      final completer = Completer<T?>();
      _requestQueue.add(() async {
        final result = await _executeWithTimeout(request, debugName);
        completer.complete(result);
      });

      return completer.future;
    }

    return await _executeWithTimeout(request, debugName);
  }

  /// ✅ تنفيذ الطلب مع Timeout
  Future<T?> _executeWithTimeout<T>(
      Future<T> Function() request,
      String? debugName,
      ) async {
    _currentRequests++;

    try {
      print('📡 تنفيذ طلب: ${debugName ?? "unknown"} (${_currentRequests}/$_maxConcurrentRequests)');

      final result = await request().timeout(
        _requestTimeout,
        onTimeout: () {
          print('⏱️ انتهى وقت الطلب: ${debugName ?? "unknown"}');
          throw TimeoutException('Request timeout');
        },
      );

      print('✅ نجح الطلب: ${debugName ?? "unknown"}');
      return result;

    } catch (e) {
      print('❌ فشل الطلب: ${debugName ?? "unknown"} - $e');
      return null;
    } finally {
      _currentRequests--;
      _processQueue();
    }
  }

  /// ✅ معالجة قائمة الانتظار
  void _processQueue() {
    while (_requestQueue.isNotEmpty && _currentRequests < _maxConcurrentRequests) {
      final request = _requestQueue.removeAt(0);
      request();
    }
  }

  /// ✅ مسح قائمة الانتظار
  void clearQueue() {
    _requestQueue.clear();
    print('🗑️ تم مسح قائمة الانتظار');
  }

  /// ✅ الحصول على حالة الخدمة
  Map<String, dynamic> getStatus() {
    return {
      'isConnected': _isConnected,
      'isSlowConnection': _isSlowConnection,
      'currentRequests': _currentRequests,
      'maxRequests': _maxConcurrentRequests,
      'queueLength': _requestQueue.length,
      'timeout': _requestTimeout.inSeconds,
    };
  }
}