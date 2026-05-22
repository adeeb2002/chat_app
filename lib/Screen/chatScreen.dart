import 'dart:async';

import 'package:ChatApp/Provider/chatProvider.dart';
import 'package:ChatApp/Provider/messageProvder.dart';
import 'package:ChatApp/Provider/userProvide.dart';
import 'package:ChatApp/model/chat.dart';
import 'package:ChatApp/model/user.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Notifications/notifications.dart';
import '../model/Message.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final Chat chat;
  final String receiverPhone;
  final String? receiverName;

  const ChatScreen({
    super.key,
    required this.chat,
    required this.receiverPhone,
    this.receiverName,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Message> _pendingMessages = [];
  bool _isFirstLoad = true;
  bool isConnected = false;
  StreamSubscription? connectionSubscription;
  bool _isBlocked = false;
  String? _blockedBy;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();
    _scrollToBottom();

    NotificationService.currentOpenChatId = widget.chat.id;

    connectionSubscription = InternetConnection().onStatusChange.listen((status) {
      final hasConnection = status == InternetStatus.connected;

      if (isConnected != hasConnection) {
        setState(() {
          isConnected = hasConnection;
        });

        if (isConnected) {
          final currentUserPhone = ref.read(appUserPhoneProvider);
          if (currentUserPhone != null) {
            ref.invalidate(chatsProvider(currentUserPhone));
            ref.invalidate(messagesProvider(widget.chat.id));
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    connectionSubscription?.cancel();
    _pendingMessages.clear();

    if (NotificationService.currentOpenChatId == widget.chat.id) {
      NotificationService.currentOpenChatId = null;
    }

    super.dispose();
  }

  void _addPendingMessage(Message message) {
    setState(() {
      _pendingMessages.add(message);
      _pendingMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    });
    _scrollToBottom();
  }

  void _removePendingMessage(String messageId) {
    setState(() {
      _pendingMessages.removeWhere((msg) => msg.id == messageId);
    });
  }

  List<Message> _getCombinedMessages(List<Message> firebaseMessages) {
    final combined = <Message>[..._pendingMessages];

    for (var msg in firebaseMessages) {
      if (!_pendingMessages.any((pending) => pending.id == msg.id)) {
        combined.add(msg);
      }
    }

    combined.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return combined;
  }

  Future<void> _markMessagesAsRead() async {
    final currentUser = ref.read(appUserDataProvider);
    if (currentUser != null && currentUser.phone.isNotEmpty) {
      try {
        await ref
            .read(messageServiceProvider)
            .markMessagesAsRead(widget.chat.id, currentUser.phone);
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

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final currentUser = ref.read(appUserDataProvider);

    final isUserBlocked = _isBlocked && _blockedBy == currentUser?.phone;
    if (isUserBlocked) {
      _showErrorSnackBar('لا يمكنك إرسال رسالة، تم حظر هذا المستخدم');
      return;
    }

    if (text.isEmpty) {
      _showErrorSnackBar('الرجاء كتابة رسالة');
      return;
    }

    if (currentUser == null || currentUser.phone.isEmpty) {
      _showErrorSnackBar('خطأ: المستخدم غير مسجل الدخول');
      return;
    }

    if (widget.receiverPhone.isEmpty) {
      _showErrorSnackBar('خطأ: بيانات المستلم غير صحيحة');
      return;
    }

    _messageController.clear();

    final tempMessageId = DateTime.now().millisecondsSinceEpoch.toString();

    final message = Message(
      id: tempMessageId,
      senderUser: currentUser.phone,
      resevUser: widget.receiverPhone,
      body: text,
      chatId: widget.chat.id,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      isRead: false,
      isDeleted: false,
      isSynced: isConnected,
    );

    _addPendingMessage(message);

    try {
      final chatService = ref.read(chatServiceProvider);
      final isDelete = await chatService.isChatDeletedForUser(widget.chat.id, currentUser.phone);
      if (isDelete) {
        await chatService.restoreDeletedChat(widget.chat.id, currentUser.phone);
      }
    } catch (e) {
      print("⚠️ فشل التحقق من حالة حذف المحادثة: $e");
    }

    ref.read(messageServiceProvider).sendMessage(message, tempMessageId).then((_) {
      _removePendingMessage(tempMessageId);
      ref.invalidate(messagesProvider(widget.chat.id));
    }).catchError((e) {
      print('❌ فشل الإرسال: $e');
      _removePendingMessage(tempMessageId);
      if (mounted) {
        _showErrorSnackBar('فشل إرسال الرسالة');
      }
    });
  }

  String _formatTime(int timestamp) {
    if (timestamp == 0) return '';

    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return DateFormat('h:mm a').format(date);
    }

    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'أمس';
    }

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
    final receiverData = ref.watch(userDataProvider(widget.receiverPhone));

    final allMessages = messagesAsync.when(
      data: (messages) => _getCombinedMessages(messages),
      loading: () => _pendingMessages,
      error: (_, __) => _pendingMessages,
    );

    final blockStatus = ref.watch(chatBlockStatusProvider(widget.chat.id));

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

    final receiverName = widget.receiverName ?? (widget.receiverPhone);
    final isUserBlocked = _isBlocked && _blockedBy == currentUser?.phone;

    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD),
      appBar: _buildAppBar(receiverName, receiverData, isUserBlocked),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (_isFirstLoad && allMessages.isNotEmpty) {
                  _isFirstLoad = false;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom();
                  });
                }

                if (allMessages.isEmpty) {
                  return _buildEmptyState(receiverName, receiverData);
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: allMessages.length,
                  itemBuilder: (context, index) {
                    final message = allMessages[index];
                    final isMe = currentUser != null && message.senderUser == currentUser.phone;

                    final isPending = _pendingMessages.any((m) => m.id == message.id);
                    final isSameSenderAsPrevious = index > 0 && allMessages[index - 1].senderUser == message.senderUser;
                    final isSameSenderAsNext = index < allMessages.length - 1 && allMessages[index + 1].senderUser == message.senderUser;

                    return _buildMessageBubble(
                      message,
                      isMe,
                      isSameSenderAsPrevious,
                      isSameSenderAsNext,
                      isPending: isPending,
                    );
                  },
                );
              },
              loading: () {
                if (_pendingMessages.isNotEmpty) {
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _pendingMessages.length,
                    itemBuilder: (context, index) {
                      final message = _pendingMessages[index];
                      final isMe = currentUser != null && message.senderUser == currentUser.phone;
                      return _buildMessageBubble(message, isMe, false, false, isPending: true);
                    },
                  );
                }
                return const Center(child: CircularProgressIndicator(color: Colors.green));
              },
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
                return InkWell(
                  onTap: () => _showProfileBottomSheet(),
                  child: CircleAvatar(
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
            child: InkWell(
              onTap: () => _showProfileBottomSheet(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    receiverName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isUserBlocked)
                    const Text(
                      'تم حظر هذا المستخدم',
                      style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                    )
                  else
                    receiverData.when(
                      data: (user) => Text(
                        user?.isOnline == true ? 'متصل الآن' : 'غير متصل',
                        style: const TextStyle(
                          color: Color(0xFFB0BEC5),
                          fontWeight: FontWeight.bold,
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
            const PopupMenuItem(value: 'clear', child: Text('مسح المحادثة', style: TextStyle(fontWeight: FontWeight.bold))),
            PopupMenuItem(
              value: 'block',
              child: Text(isUserBlocked ? 'إلغاء الحظر' : 'حظر المستخدم', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const PopupMenuItem(
              value: 'report',
              child: Text('الإبلاغ عن محتوى غير مناسب', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }

  void _showComingSoonMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('هذه الميزة قريباً', style: TextStyle(fontWeight: FontWeight.bold)),
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
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) {
        return Dialog(
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 6,
                  width: 60,
                  margin: const EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 48,
                    color: Colors.orange[600],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'مسح المحادثة',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF303030),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  child: const Text(
                    'هل أنت متأكد من مسح جميع الرسائل؟',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF303030),
                        fontWeight: FontWeight.bold
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.orange[700]),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'سيتم مسح جميع الرسائل ولن تتمكن من استعادتها',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context, false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(
                                'إلغاء',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context, true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.red[600]!, Colors.orange[600]!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                'مسح الكل',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (result == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Material(
            type: MaterialType.transparency,
            child: CircularProgressIndicator(color: Color(0xFF075E54)),
          ),
        ),
      );

      try {
        await ref.read(chatServiceProvider).clearChat(widget.chat.id);

        if (mounted) {
          Navigator.pop(context);
          ref.invalidate(messagesProvider(widget.chat.id));
          _showSuccessSnackBar('تم مسح جميع الرسائل');
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          _showErrorSnackBar('خطأ في مسح الرسائل');
        }
      }
    }
  }

  Future<void> _showBlockUserDialog() async {
    final currentUser = ref.read(appUserDataProvider);
    if (currentUser == null) return;

    final isCurrentlyBlocked = _isBlocked && _blockedBy == currentUser.phone;

    if (isCurrentlyBlocked) {
      final shouldUnblock = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(0.6),
        builder: (context) {
          return Dialog(
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 6,
                    width: 60,
                    margin: const EdgeInsets.only(top: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_outline,
                      size: 48,
                      color: Colors.green[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'إلغاء حظر المستخدم',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF303030),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'هل أنت متأكد من إلغاء حظر ${widget.receiverPhone}؟',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Colors.green[700]),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'بعد إلغاء الحظر، سيتمكن المستخدم من إرسال واستقبال الرسائل',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context, false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Text(
                                  'إلغاء',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context, true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.green[600]!, Colors.green[400]!],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  'إلغاء الحظر',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      );

      if (shouldUnblock == true) {
        try {
          await ref
              .read(chatServiceProvider)
              .unblockUser(widget.chat.id, currentUser.phone);

          ref.invalidate(chatBlockStatusProvider(widget.chat.id));
          ref.invalidate(messagesProvider(widget.chat.id));

          if (mounted) {
            _showSuccessSnackBar('تم إلغاء حظر المستخدم بنجاح');
          }
        } catch (e) {
          if (mounted) {
            _showErrorSnackBar('فشل إلغاء الحظر');
          }
        }
      }
    } else {
      final shouldBlock = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(0.6),
        builder: (context) {
          return Dialog(
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 6,
                    width: 60,
                    margin: const EdgeInsets.only(top: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.block,
                      size: 48,
                      color: Colors.red[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'حظر المستخدم',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF303030),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'هل أنت متأكد من حظر ${widget.receiverPhone}؟',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 18, color: Colors.red[700]),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'لن تتمكن من إرسال أو استقبال رسائل من هذا المستخدم',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context, false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Text(
                                  'إلغاء',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context, true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.red[600]!, Colors.red[400]!],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  'حظر',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      );

      if (shouldBlock == true) {
        try {
          await ref
              .read(chatServiceProvider)
              .blockUser(widget.chat.id, currentUser.phone);

          ref.invalidate(chatBlockStatusProvider(widget.chat.id));
          ref.invalidate(messagesProvider(widget.chat.id));

          if (mounted) {
            _showSuccessSnackBar('تم حظر المستخدم بنجاح');
          }
        } catch (e) {
          if (mounted) {
            _showErrorSnackBar('فشل حظر المستخدم');
          }
        }
      }
    }
  }

  Future<void> _showReportDialog() async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) {
        return Dialog(
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 6,
                  width: 60,
                  margin: const EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.report_problem,
                    size: 48,
                    color: Colors.orange[600],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'الإبلاغ عن محتوى غير مناسب',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF303030),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'اختر سبب الإبلاغ عن المستخدم ${widget.receiverPhone}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      _buildReportOption(
                        context: context,
                        icon: Icons.message,
                        iconColor: Colors.blue,
                        title: 'رسائل مزعجة',
                        subtitle: 'يحتوي على رسائل غير مرغوب فيها أو إعلانات',
                        value: 'spam',
                      ),
                      Divider(height: 1, color: Colors.grey[200]),
                      _buildReportOption(
                        context: context,
                        icon: Icons.person_off,
                        iconColor: Colors.red,
                        title: 'تحرش أو مضايقة',
                        subtitle: 'سلوك غير لائق أو مضايقات متكررة',
                        value: 'harassment',
                      ),
                      Divider(height: 1, color: Colors.grey[200]),
                      _buildReportOption(
                        context: context,
                        icon: Icons.warning,
                        iconColor: Colors.orange,
                        title: 'محتوى غير مناسب',
                        subtitle: 'صور أو كلمات مسيئة أو مخالفة للقوانين',
                        value: 'inappropriate',
                      ),
                      Divider(height: 1, color: Colors.grey[200]),
                      _buildReportOption(
                        context: context,
                        icon: Icons.person_add_disabled,
                        iconColor: Colors.purple,
                        title: 'انتحال شخصية',
                        subtitle: 'يتظاهر بأنه شخص آخر',
                        value: 'impersonation',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          'إلغاء',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (result != null) {
      try {
        final database = ref.read(chatDatabaseProvider);
        await database.ref('reports').push().set({
          'reporterPhone': ref.read(appUserPhoneProvider),
          'reportedPhone': widget.receiverPhone,
          'chatId': widget.chat.id,
          'reason': result,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'status': 'pending',
        });
        _showSuccessSnackBar('تم الإبلاغ بنجاح، سيتم مراجعة البلاغ');
      } catch (e) {
        _showErrorSnackBar('فشل الإبلاغ، حاول مرة أخرى');
      }
    }
  }

  Widget _buildReportOption({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String value,
  }) {
    return InkWell(
      onTap: () => Navigator.pop(context, value),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF303030),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String receiverName, AsyncValue<AppUser?> receiverData) {
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
                Icon(
                  Icons.lock_outline,
                  size: 14,
                  color: Color(0xFF8D6E63),
                ),
                SizedBox(width: 8),
                Text(
                  'الرسائل مشفرة من الطرف إلى الطرف',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8D6E63),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'لا توجد رسائل بعد',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'أرسل رسالتك الأولى الآن',
            style: TextStyle(
              color: Colors.green,
              fontSize: 12,
            ),
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
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[700],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              ref.invalidate(messagesProvider(widget.chat.id));
            },
            icon: const Icon(Icons.refresh),
            label: const Text(
              'إعادة المحاولة',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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
      bool isSameSenderAsNext, {
        bool isPending = false,
      }) {
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
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe && !isSameSenderAsPrevious)
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: Text(
                    message.senderUser,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          if (isPending)
                            const Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.orange,
                            )
                          else
                            Icon(
                              message.isRead ? Icons.done_all : Icons.done,
                              size: 14,
                              color: message.isRead ? Colors.blue : Colors.grey[400],
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

  Future<void> _showEditMessageDialog(Message message) async {
    final TextEditingController editController = TextEditingController();
    editController.text = message.body;
    final FocusNode focusNode = FocusNode();

    Future.delayed(const Duration(milliseconds: 100), () {
      focusNode.requestFocus();
    });

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 6,
                      width: 60,
                      margin: const EdgeInsets.only(top: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 20, left: 24, right: 24),
                      child: Row(
                        children: [
                          Icon(Icons.edit_note, color: Color(0xFF075E54), size: 28),
                          SizedBox(width: 12),
                          Text(
                            'تعديل الرسالة',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF075E54),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: TextFormField(
                          controller: editController,
                          focusNode: focusNode,
                          maxLines: 5,
                          minLines: 3,
                          decoration: InputDecoration(
                            hintText: 'اكتب رسالتك الجديدة...',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 6),
                          Text(
                            'سيظهر للمستلم أن الرسالة تم تعديلها',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context, false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Text(
                                    'إلغاء',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (editController.text.trim().isNotEmpty) {
                                  Navigator.pop(context, true);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF075E54), Color(0xFF128C7E)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF075E54).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    'حفظ التعديل',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == true && editController.text.trim().isNotEmpty) {
      try {
        await ref
            .read(messageServiceProvider)
            .editMessage(
          chatId: widget.chat.id,
          messageId: message.id,
          newBody: editController.text.trim(),
        );
        if (mounted) {
          _showSuccessSnackBar('تم تعديل الرسالة بنجاح');
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar('فشل تعديل الرسالة');
        }
      }
    }
  }

  Future<void> _showDeleteMessageDialog(Message message) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) {
        return Dialog(
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 6,
                  width: 60,
                  margin: const EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    size: 48,
                    color: Colors.red[400],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'حذف الرسالة',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF303030),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'هل أنت متأكد من حذف هذه الرسالة؟\nلن يتمكن ${message.senderUser == ref.read(appUserPhoneProvider) ? 'المستلم' : 'المرسل'} من رؤيتها',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context, false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(
                                'إلغاء',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context, true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.red[600]!, Colors.red[400]!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                'حذف',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (result == true) {
      try {
        await ref
            .read(messageServiceProvider)
            .deleteMessage(
          chatId: widget.chat.id,
          messageId: message.id,
          forEveryone: true,
        );
        ref.invalidate(messagesProvider(widget.chat.id));
        if (mounted) {
          _showSuccessSnackBar('تم حذف الرسالة بنجاح');
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar('فشل حذف الرسالة');
        }
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
                    'لن تتمكن من إرسال أو استقبال رسائل من ${widget.receiverPhone}',
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'إلغاء الحظر',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                  textInputAction: TextInputAction.send,
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
              child: IconButton(
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

  void _showProfileBottomSheet() {
    final currentUser = ref.read(appUserDataProvider);
    if (currentUser == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 5,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: const Color(0xFF075E54).withOpacity(0.1),
                        child: Text(
                          currentUser.displayName.isNotEmpty
                              ? currentUser.displayName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF075E54),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      currentUser.displayName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        currentUser.phone ?? 'رقم الهاتف غير متوفر',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Chip(
                      avatar: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isConnected ? Colors.green : Colors.grey,
                        ),
                      ),
                      label: Text(
                        isConnected ? 'متصل الآن' : 'غير متصل',
                        style: TextStyle(
                          color: isConnected ? Colors.green[700] : Colors.grey[700],
                        ),
                      ),
                      backgroundColor: isConnected
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showEditProfileBottomSheet();
                            },
                            icon: const Icon(Icons.edit, size: 20),
                            label: const Text(
                              'تعديل',
                              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green,
                              side: const BorderSide(color: Colors.green),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF075E54),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'إغلاق',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showEditProfileBottomSheet() {
    final currentUser = ref.read(appUserDataProvider);
    if (currentUser == null) return;

    final nameController = TextEditingController(text: currentUser.displayName);
    final emailController = TextEditingController(text: currentUser.email ?? '');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(25),
                    topRight: Radius.circular(25),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'تعديل الملف الشخصي',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF075E54),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'اسم المستخدم',
                        labelStyle: const TextStyle(color: Color(0xFF075E54)),
                        hintText: 'أدخل اسمك الجديد',
                        prefixIcon: const Icon(Icons.person, color: Color(0xFF075E54)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF075E54), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'البريد الإلكتروني',
                        labelStyle: const TextStyle(color: Color(0xFF075E54)),
                        hintText: 'example@email.com',
                        prefixIcon: const Icon(Icons.email, color: Color(0xFF075E54)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF075E54), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSaving ? null : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Colors.grey),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('إلغاء', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSaving ? null : () async {
                              final newName = nameController.text.trim();
                              final newEmail = emailController.text.trim();

                              if (newName.isEmpty) {
                                Fluttertoast.showToast(msg: 'الاسم لا يمكن أن يكون فارغاً');
                                return;
                              }
                              if (newEmail.isEmpty) {
                                Fluttertoast.showToast(msg: 'البريد الإلكتروني لا يمكن أن يكون فارغاً');
                                return;
                              }

                              setModalState(() => isSaving = true);

                              try {
                                final database = ref.read(chatDatabaseProvider);
                                await database.ref('users').child(currentUser.id!).update({
                                  'email': newEmail,
                                  'displayName': newName,
                                });

                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setString('userEmail', newEmail);
                                await prefs.setString('userName', newName);

                                ref.read(appUserDataProvider.notifier).state = currentUser.copyWith(
                                  displayName: newName,
                                  email: newEmail,
                                );

                                _showSuccessSnackBar('تم تحديث البيانات بنجاح');

                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              } catch (e) {
                                print('❌ خطأ أثناء تحديث البيانات: $e');
                                _showErrorSnackBar('حدث خطأ أثناء حفظ البيانات');
                              } finally {
                                if (context.mounted) {
                                  setModalState(() => isSaving = false);
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF075E54),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: isSaving
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                                : const Text('حفظ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}