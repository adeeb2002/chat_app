import 'dart:async';
import 'dart:convert';
import 'package:ChatApp/Provider/chatProvider.dart';
import 'package:ChatApp/Provider/userProvide.dart';
import 'package:ChatApp/model/chat.dart';
import 'package:ChatApp/model/user.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Notifications/notifications.dart';
import '../Provider/messageProvder.dart';
import '../model/Message.dart';
import '../service/ImageUploadService.dart';
import '../theme/app_theme.dart';

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

  List<Message> _pendingMessages = [];
  final Set<String> _failedMessages = {};
  final Set<String> _sendingMessages = {};

  Timer? _typingTimer;
  bool _isTyping = false;

  bool _isFirstLoad = true;
  bool isConnected = true;
  StreamSubscription? connectionSubscription;
  bool _isBlocked = false;
  String? _blockedBy;

  static const String _pendingMessagesKey = 'pending_messages_';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    NotificationService.currentOpenChatId = widget.chat.id;
    _messageController.addListener(_onTextChanged);

    _loadPendingMessages();
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    connectionSubscription = Connectivity().onConnectivityChanged.listen((result) {
      final newConnectionState = result != ConnectivityResult.none;

      if (mounted) {
        setState(() {
          isConnected = newConnectionState;
        });
      }

      if (newConnectionState && _pendingMessages.isNotEmpty) {
        _sendPendingMessages();
      }
    });

    Connectivity().checkConnectivity().then((result) {
      if (mounted) {
        setState(() {
          isConnected = result != ConnectivityResult.none;
        });
      }
    });
  }

  Future<void> _loadPendingMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _pendingMessagesKey + widget.chat.id;
      final messagesJson = prefs.getStringList(key) ?? [];

      if (messagesJson.isNotEmpty) {
        setState(() {
          _pendingMessages = messagesJson
              .map((json) => Message.fromJson(jsonDecode(json)))
              .toList();

          for (var msg in _pendingMessages) {
            _sendingMessages.add(msg.id);
          }
        });

        if (isConnected) {
          _sendPendingMessages();
        }
      }
    } catch (e) {
      print('❌ خطأ في تحميل الرسائل المعلقة: $e');
    }
  }

  Future<void> _savePendingMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _pendingMessagesKey + widget.chat.id;
      final messagesJson = _pendingMessages
          .map((msg) => jsonEncode(msg.toJson()))
          .toList();

      await prefs.setStringList(key, messagesJson);
    } catch (e) {
      print('❌ خطأ في حفظ الرسائل المعلقة: $e');
    }
  }

  Future<void> _sendPendingMessages() async {
    if (_pendingMessages.isEmpty) return;

    print('🔄 إرسال ${_pendingMessages.length} رسالة معلقة...');

    final messagesToSend = List<Message>.from(_pendingMessages);

    for (var message in messagesToSend) {
      try {
        await ref.read(messageServiceProvider).sendMessage(message, message.id);

        if (mounted) {
          setState(() {
            _pendingMessages.removeWhere((m) => m.id == message.id);
            _sendingMessages.remove(message.id);
            _failedMessages.remove(message.id);
          });
        }

        print('✅ تم إرسال رسالة معلقة: ${message.id}');
      } catch (e) {
        print('❌ فشل إرسال رسالة معلقة: ${message.id}, $e');
        _markMessageAsFailed(message.id);
      }
    }

    await _savePendingMessages();
    ref.invalidate(messagesProvider(widget.chat.id));

    if (_pendingMessages.isEmpty && mounted) {
      _showSuccessSnackBar('تم إرسال جميع الرسائل المعلقة');
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _typingTimer?.cancel();
    _setTyping(false);
    _messageController.dispose();
    _scrollController.dispose();
    connectionSubscription?.cancel();
    _failedMessages.clear();
    _sendingMessages.clear();

    if (NotificationService.currentOpenChatId == widget.chat.id) {
      NotificationService.currentOpenChatId = null;
    }

    super.dispose();
  }

  void _onTextChanged() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty && !_isTyping) {
      _setTyping(true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _setTyping(false);
    });
  }

  void _setTyping(bool typing) {
    if (_isTyping == typing) return;
    _isTyping = typing;
    final currentUser = ref.read(appUserDataProvider);
    if (currentUser != null && currentUser.phone.isNotEmpty && isConnected) {
      ref.read(chatServiceProvider).setTypingStatus(
        widget.chat.id,
        currentUser.phone,
        typing,
      );
    }
  }

  void _markMessageAsSent(String messageId) {
    if (mounted) {
      setState(() {
        _sendingMessages.remove(messageId);
        _failedMessages.remove(messageId);
      });
    }
  }

  void _markMessageAsFailed(String messageId) {
    if (mounted) {
      setState(() {
        _sendingMessages.remove(messageId);
        _failedMessages.add(messageId);
      });
    }
  }

  List<Message> _getCombinedMessages(List<Message> firebaseMessages) {
    final Map<String, Message> messageMap = {};

    for (var msg in firebaseMessages) {
      messageMap[msg.id] = msg;
    }

    for (var localMsg in _pendingMessages) {
      if (!messageMap.containsKey(localMsg.id)) {
        messageMap[localMsg.id] = localMsg;
      }
    }

    final combined = messageMap.values.toList();
    combined.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return combined;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
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
    if (!mounted) return;
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
    _typingTimer?.cancel();
    _setTyping(false);
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

    final tempMessageId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    final message = Message(
      id: tempMessageId,
      senderUser: currentUser.phone,
      resevUser: widget.receiverPhone,
      body: text,
      chatId: widget.chat.id,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      isRead: false,
      isDeleted: false,
      isSynced: false,
    );

    setState(() {
      _pendingMessages.add(message);
      _sendingMessages.add(tempMessageId);
    });

    await _savePendingMessages();
    _scrollToBottom();

    if (!isConnected) {
      _showErrorSnackBar('لا توجد اتصال. سيتم إرسال الرسالة عند عودة الاتصال');
      return;
    }

    try {
      await ref.read(messageServiceProvider).sendMessage(message, tempMessageId);

      setState(() {
        _pendingMessages.removeWhere((m) => m.id == tempMessageId);
        _sendingMessages.remove(tempMessageId);
      });

      await _savePendingMessages();
      ref.invalidate(messagesProvider(widget.chat.id));

      print('✅ تم إرسال الرسالة بنجاح');
    } catch (e) {
      print('❌ فشل الإرسال: $e');
      _markMessageAsFailed(tempMessageId);

      if (mounted) {
        _showErrorSnackBar('فشل إرسال الرسالة. سيتم المحاولة مرة أخرى');
      }
    }
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
  // ✅ التحقق مما إذا كان النص عبارة عن رابط صورة
  bool _isImageUrl(String url) {
    if (url.isEmpty || url == 'loading') return false;
    final lowerUrl = url.toLowerCase();
    return lowerUrl.startsWith('http') &&
        (lowerUrl.contains('.jpg') ||
            lowerUrl.contains('.jpeg') ||
            lowerUrl.contains('.png') ||
            lowerUrl.contains('.gif') ||
            lowerUrl.contains('.webp') ||
            lowerUrl.contains('.bmp') ||
            lowerUrl.contains('firebasestorage.googleapis.com') ||
            lowerUrl.contains('googleapis.com') ||
            lowerUrl.contains('cloudinary.com') ||
            lowerUrl.contains('imgur.com'));
  }

  // ✅ تحديد نوع الرسالة الفعلي (بغض النظر عما هو محفوظ في type)
  bool _isImageMessage(Message message) {
    return message.type == MessageType.image || _isImageUrl(message.body);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // ✅ الاستماع للتحديثات داخل build فقط
    ref.listen(messagesProvider(widget.chat.id), (previous, next) {
      next.whenData((messages) {
        if (messages.isNotEmpty && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        }
      });
    });

    final messagesAsync = ref.watch(messagesProvider(widget.chat.id));
    final currentUser = ref.watch(appUserDataProvider);
    final receiverData = ref.watch(userDataProvider(widget.receiverPhone));

    final blockStatus = ref.watch(chatBlockStatusProvider(widget.chat.id));
    final isTyping = ref.watch(chatTypingStatusProvider({
      'chatId': widget.chat.id,
      'receiverPhone': widget.receiverPhone,
    }));

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

    final receiverName = widget.receiverName ?? widget.receiverPhone;
    final isUserBlocked = _isBlocked && _blockedBy == currentUser?.phone;

    return Scaffold(
      backgroundColor: AppTheme.chatBgColor(context),
      appBar: _buildAppBar(receiverName, receiverData, isUserBlocked, isTyping.value ?? false),
      body: Column(
        children: [
          if (!isConnected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.orange,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    _pendingMessages.isEmpty
                        ? 'لا يوجد اتصال بالإنترنت'
                        : 'لا يوجد اتصال - ${_pendingMessages.length} رسالة في الانتظار',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                final allMessages = _getCombinedMessages(messages);

                if (_isFirstLoad && allMessages.isNotEmpty) {
                  _isFirstLoad = false;
                  _scrollToBottom();
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

                    final isSending = _sendingMessages.contains(message.id);
                    final isFailed = _failedMessages.contains(message.id);

                    final isSameSenderAsPrevious = index > 0 &&
                        allMessages[index - 1].senderUser == message.senderUser;
                    final isSameSenderAsNext = index < allMessages.length - 1 &&
                        allMessages[index + 1].senderUser == message.senderUser;

                    return _buildMessageBubble(
                      message,
                      isMe,
                      isSameSenderAsPrevious,
                      isSameSenderAsNext,
                      isPending: isSending,
                      isFailed: isFailed,
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
                      final isFailed = _failedMessages.contains(message.id);

                      return _buildMessageBubble(
                        message,
                        isMe,
                        false,
                        false,
                        isPending: true,
                        isFailed: isFailed,
                      );
                    },
                  );
                }
                return const Center(
                  child: CircularProgressIndicator(color: Colors.green),
                );
              },
              error: (error, stackTrace) {
                print('❌ خطأ في تحميل الرسائل: $error');

                if (_pendingMessages.isNotEmpty) {
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _pendingMessages.length,
                    itemBuilder: (context, index) {
                      final message = _pendingMessages[index];
                      final isMe = currentUser != null && message.senderUser == currentUser.phone;
                      final isFailed = _failedMessages.contains(message.id);

                      return _buildMessageBubble(
                        message,
                        isMe,
                        false,
                        false,
                        isPending: true,
                        isFailed: isFailed,
                      );
                    },
                  );
                }
                return _buildErrorState(error.toString());
              },
            ),
          ),
          _buildMessageInput(isUserBlocked, widget.chat.id, currentUser?.id ?? ''),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      String receiverName,
      AsyncValue<AppUser?> receiverData,
      bool isUserBlocked,
      bool isTyping,
      ) {
    return AppBar(
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
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Text(
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
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else if (isTyping)
                    const Text(
                      'يكتب الآن...',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
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
                        style: TextStyle(
                          color: Color(0xFFB0BEC5),
                          fontSize: 12,
                        ),
                      ),
                      error: (_, __) => const Text(
                        'غير معروف',
                        style: TextStyle(
                          color: Color(0xFFB0BEC5),
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (_pendingMessages.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'تحديث الرسائل',
            onPressed: () {
              ref.invalidate(messagesProvider(widget.chat.id));
              _showSuccessSnackBar('تم التحديث');
            },
          ),
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
            const PopupMenuItem(
              value: 'clear',
              child: Text(
                'مسح المحادثة',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            PopupMenuItem(
              value: 'block',
              child: Text(
                isUserBlocked ? 'إلغاء الحظر' : 'حظر المستخدم',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const PopupMenuItem(
              value: 'report',
              child: Text(
                'الإبلاغ عن محتوى غير مناسب',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showComingSoonMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'هذه الميزة قريباً',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
    bool deleteForEveryone = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('مسح المحادثة'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('هل أنت متأكد من مسح جميع الرسائل؟'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: deleteForEveryone,
                        onChanged: (value) {
                          setState(() {
                            deleteForEveryone = value ?? false;
                          });
                        },
                      ),
                      const Text('حذف للجميع'),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('مسح'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      try {
        final currentUser = ref.read(appUserDataProvider);
        if (deleteForEveryone) {
          await ref.read(chatServiceProvider).clearChatForEveryone(widget.chat.id);
          _showSuccessSnackBar('تم حذف المحادثة للجميع بنجاح');
        } else {
          if (currentUser == null) return;
          await ref.read(chatServiceProvider).clearChatForUser(
            widget.chat.id,
            currentUser.phone,
          );
          _showSuccessSnackBar('تم مسح جميع الرسائل بنجاح');
        }

        setState(() {
          _pendingMessages.clear();
        });
        await _savePendingMessages();

        ref.invalidate(messagesProvider(widget.chat.id));
      } catch (e) {
        _showErrorSnackBar('حدث خطأ: ${e.toString()}');
      }
    }
  }

  Future<void> _showBlockUserDialog() async {
    final currentUser = ref.read(appUserDataProvider);
    if (currentUser == null) return;

    final isCurrentlyBlocked = _isBlocked && _blockedBy == currentUser.phone;

    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isCurrentlyBlocked ? 'إلغاء الحظر' : 'حظر المستخدم'),
        content: Text(
          isCurrentlyBlocked
              ? 'هل أنت متأكد من إلغاء حظر هذا المستخدم؟'
              : 'هل أنت متأكد من حظر هذا المستخدم؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: isCurrentlyBlocked ? Colors.green : Colors.red,
            ),
            child: Text(isCurrentlyBlocked ? 'إلغاء الحظر' : 'حظر'),
          ),
        ],
      ),
    );

    if (shouldProceed == true) {
      try {
        if (isCurrentlyBlocked) {
          await ref.read(chatServiceProvider).unblockUser(widget.chat.id, currentUser.phone);
          _showSuccessSnackBar('تم إلغاء حظر المستخدم بنجاح');
        } else {
          await ref.read(chatServiceProvider).blockUser(widget.chat.id, currentUser.phone);
          _showSuccessSnackBar('تم حظر المستخدم بنجاح');
        }
        ref.invalidate(chatBlockStatusProvider(widget.chat.id));
        ref.invalidate(messagesProvider(widget.chat.id));
      } catch (e) {
        _showErrorSnackBar('فشل العملية');
      }
    }
  }

  Future<void> _showReportDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الإبلاغ عن محتوى غير مناسب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              child: ListTile(
                title: const Text('رسائل مزعجة'),
                onTap: () => Navigator.pop(context, 'spam'),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: ListTile(
                title: const Text('تحرش أو مضايقة'),
                onTap: () => Navigator.pop(context, 'harassment'),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: ListTile(
                title: const Text('محتوى غير مناسب'),
                onTap: () => Navigator.pop(context, 'inappropriate'),
              ),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        final database = ref.read(firebaseDatabaseProvider);
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

  Widget _buildEmptyState(String receiverName, AsyncValue<AppUser?> receiverData) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          receiverData.when(
            data: (user) {
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
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Icon(
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
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
        bool isFailed = false,
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
        if (isMe && !isPending && message.body != 'loading') {
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isFailed)
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        leading: const Icon(Icons.refresh, color: Colors.blue),
                        title: const Text('إعادة المحاولة'),
                        onTap: () {
                          Navigator.pop(context);
                          _retryFailedMessage(message);
                        },
                      ),
                    ),
                  if (_isImageMessage(message))
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        leading: const Icon(Icons.edit, color: Colors.green),
                        title: const Text('تعديل الرسالة'),
                        onTap: () {
                          Navigator.pop(context);
                          _showEditMessageDialog(message);
                        },
                      ),
                    ),
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      leading: const Icon(Icons.delete, color: Colors.red),
                      title: const Text('حذف الرسالة'),
                      onTap: () {
                        Navigator.pop(context);
                        _showDeleteMessageDialog(message);
                      },
                    ),
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
                  color: isFailed
                      ? Colors.red[50]
                      : (isMe ? AppTheme.messageSentColor(context) : AppTheme.messageReceivedColor(context)),
                  borderRadius: _getMessageBorderRadius(
                    isMe,
                    isSameSenderAsPrevious,
                    isSameSenderAsNext,
                  ),
                  border: isFailed ? Border.all(color: Colors.red, width: 1) : null,
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
                    if (_isImageMessage(message))
                      _buildImageContent(message, isPending, isFailed)
                    else
                      Text(
                        message.body,
                        style: TextStyle(
                          color: isFailed ? Colors.red[900] : const Color(0xFF303030),
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
                          if (isPending && !isFailed)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Colors.orange,
                              ),
                            )
                          else if (isFailed)
                            const Icon(
                              Icons.error_outline,
                              size: 14,
                              color: Colors.red,
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

  Widget _buildImageContent(Message message, bool isPending, bool isFailed) {
    if (message.body == 'loading') {
      return Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Colors.green,
              strokeWidth: 3,
            ),
            const SizedBox(height: 12),
            Text(
              'جاري رفع الصورة...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: message.body,
        width: 200,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: 200,
          height: 150,
          color: Colors.grey[200],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.green,
              ),
              const SizedBox(height: 8),
              Text(
                isPending ? 'جاري الإرسال...' : 'جاري التحميل...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          width: 200,
          height: 150,
          color: Colors.grey[200],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isFailed ? Icons.error_outline : Icons.broken_image,
                color: isFailed ? Colors.red : Colors.grey,
                size: 40,
              ),
              const SizedBox(height: 8),
              Text(
                isFailed ? 'فشل التحميل' : 'خطأ في الصورة',
                style: TextStyle(
                  color: isFailed ? Colors.red : Colors.grey,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _retryFailedMessage(Message message) async {
    setState(() {
      _failedMessages.remove(message.id);
      _sendingMessages.add(message.id);
    });

    try {
      await ref.read(messageServiceProvider).sendMessage(message, message.id);

      setState(() {
        _pendingMessages.removeWhere((m) => m.id == message.id);
        _sendingMessages.remove(message.id);
      });

      await _savePendingMessages();
      ref.invalidate(messagesProvider(widget.chat.id));

      _showSuccessSnackBar('تم إرسال الرسالة بنجاح');
    } catch (e) {
      print('❌ فشل إعادة الإرسال: $e');
      _markMessageAsFailed(message.id);
      _showErrorSnackBar('فشل إرسال الرسالة');
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

  Future<void> _showEditMessageDialog(Message message) async {
    final TextEditingController editController = TextEditingController(
      text: message.body,
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل الرسالة'),
        content: TextField(
          controller: editController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'اكتب رسالتك الجديدة...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              if (editController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
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
        _showSuccessSnackBar('تم تعديل الرسالة بنجاح');
        ref.invalidate(messagesProvider(widget.chat.id));
      } catch (e) {
        _showErrorSnackBar('فشل تعديل الرسالة');
      }
    }
  }

  Future<void> _showDeleteMessageDialog(Message message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الرسالة'),
        content: const Text('هل أنت متأكد من حذف هذه الرسالة؟'),
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
        _showSuccessSnackBar('تم حذف الرسالة بنجاح');
      } catch (e) {
        _showErrorSnackBar('فشل حذف الرسالة');
      }
    }
  }

  void _showMediaPickerDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'إرسال صورة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: const Icon(Icons.photo_library, color: Colors.green),
                  title: const Text('اختيار من المعرض'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendImage(fromCamera: false);
                  },
                ),
              ),
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: const Icon(Icons.camera_alt, color: Colors.green),
                  title: const Text('التقاط صورة'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendImage(fromCamera: true);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndSendImage({required bool fromCamera}) async {
    final currentUser = ref.read(appUserDataProvider);
    if (currentUser == null || currentUser.phone.isEmpty) return;

    final imageService = ImageUploadService();
    final imageFile = await imageService.pickImage(fromCamera: fromCamera);
    if (imageFile == null) return;

    final tempMessageId = 'temp_img_${DateTime.now().millisecondsSinceEpoch}';

    final pendingMessage = Message(
      id: tempMessageId,
      senderUser: currentUser.phone,
      resevUser: widget.receiverPhone,
      body: 'loading',
      chatId: widget.chat.id,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      isRead: false,
      type: MessageType.image,
      isDeleted: false,
      isSynced: false,
    );

    setState(() {
      _pendingMessages.add(pendingMessage);
      _sendingMessages.add(tempMessageId);
    });
    await _savePendingMessages();
    _scrollToBottom();

    try {
      final imageUrl = await imageService.uploadImage(imageFile);
      if (imageUrl == null) {
        setState(() {
          _pendingMessages.removeWhere((m) => m.id == tempMessageId);
        });
        await _savePendingMessages();
        _markMessageAsFailed(tempMessageId);
        _showErrorSnackBar('فشل رفع الصورة');
        return;
      }

      print('✅ تم رفع الصورة: $imageUrl');

      final updatedMessage = Message(
        id: tempMessageId,
        senderUser: currentUser.phone,
        resevUser: widget.receiverPhone,
        body: imageUrl,
        chatId: widget.chat.id,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        isRead: false,
        type: MessageType.image,
        isDeleted: false,
        isSynced: false,
      );

      setState(() {
        final index = _pendingMessages.indexWhere((m) => m.id == tempMessageId);
        if (index != -1) {
          _pendingMessages[index] = updatedMessage;
        }
      });
      await _savePendingMessages();
      _scrollToBottom();

      if (!isConnected) {
        _showErrorSnackBar('لا توجد اتصال. سيتم إرسال الصورة عند عودة الاتصال');
        return;
      }

      try {
        await ref.read(messageServiceProvider).sendMessage(updatedMessage, tempMessageId);

        print('✅ تم إرسال الصورة إلى Firebase');

        setState(() {
          _pendingMessages.removeWhere((m) => m.id == tempMessageId);
          _sendingMessages.remove(tempMessageId);
        });

        await _savePendingMessages();
        ref.invalidate(messagesProvider(widget.chat.id));
        _scrollToBottom();

      } catch (e) {
        print('❌ فشل إرسال الصورة إلى Firebase: $e');
        _markMessageAsFailed(tempMessageId);
        _showErrorSnackBar('فشل إرسال الصورة');
      }

    } catch (e) {
      print('❌ خطأ في رفع الصورة: $e');
      setState(() {
        _pendingMessages.removeWhere((m) => m.id == tempMessageId);
      });
      await _savePendingMessages();
      _markMessageAsFailed(tempMessageId);
      _showErrorSnackBar('حدث خطأ: $e');
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
              const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'تم حظر هذه المحادثة',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'لن تتمكن من إرسال أو استقبال رسائل',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  ref.read(chatServiceProvider).unblockUser(chatId, myId).catchError((e) {
                    print('❌ خطأ في إلغاء الحظر: $e');
                  });
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
        color: Theme.of(context).colorScheme.surface,
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
              onPressed: _showMediaPickerDialog,
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
                icon: const CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Icon(Icons.send, color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileBottomSheet() {
    final receiverData = ref.read(userDataProvider(widget.receiverPhone));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return receiverData.when(
          data: (receiver) {
            if (receiver == null) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(25),
                    topRight: Radius.circular(25),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('لا توجد بيانات للمستخدم'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إغلاق'),
                    ),
                  ],
                ),
              );
            }

            return Container(
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
                crossAxisAlignment: CrossAxisAlignment.center,
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
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 70,
                      backgroundColor: const Color(0xFF075E54).withOpacity(0.1),
                      backgroundImage: receiver.imageUrl != null && receiver.imageUrl!.isNotEmpty
                          ? CachedNetworkImageProvider(receiver.imageUrl!)
                          : null,
                      child: receiver.imageUrl == null || receiver.imageUrl!.isEmpty
                          ? Text(
                        receiver.displayName.isNotEmpty
                            ? receiver.displayName[0].toUpperCase()
                            : widget.receiverPhone[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF075E54),
                        ),
                      )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    receiver.displayName.isNotEmpty ? receiver.displayName : widget.receiverPhone,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF075E54),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          widget.receiverPhone,
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  if (receiver.email != null && receiver.email!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.email, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            receiver.email!,
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: receiver.isOnline ? Colors.green[50] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: receiver.isOnline ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          receiver.isOnline ? 'متصل الآن' : 'غير متصل',
                          style: TextStyle(
                            fontSize: 14,
                            color: receiver.isOnline ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showComingSoonMessage();
                          },
                          icon: const Icon(Icons.call, size: 20),
                          label: const Text('اتصال صوتي'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showComingSoonMessage();
                          },
                          icon: const Icon(Icons.videocam, size: 20),
                          label: const Text('اتصال فيديو'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF075E54),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showBlockUserDialog();
                      },
                      icon: Icon(
                        _isBlocked ? Icons.check_circle : Icons.block,
                        size: 20,
                      ),
                      label: Text(_isBlocked ? 'إلغاء الحظر' : 'حظر المستخدم'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _isBlocked ? Colors.green : Colors.red,
                        side: BorderSide(
                          color: _isBlocked ? Colors.green : Colors.red,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
          loading: () => Container(
            height: 200,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
              ),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.green),
            ),
          ),
          error: (error, stack) => Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 50, color: Colors.red),
                const SizedBox(height: 10),
                const Text(
                  'حدث خطأ في تحميل البيانات',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إغلاق'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showImagePickerOptions(
      BuildContext context,
      Function setModalState,
      Function(String) onImageUploaded,
      Function onUploadStart,
      Function onUploadEnd,
      ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Material(
              color: Colors.transparent,
              child: ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.green),
                title: const Text('اختيار من المعرض', style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickAndUploadImageForProfile(false, setModalState, onImageUploaded, onUploadStart, onUploadEnd);
                },
              ),
            ),
            const Divider(height: 1),
            Material(
              color: Colors.transparent,
              child: ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.green),
                title: const Text('التقاط صورة', style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickAndUploadImageForProfile(true, setModalState, onImageUploaded, onUploadStart, onUploadEnd);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImageForProfile(
      bool fromCamera,
      Function setModalState,
      Function(String) onImageUploaded,
      Function onUploadStart,
      Function onUploadEnd,
      ) async {
    onUploadStart();

    try {
      final imageService = ImageUploadService();
      final imageFile = await imageService.pickImage(fromCamera: fromCamera);

      if (imageFile != null) {
        final imageUrl = await imageService.uploadImage(imageFile);
        if (imageUrl != null && imageUrl.isNotEmpty) {
          onImageUploaded(imageUrl);
          _showSuccessSnackBar('تم رفع الصورة بنجاح');
        } else {
          _showErrorSnackBar('فشل رفع الصورة، حاول مرة أخرى');
        }
      }
    } catch (e) {
      print('❌ خطأ في رفع الصورة: $e');
      _showErrorSnackBar('حدث خطأ: ${e.toString()}');
    } finally {
      onUploadEnd();
    }
  }
}