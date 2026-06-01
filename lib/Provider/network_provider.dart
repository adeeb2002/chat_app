import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InternetConnectionNotifier extends StateNotifier<bool> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _debounceTimer;

  InternetConnectionNotifier() : super(true) {
    _init();
  }

  void _init() async {
    final initialResult = await _connectivity.checkConnectivity();
    _evaluateStatus(initialResult);

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _evaluateStatus(results);
    });
  }

  void _evaluateStatus(List<ConnectivityResult> results) {
    final hasConnection = results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.vpn);

    if (hasConnection) {
      _debounceTimer?.cancel();
      _debounceTimer = null;
      if (state != true) {
        state = true;
      }
    } else {
      if (state == true && _debounceTimer == null) {
        _debounceTimer = Timer(const Duration(seconds: 3), () {
          state = false;
          _debounceTimer = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }
}

final internetConnectionProvider =
    StateNotifierProvider<InternetConnectionNotifier, bool>((ref) {
  return InternetConnectionNotifier();
});
