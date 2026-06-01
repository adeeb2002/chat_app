import 'package:ChatApp/model/ReplyToStatus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../Provider/statusProvider.dart';
import '../Provider/userProvide.dart';
import '../model/status.dart';
import '../theme/app_theme.dart';

class ViewStatusScreen extends ConsumerStatefulWidget {
  final Status status;

  const ViewStatusScreen({
    super.key,
    required this.status,
  });

  @override
  ConsumerState<ViewStatusScreen> createState() => _ViewStatusScreenState();
}

class _ViewStatusScreenState extends ConsumerState<ViewStatusScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _hasAddedView = false;
  String? _currentUserId;
  bool _isPaused = false;
  bool _showDetails = false;

  static const Duration _storyDuration = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    final userAsync = ref.read(appUserDataProvider);
    _currentUserId = userAsync?.id;

    _animationController = AnimationController(
      duration: _storyDuration,
      vsync: this,
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.of(context).pop();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ✅ حذف القصة
  Future<void> _deleteStatus() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف القصة'),
        content: const Text('هل أنت متأكد من حذف هذه القصة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(deleteStatusProvider(widget.status.id).future);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف القصة بنجاح')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في حذف القصة: $e')),
        );
      }
    }
  }

  // ✅ الرد على القصة (نسخة مصححة)
  Future<void> _replyToStatus() async {
    final replyController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رد على القصة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'أرسل رداً إلى ${widget.status.userDisplayName}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: replyController,
              maxLines: 3,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'اكتب ردك هنا...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryColor),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (replyController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('إرسال'),
          ),
        ],
      ),
    );

    if (result == true && replyController.text.trim().isNotEmpty) {
      final currentUser = ref.read(appUserDataProvider);
      if (currentUser == null) {
        _showSnackBar('يجب تسجيل الدخول أولاً', isError: true);
        return;
      }

      _showSnackBar('جاري إرسال الرد...', isError: false);

      try {
        // ✅ إنشاء كائن StatusReply بشكل صحيح (بدون senderName)
        final statusReply = StatusReply(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          statusId: widget.status.id,
          senderId: currentUser.id!,
          receiverId: widget.status.userId,
          replyText: replyController.text.trim(),
          timestamp: DateTime.now(),
          isRead: false,
        );

        // ✅ استدعاء Provider الرد
        ref.read(addStatusReplyProvider(statusReply));

        _showSnackBar('تم إرسال الرد بنجاح ✅', isError: false);

        await Future.delayed(const Duration(seconds: 1));

        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        _showSnackBar('حدث خطأ: $e', isError: true);
      }
    }
  }

  // ✅ دالة مساعدة لإظهار الرسائل
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleDetails() {
    setState(() {
      _showDetails = !_showDetails;
    });
  }

  @override
  Widget build(BuildContext context) {
    // إضافة مشاهدة
    if (!_hasAddedView && _currentUserId != null && _currentUserId != widget.status.userId) {
      final viewsAsync = ref.watch(statusViewsProvider(
        StatusViewsParams(
          userId: widget.status.userId,
          statusId: widget.status.id,
        ),
      ));

      viewsAsync.when(
        data: (views) {
          if (!views.contains(_currentUserId)) {
            ref.read(statusViewProvider(
              StatusViewParams(
                userId: widget.status.userId,
                statusId: widget.status.id,
                viewerId: _currentUserId!,
              ),
            ));
            setState(() => _hasAddedView = true);
          }
        },
        error: (e, _) => print('Error getting views: $e'),
        loading: () => null,
      );
    }

    // جلب عدد المشاهدات
    final viewsAsync = ref.watch(statusViewsProvider(
      StatusViewsParams(
        userId: widget.status.userId,
        statusId: widget.status.id,
      ),
    ));

    final isOwner = _currentUserId == widget.status.userId;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildContent(),
          Positioned(top: 0, left: 0, right: 0, child: _buildProgressBar()),
          Positioned(top: 50, left: 16, right: 16, child: _buildUserInfo(viewsAsync, isOwner)),
          Positioned(top: 50, right: 16, child: _buildCloseButton()),
          if (isOwner) Positioned(bottom: 80, left: 16, child: _buildOwnerControls()),
          if (!isOwner) Positioned(bottom: 80, right: 16, child: _buildReplyButton()),
          if (_isPaused) Positioned(bottom: 80, left: 0, right: 0, child: _buildPauseIndicator()),
          Positioned.fill(child: _buildGestureLayer()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (widget.status.isImageOnly && widget.status.imageUrl != null) {
      return Positioned.fill(
        child: widget.status.imageUrl!.startsWith('http')
            ? Image.network(
          widget.status.imageUrl!,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.grey.shade800,
            child: const Icon(Icons.broken_image, size: 50, color: Colors.white70),
          ),
        )
            : Container(
          color: Colors.grey.shade800,
          child: const Icon(Icons.image, size: 50, color: Colors.white70),
        ),
      );
    } else {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            widget.status.text ?? '',
            style: const TextStyle(fontSize: 24, color: Colors.white, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
  }

  Widget _buildProgressBar() {
    return Container(
      height: 4,
      color: Colors.white.withOpacity(0.3),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final progress = _animationController.value;
          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: MediaQuery.of(context).size.width * progress,
              height: 4,
              color: AppTheme.primaryColor,
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserInfo(AsyncValue<List<String>> viewsAsync, bool isOwner) {
    return GestureDetector(
      onTap: _toggleDetails,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primaryColor, width: 2),
            ),
            child: ClipOval(
              child: widget.status.userImageUrl != null &&
                  widget.status.userImageUrl!.startsWith('http')
                  ? Image.network(
                widget.status.userImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade700,
                  child: Icon(Icons.person, color: AppTheme.primaryColor),
                ),
              )
                  : Container(
                color: Colors.grey.shade700,
                child: Icon(Icons.person, color: AppTheme.primaryColor),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.status.userDisplayName.isNotEmpty
                          ? widget.status.userDisplayName
                          : 'مستخدم',
                      style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    if (isOwner)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('قصتك', style: TextStyle(fontSize: 10, color: Colors.white)),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTimeAgo(widget.status.timestamp),
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7)),
                ),
                if (_showDetails)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: viewsAsync.when(
                      data: (views) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('📊 المشاهدات: ${views.length}',
                              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8))),
                          const SizedBox(height: 4),
                          Text('⏱️ تنتهي: ${_formatExpiryTime(widget.status.expiresAt)}',
                              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8))),
                          const SizedBox(height: 4),
                          if (isOwner && views.isNotEmpty)
                            Text('👀 آخر مشاهد: ${_formatLastViewers(views)}',
                                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6))),
                        ],
                      ),
                      loading: () => const SizedBox(),
                      error: (_, __) => const SizedBox(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloseButton() {
    return IconButton(
      icon: const Icon(Icons.close, color: Colors.white),
      onPressed: () => Navigator.of(context).pop(),
    );
  }

  Widget _buildOwnerControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(30),
          ),
          child: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _deleteStatus,
            tooltip: 'حذف القصة',
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(30),
          ),
          child: IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ميزة المشاركة قريباً')),
              );
            },
            tooltip: 'مشاركة القصة',
          ),
        ),
      ],
    );
  }

  Widget _buildReplyButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(30),
      ),
      child: IconButton(
        icon: const Icon(Icons.reply, color: Colors.white),
        onPressed: _replyToStatus,
        tooltip: 'رد على القصة',
      ),
    );
  }

  Widget _buildPauseIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pause_circle_filled, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('متوقفة', style: TextStyle(fontSize: 12, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildGestureLayer() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (_) {
        if (_animationController.isAnimating) {
          _animationController.stop();
          setState(() => _isPaused = true);
        }
      },
      onLongPressEnd: (_) {
        if (_isPaused && mounted) {
          _animationController.forward();
          setState(() => _isPaused = false);
        }
      },
      onTapDown: (details) {
        final screenWidth = MediaQuery.of(context).size.width;
        if (details.localPosition.dy < 80) return;
        if (details.localPosition.dx < screenWidth / 3) {
          print('👈 Left tap');
        } else if (details.localPosition.dx > 2 * screenWidth / 3) {
          print('👉 Right tap');
        } else {
          Navigator.of(context).pop();
        }
      },
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
          Navigator.of(context).pop();
        }
      },
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return 'منذ ${(difference.inDays / 7).floor()} أسابيع';
    } else if (difference.inDays >= 1) {
      return 'منذ ${difference.inDays} يوم${difference.inDays == 1 ? '' : 'ين'}';
    } else if (difference.inHours >= 1) {
      return 'منذ ${difference.inHours} ساعة${difference.inHours == 1 ? '' : 'ات'}';
    } else if (difference.inMinutes >= 1) {
      return 'منذ ${difference.inMinutes} دقيقة${difference.inMinutes == 1 ? '' : 'ق'}';
    } else {
      return 'الآن';
    }
  }

  String _formatExpiryTime(DateTime expiryTime) {
    final now = DateTime.now();
    final difference = expiryTime.difference(now);

    if (difference.inHours >= 24) {
      return '${(difference.inHours / 24).floor()} يوم';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours} ساعة';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes} دقيقة';
    } else {
      return 'أقل من دقيقة';
    }
  }

  String _formatLastViewers(List<String> views) {
    if (views.length <= 2) {
      return views.join(', ');
    } else {
      return '${views.take(2).join(', ')} و ${views.length - 2} آخرين';
    }
  }
}