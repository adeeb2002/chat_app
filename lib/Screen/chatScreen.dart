import 'dart:async';

import 'package:ChatApp/Provider/chatProvider.dart';
import 'package:ChatApp/Provider/messageProvder.dart';
import 'package:ChatApp/Provider/userProvide.dart';
import 'package:ChatApp/model/chat.dart';
import 'package:ChatApp/model/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:intl/intl.dart';
import '../model/Message.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final Chat chat;
  final String receiverEmail;
  final String? receiverName;

  const ChatScreen({
    super.key,
    required this.chat,
    required this.receiverEmail,
    this.receiverName,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  bool _isFirstLoad = true;
  bool isConnected=false;
  StreamSubscription? connectionSubscription;
  // ✅ متغيرات لتتبع حالة الحظر الفعلية
  bool _isBlocked = false;
  String? _blockedBy;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();

    // مراقبة الاتصال بشكل حي
    connectionSubscription = InternetConnection().onStatusChange.listen((status) {
      final hasConnection = status == InternetStatus.connected;

      // تحديث الحالة فقط إذا تغيرت لتجنب Rebuild غير ضروري
      if (isConnected != hasConnection) {
        setState(() {
          isConnected = hasConnection;
        });

        if (isConnected) {
          // إذا عاد الإنترنت، نحدث البيانات
          final currentUserEmail = ref.read(appUserEmailProvider);
          if (currentUserEmail != null) {
            ref.invalidate(chatsProvider(currentUserEmail));
          }
        }
      }
    });
    // ✅ لا نستخدم ref.listen هنا
  }


  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    connectionSubscription?.cancel(); // ← أضف هذا السطر
    super.dispose();
  }

  // ✅ دالة تحديث حالة الحظر - تستخدم في build
  void _updateBlockStatus(Map<String, dynamic>? status) {
    if (mounted) {
      final newIsBlocked = status?['isBlocked'] == true;
      final newBlockedBy = status?['blockedBy'];

      if (_isBlocked != newIsBlocked || _blockedBy != newBlockedBy) {
        setState(() {
          _isBlocked = newIsBlocked;
          _blockedBy = newBlockedBy;
        });
        print(
          '🔄 تحديث حالة الحظر: isBlocked=$_isBlocked, blockedBy=$_blockedBy',
        );
      }
    }
  }

  Future<void> _markMessagesAsRead() async {
    final currentUser = ref.read(appUserDataProvider);
    if (currentUser != null && currentUser.email.isNotEmpty) {
      try {
        await ref
            .read(messageServiceProvider)
            .markMessagesAsRead(widget.chat.id, currentUser.email);
      } catch (e) {
        print('❌ خطأ في تحديث حالة القراءة: $e');
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent > 0) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final currentUser = ref.read(appUserDataProvider);

    // التحققات الأساسية (تبقى كما هي)
    final isUserBlocked = _isBlocked && _blockedBy == currentUser?.email;
    if (isUserBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكنك إرسال رسالة، تم حظر هذا المستخدم'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء كتابة رسالة'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (currentUser == null || currentUser.email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('خطأ: المستخدم غير مسجل الدخول'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (widget.receiverEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('خطأ: بيانات المستلم غير صحيحة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // إنشاء معرف مؤقت
    final tempMessageId = DateTime.now().millisecondsSinceEpoch.toString();

    final message = Message(
      id: tempMessageId,
      senderUser: currentUser.email,
      resevUser: widget.receiverEmail,
      body: text,
      chatId: widget.chat.id,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      isRead: false,
      isDeleted: false,
      isSynced: isConnected, // استخدام حالة الاتصال الحالية
    );

    // تنظيف المدخلات والتمرير
    _messageController.clear();
    _scrollToBottom();

    // ⚠️ لا نستخدم await هنا لكي لا ننتظر الرد
    ref.read(messageServiceProvider).sendMassege(message).catchError((e) {
      print("❌ فشل إرسال الرسالة: $e");
      // يمكنك هنا تحديث حالة الرسالة إلى "فشل الإرسال" إذا أردت
    });
  }


  String _formatTime(int timestamp) {
    if (timestamp == 0) return '';

    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();

    // إذا كان التاريخ اليوم
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return DateFormat('h:mm a').format(date);
    }

    // إذا كان أمس
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'أمس';
    }

    // باقي الحالات
    if (date.year == now.year) {
      return DateFormat('d MMM').format(date);
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final messagesAsync = ref.watch(messagesProvider(widget.chat.id));
    final currentUser = ref.watch(appUserDataProvider);
    final receiverData = ref.watch(userDataProvider(widget.receiverEmail));

    // ✅ مراقبة حالة الحظر من داخل build
    final blockStatus = ref.watch(chatBlockStatusProvider(widget.chat.id));

    // ✅ تحديث الحالة المحلية عند تغيير البيانات
    blockStatus.whenData((status) {
      if (mounted) {
        final newIsBlocked = status?['isBlocked'] == true;
        final newBlockedBy = status?['blockedBy'];

        if (_isBlocked != newIsBlocked || _blockedBy != newBlockedBy) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _isBlocked = newIsBlocked;
                _blockedBy = newBlockedBy;
              });
            }
          });
        }
      }
    });

    final receiverName =
        widget.receiverName ?? (widget.receiverEmail.split('@').first);

    // ✅ التحقق من الحظر باستخدام المتغيرات المحدثة
    final isUserBlocked = _isBlocked && _blockedBy == currentUser?.email;

    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD),
      appBar: _buildAppBar(receiverName, receiverData, isUserBlocked),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (_isFirstLoad && messages.isNotEmpty) {
                  _isFirstLoad = false;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom();
                  });
                } else if (messages.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      final isNearBottom =
                          _scrollController.position.pixels >=
                          _scrollController.position.maxScrollExtent - 200;
                      if (isNearBottom) {
                        _scrollToBottom();
                      }
                    }
                  });
                }

                if (messages.isEmpty) {
                  return _buildEmptyState(receiverName, receiverData);
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: messages.length,
                  reverse: false,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe =
                        currentUser != null &&
                        message.senderUser == currentUser.email;

                    final isSameSenderAsPrevious =
                        index > 0 &&
                        messages[index - 1].senderUser == message.senderUser;
                    final isSameSenderAsNext =
                        index < messages.length - 1 &&
                        messages[index + 1].senderUser == message.senderUser;

                    return _buildMessageBubble(
                      message,
                      isMe,
                      isSameSenderAsPrevious,
                      isSameSenderAsNext,
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.green),
              ),
              error: (error, stackTrace) => _buildErrorState(error.toString()),
            ),
          ),
          _buildMessageInput(isUserBlocked, widget.chat.id, currentUser!.id!),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    String receiverName,
    AsyncValue<AppUser?> receiverData,
    bool isUserBlocked,
  ) {
    return AppBar(
      backgroundColor: const Color(0xFF075E54),
      elevation: 1,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green[100],
            ),
            child: receiverData.when(
              data: (user) {
                final name = user?.displayName ?? receiverName;
                final imageUrl = user?.imageUrl;
                return CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.green[50],
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            imageUrl,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Text(
                              name[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        )
                      : Text(
                          name[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                );
              },
              loading: () => const CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, __) => CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[300],
                child: Text(
                  receiverName[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  receiverName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (isUserBlocked)
                  const Text(
                    'تم حظر هذا المستخدم',
                    style: TextStyle(color: Colors.red, fontSize: 11),
                  )
                else
                  receiverData.when(
                    data: (user) => Text(
                      user?.isOnline == true ? 'متصل الآن' : 'غير متصل',
                      style: const TextStyle(
                        color: Color(0xFFB0BEC5),
                        fontSize: 12,
                      ),
                    ),
                    loading: () => const Text(
                      'جاري التحميل...',
                      style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 12),
                    ),
                    error: (_, __) => const Text(
                      'غير معروف',
                      style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.videocam, color: Colors.white),
          onPressed: () => _showComingSoonMessage(),
        ),
        IconButton(
          icon: const Icon(Icons.call, color: Colors.white),
          onPressed: () => _showComingSoonMessage(),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) => _handlePopupMenu(value),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'clear', child: Text('مسح المحادثة')),
            PopupMenuItem(
              value: 'block',
              child: Text(isUserBlocked ? 'إلغاء الحظر' : 'حظر المستخدم'),
            ),
            const PopupMenuItem(
              value: 'report',
              child: Text('الإبلاغ عن محتوى غير مناسب'),
            ),
          ],
        ),
      ],
    );
  }

  void _showComingSoonMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('هذه الميزة قريباً'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _handlePopupMenu(String value) {
    switch (value) {
      case 'clear':
        _showClearChatDialog();
        break;
      case 'block':
        _showBlockUserDialog();
        break;
      case 'report':
        _showReportDialog();
        break;
    }
  }

  Future<void> _showClearChatDialog() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مسح المحادثة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('هل أنت متأكد من مسح جميع الرسائل؟'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'سيتم مسح جميع الرسائل ولن تتمكن من استعادتها',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('مسح'),
          ),
        ],
      ),
    );

    if (shouldClear == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        await ref.read(chatServiceProvider).clearChat(widget.chat.id);

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('تم مسح جميع الرسائل')));
          ref.invalidate(messagesProvider(widget.chat.id));
          Navigator.pop(context); // إغلاق مؤشر التحميل
          Navigator.pop(context); // العودة للشاشة السابقة
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('خطأ في مسح الرسائل: $e')));
        }
      }
    }
  }

  Future<void> _showBlockUserDialog() async {
    final currentUser = ref.read(appUserDataProvider);
    if (currentUser == null) return;

    final isCurrentlyBlocked = _isBlocked && _blockedBy == currentUser.email;

    if (isCurrentlyBlocked) {
      final shouldUnblock = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('إلغاء حظر المستخدم'),
          content: Text(
            'هل أنت متأكد من إلغاء حظر ${widget.receiverEmail.split('@').first}؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('إلغاء الحظر'),
            ),
          ],
        ),
      );

      if (shouldUnblock == true) {
        try {
          await ref
              .read(chatServiceProvider)
              .unblockUser(widget.chat.id, currentUser.email);

          ref.invalidate(chatBlockStatusProvider(widget.chat.id));
          ref.invalidate(messagesProvider(widget.chat.id));

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم إلغاء حظر المستخدم')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
          }
        }
      }
    } else {
      final shouldBlock = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('حظر المستخدم'),
          content: Text(
            'هل أنت متأكد من حظر ${widget.receiverEmail.split('@').first}؟\n\nلن تتمكن من إرسال أو استقبال رسائل من هذا المستخدم.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('حظر'),
            ),
          ],
        ),
      );

      if (shouldBlock == true) {
        try {
          await ref
              .read(chatServiceProvider)
              .blockUser(widget.chat.id, currentUser.email);

          ref.invalidate(chatBlockStatusProvider(widget.chat.id));
          ref.invalidate(messagesProvider(widget.chat.id));

          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('تم حظر المستخدم')));
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
          }
        }
      }
    }
  }

  Future<void> _showReportDialog() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الإبلاغ عن محتوى غير مناسب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.message),
              title: const Text('رسائل مزعجة'),
              onTap: () => Navigator.pop(context, 'spam'),
            ),
            ListTile(
              leading: const Icon(Icons.person_off),
              title: const Text('تحرش أو مضايقة'),
              onTap: () => Navigator.pop(context, 'harassment'),
            ),
            ListTile(
              leading: const Icon(Icons.warning),
              title: const Text('محتوى غير مناسب'),
              onTap: () => Navigator.pop(context, 'inappropriate'),
            ),
          ],
        ),
      ),
    );

    if (reason != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تم الإبلاغ بنجاح، سبب: $reason')));
    }
  }

  Widget _buildEmptyState(
    String receiverName,
    AsyncValue<AppUser?> receiverData,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          receiverData.when(
            data: (user) {
              final name = user?.displayName ?? receiverName;
              final imageUrl = user?.imageUrl;
              return Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green[50],
                ),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          imageUrl,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.person,
                            size: 50,
                            color: Colors.green[300],
                          ),
                        ),
                      )
                    : Icon(Icons.person, size: 50, color: Colors.green[300]),
              );
            },
            loading: () => Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green[50],
              ),
              child: const CircularProgressIndicator(),
            ),
            error: (_, __) => Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green[50],
              ),
              child: const Icon(Icons.person, size: 50),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            receiverName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF303030),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 14, color: Color(0xFF8D6E63)),
                SizedBox(width: 8),
                Text(
                  'الرسائل مشفرة من الطرف إلى الطرف',
                  style: TextStyle(fontSize: 12, color: Color(0xFF8D6E63)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'لا توجد رسائل بعد',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 8),
          const Text(
            'أرسل رسالتك الأولى الآن',
            style: TextStyle(color: Colors.green, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'حدث خطأ',
            style: TextStyle(fontSize: 18, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              ref.invalidate(messagesProvider(widget.chat.id));
            },
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    Message message,
    bool isMe,
    bool isSameSenderAsPrevious,
    bool isSameSenderAsNext,
  ) {

    // ✅ إذا كانت الرسالة محذوفة للجميع، لا نعرضها
    if (message.isDeleted && message.body.contains('تم حذف')) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.body,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onLongPress: () {
        // فقط المرسل يمكنه التعديل أو الحذف
        if (isMe) {
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit, color: Colors.green),
                    title: const Text('تعديل الرسالة'),
                    onTap: () {
                      Navigator.pop(context);
                      _showEditMessageDialog(message);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('حذف الرسالة'),
                    onTap: () {
                      Navigator.pop(context);
                      _showDeleteMessageDialog(message);
                    },
                  ),
                ],
              ),
            ),
          );
        }
      },
      child: Padding(
        padding: EdgeInsets.only(
          top: isSameSenderAsPrevious ? 2 : 8,
          bottom: isSameSenderAsNext ? 2 : 8,
          left: isMe ? 60 : 0,
          right: isMe ? 0 : 60,
        ),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!isMe && !isSameSenderAsPrevious)
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: Text(
                    message.senderUser.split('@').first,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isMe ? const Color(0xFFDCF8C6) : Colors.white,
                  borderRadius: _getMessageBorderRadius(
                    isMe,
                    isSameSenderAsPrevious,
                    isSameSenderAsNext,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // ✅ عرض النص مع علامة "تم التعديل" إذا وجدت
                    Text(
                      message.body,
                      style: const TextStyle(
                        color: Color(0xFF303030),
                        fontSize: 15,
                      ),
                    ),
                    if (message.editedAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '(تم التعديل)',
                        style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.timestamp),
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey[500],
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            !message.isSynced!
                                ? Icons.access_time  // لم يتم الإرسال بعد (في انتظار الاتصال)
                                : (message.isRead
                                ? Icons.done_all   // تمت القراءة
                                : Icons.done),     // تم الإرسال فقط
                            size: 14,
                            color: !message.isSynced!
                                ? Colors.orange
                                : (message.isRead ? Colors.blue : Colors.grey[400]),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ نافذة تعديل الرسالة
  Future<void> _showEditMessageDialog(Message message) async {
    final TextEditingController editController = TextEditingController();
    editController.text = message.body;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit, color: Colors.green),
            SizedBox(width: 8),
            Text('تعديل الرسالة'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: editController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'اكتب النص الجديد...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              'سيظهر للمستلم أن الرسالة تم تعديلها',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (editController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('حفظ التعديل'),
          ),
        ],
      ),
    );

    if (result == true && editController.text.trim().isNotEmpty) {
      setState(() => _isSending = true);
      try {
        await ref
            .read(messageServiceProvider)
            .editMessage(
              chatId: widget.chat.id,
              messageId: message.id,
              newBody: editController.text.trim(),
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ تم تعديل الرسالة'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ فشل التعديل: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSending = false);
      }
    }
  }

  // ✅ نافذة حذف الرسالة
  Future<void> _showDeleteMessageDialog(Message message) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete, color: Colors.red),
            SizedBox(width: 8),
            Text('حذف الرسالة'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('هل أنت متأكد من حذف هذه الرسالة؟'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'لن يتمكن ${message.senderUser == ref.read(appUserEmailProvider) ? 'المستلم' : 'المرسل'} من رؤية هذه الرسالة بعد الحذف',
                      style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      setState(() => _isSending = true);
      try {
        await ref
            .read(messageServiceProvider)
            .deleteMessage(
              chatId: widget.chat.id,
              messageId: message.id,
              forEveryone: true, // true: حذف للجميع، false: حذف لي فقط
            );

        // تحديث الـ Stream
        ref.invalidate(messagesProvider(widget.chat.id));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ تم حذف الرسالة'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ فشل الحذف: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSending = false);
      }
    }
  }

  BorderRadius _getMessageBorderRadius(
    bool isMe,
    bool isSameSenderAsPrevious,
    bool isSameSenderAsNext,
  ) {
    if (isMe) {
      return BorderRadius.only(
        topLeft: const Radius.circular(16),
        topRight: const Radius.circular(16),
        bottomLeft: const Radius.circular(16),
        bottomRight: isSameSenderAsNext
            ? const Radius.circular(4)
            : const Radius.circular(16),
      );
    } else {
      return BorderRadius.only(
        topLeft: isSameSenderAsPrevious
            ? const Radius.circular(4)
            : const Radius.circular(16),
        topRight: const Radius.circular(16),
        bottomLeft: const Radius.circular(16),
        bottomRight: const Radius.circular(16),
      );
    }
  }

  Widget _buildMessageInput(bool isUserBlocked, String chatId, String myId) {
    if (isUserBlocked) {
      return Container(
        height: 80,
        width: double.infinity,
        color: Colors.grey[100],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'تم حظر هذه المحادثة',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'لن تتمكن من إرسال أو استقبال رسائل من ${widget.receiverEmail.split('@').first}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  ref.read(chatServiceProvider).unblockUser(chatId, myId);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'إلغاء الحظر',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file, color: Colors.grey),
              onPressed: () => _showComingSoonMessage(),
            ),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 100),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextFormField(
                  controller: _messageController,
                  maxLines: null,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'اكتب رسالتك...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onFieldSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(left: 8),
              child: _isSending
                  ? const SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.green,
                        ),
                      ),
                    )
                  : IconButton(
                      onPressed: _sendMessage,
                      icon: CircleAvatar(
                        backgroundColor: Colors.green,
                        child: const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
