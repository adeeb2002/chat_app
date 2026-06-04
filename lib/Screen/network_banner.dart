import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../Provider/network_provider.dart';

class NetworkBannerWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const NetworkBannerWrapper({super.key, required this.child});

  @override
  ConsumerState<NetworkBannerWrapper> createState() =>
      _NetworkBannerWrapperState();
}

class _NetworkBannerWrapperState extends ConsumerState<NetworkBannerWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  bool _showSuccessBanner = false;
  bool _previousStatus = true;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentStatus = ref.watch(internetConnectionProvider);

    if (_previousStatus != currentStatus) {
      _previousStatus = currentStatus;

      if (!currentStatus) {
        setState(() => _showSuccessBanner = false);
        _animController.forward();
      } else {
        setState(() => _showSuccessBanner = true);
        _animController.forward();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && ref.read(internetConnectionProvider)) {
            _animController.reverse().then((_) {
              if (mounted) {
                setState(() => _showSuccessBanner = false);
              }
            });
          }
        });
      }
    }

    return Stack(
      children: [
        widget.child,
        SlideTransition(
          position: _slideAnimation,
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: _showSuccessBanner ? Colors.green : Colors.red,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _showSuccessBanner ? Icons.wifi : Icons.wifi_off,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _showSuccessBanner
                          ? 'تم استعادة الاتصال بالإنترنت'
                          : 'لا يوجد اتصال بالإنترنت...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
