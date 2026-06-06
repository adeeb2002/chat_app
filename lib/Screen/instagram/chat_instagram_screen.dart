import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../Provider/instagram/instagram_provider.dart';
import '../../model/instagram/message_models.dart';

class ChatInstagramScreen extends StatefulWidget {
  final InboxThread thread;
  final User? user;

  ChatInstagramScreen({required this.thread, this.user});

  @override
  _ChatInstagramScreenState createState() => _ChatInstagramScreenState();
}

class _ChatInstagramScreenState extends State<ChatInstagramScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final provider = context.read<InstagramProvider>();
    final messages = await provider.loadMessages(widget.thread.threadId);

    if (mounted) {
      setState(() {
        _messages = messages.reversed.toList();
        _isLoading = false;
      });

      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSending) return;

    final text = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _isSending = true;
    });

    final provider = context.read<InstagramProvider>();
    final success = await provider.sendMessage(widget.thread.threadId, text);

    setState(() {
      _isSending = false;
    });

    if (success) {
      await _loadMessages();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل إرسال الرسالة'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatMessageTime(int timestamp) {
    final date = DateTime.fromMicrosecondsSinceEpoch(timestamp);
    return DateFormat('HH:mm').format(date);
  }

  bool _isSameDay(int timestamp1, int timestamp2) {
    final date1 = DateTime.fromMicrosecondsSinceEpoch(timestamp1);
    final date2 = DateTime.fromMicrosecondsSinceEpoch(timestamp2);
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InstagramProvider>();
    final currentUserId = provider.apiService.userId;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF833AB4), Color(0xFFFD1D1D)],
            ),
          ),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              backgroundImage: widget.user?.profilePicUrl != null
                  ? CachedNetworkImageProvider(widget.user!.profilePicUrl!)
                  : null,
              child: widget.user?.profilePicUrl == null
                  ? Icon(Icons.person, size: 20, color: Color(0xFFE1306C))
                  : null,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.user?.username ?? widget.thread.threadTitle,
                          style: TextStyle(fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.user?.isVerified == true)
                        Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.verified, size: 14),
                        ),
                    ],
                  ),
                  if (widget.user?.fullName != null)
                    Text(
                      widget.user!.fullName,
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.videocam),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('قريباً: مكالمة فيديو')),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('قريباً: معلومات المحادثة')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE1306C),
              ),
            )
                : _messages.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'لا توجد رسائل',
                    style:
                    TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'ابدأ المحادثة بإرسال رسالة',
                    style:
                    TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            )
                : ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMe = message.userId == currentUserId;
                final showDate = index == 0 ||
                    !_isSameDay(
                      _messages[index - 1].timestamp,
                      message.timestamp,
                    );

                return Column(
                  children: [
                    if (showDate)
                      _buildDateDivider(message.timestamp),
                    _buildMessageBubble(message, isMe),
                  ],
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildDateDivider(int timestamp) {
    final date = DateTime.fromMicrosecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    String dateText;

    if (_isSameDay(date.millisecondsSinceEpoch * 1000,
        now.millisecondsSinceEpoch * 1000)) {
      dateText = 'اليوم';
    } else if (_isSameDay(
        date.millisecondsSinceEpoch * 1000,
        now.subtract(Duration(days: 1)).millisecondsSinceEpoch * 1000)) {
      dateText = 'أمس';
    } else {
      dateText = DateFormat('dd MMMM yyyy').format(date);
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider()),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                dateText,
                style: TextStyle(color: Colors.grey[700], fontSize: 12),
              ),
            ),
          ),
          Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 4,
          bottom: 4,
          left: isMe ? 60 : 0,
          right: isMe ? 0 : 60,
        ),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isMe
              ? LinearGradient(
            colors: [Color(0xFF833AB4), Color(0xFFE1306C)],
          )
              : null,
          color: isMe ? null : Colors.grey[200],
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: isMe ? Radius.circular(4) : Radius.circular(20),
            bottomLeft: isMe ? Radius.circular(20) : Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.getDisplayText(),
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            SizedBox(height: 4),
            Text(
              _formatMessageTime(message.timestamp),
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.grey,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.camera_alt, color: Color(0xFFE1306C)),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('قريباً: إرسال صورة')),
                );
              },
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'رسالة...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            SizedBox(width: 8),
            _isSending
                ? Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFE1306C),
                ),
              ),
            )
                : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF833AB4), Color(0xFFE1306C)],
                ),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.send, color: Colors.white),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}