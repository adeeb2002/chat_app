import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../Provider/instagram/instagram_provider.dart';
import '../loginScreen.dart';


class MessagesScreen extends StatefulWidget {
  @override
  _MessagesScreenState createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InstagramProvider>().loadThreads();
    });
  }

  Future<void> _refreshThreads() async {
    await context.read<InstagramProvider>().loadThreads(refresh: true);
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تسجيل الخروج'),
        content: Text('هل تريد تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              await context.read<InstagramProvider>().logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => LoginScreen()),
                    (route) => false,
              );
            },
            child: Text('تسجيل الخروج', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMicrosecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(date);
    } else if (difference.inDays == 1) {
      return 'أمس';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} أيام';
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'الرسائل',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF833AB4), Color(0xFFFD1D1D)],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              // TODO: إضافة شاشة البحث
            },
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _showLogoutDialog,
          ),
        ],
      ),
      body: Consumer<InstagramProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingThreads && provider.threads.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFFE1306C),
                  ),
                  SizedBox(height: 16),
                  Text('جاري تحميل المحادثات...'),
                ],
              ),
            );
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 60, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    provider.errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshThreads,
                    child: Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }

          if (provider.threads.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 80,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'لا توجد محادثات',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshThreads,
            color: Color(0xFFE1306C),
            child: ListView.builder(
              itemCount: provider.threads.length,
              itemBuilder: (context, index) {
                final thread = provider.threads[index];
                final user = thread.users.isNotEmpty ? thread.users[0] : null;

                return _buildThreadItem(thread, user);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildThreadItem(InboxThread thread, User? user) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: thread.hasUnread ? Color(0xFFFFF5F8) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Color(0xFFE1306C),
              child: user?.profilePicUrl != null
                  ? ClipOval(
                child: CachedNetworkImage(
                  imageUrl: user!.profilePicUrl!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                  errorWidget: (context, url, error) => Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              )
                  : Icon(Icons.person, color: Colors.white, size: 30),
            ),
            if (thread.hasUnread)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Color(0xFFE1306C),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user?.username ?? thread.threadTitle,
                style: TextStyle(
                  fontWeight: thread.hasUnread ? FontWeight.bold : FontWeight.w500,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (user?.isVerified == true)
              Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.verified,
                  size: 16,
                  color: Colors.blue,
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            thread.lastMessage?.text ??
                _getMessageTypeText(thread.lastMessage?.itemType),
            style: TextStyle(
              color: thread.hasUnread ? Colors.black87 : Colors.grey,
              fontWeight: thread.hasUnread ? FontWeight.w500 : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatTimestamp(thread.lastActivityAt),
              style: TextStyle(
                color: thread.hasUnread ? Color(0xFFE1306C) : Colors.grey,
                fontSize: 12,
                fontWeight: thread.hasUnread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (thread.hasUnread)
              Container(
                margin: EdgeInsets.only(top: 4),
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Color(0xFFE1306C),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'جديد',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                thread: thread,
                user: user,
              ),
            ),
          );
        },
      ),
    );
  }

  String _getMessageTypeText(String? type) {
    switch (type) {
      case 'text':
        return '';
      case 'media':
        return '📷 صورة';
      case 'reel_share':
        return '🎬 ريل';
      case 'voice_media':
        return '🎤 رسالة صوتية';
      case 'animated_media':
        return '😄 GIF';
      case 'link':
        return '🔗 رابط';
      default:
        return 'رسالة';
    }
  }
}