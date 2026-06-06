import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../Provider/instagram/instagram_provider.dart';
import '../../model/instagram/message_models.dart';
import 'chat_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 10),
            Text('تسجيل الخروج'),
          ],
        ),
        content: Text('هل تريد تسجيل الخروج من حسابك؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              await context.read<InstagramProvider>().logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => LoginScreen()),
                    (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('تسجيل الخروج'),
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
      return '${difference.inDays} يوم';
    } else {
      return DateFormat('dd/MM').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'الرسائل',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF833AB4), Color(0xFFFD1D1D)],
            ),
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.edit_square),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('قريباً: رسالة جديدة')),
              );
            },
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Consumer<InstagramProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingThreads && provider.threads.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFE1306C)),
                  SizedBox(height: 16),
                  Text('جاري تحميل المحادثات...'),
                ],
              ),
            );
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 60, color: Colors.red),
                    SizedBox(height: 16),
                    Text(
                      provider.errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red, fontSize: 16),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _refreshThreads,
                      icon: Icon(Icons.refresh),
                      label: Text('إعادة المحاولة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFE1306C),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (provider.threads.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'لا توجد محادثات',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'ابدأ محادثة جديدة',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshThreads,
            color: Color(0xFFE1306C),
            child: ListView.separated(
              itemCount: provider.threads.length,
              separatorBuilder: (context, index) =>
                  Divider(height: 1, indent: 80),
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

  Widget _buildDrawer() {
    return Drawer(
      child: Consumer<InstagramProvider>(
        builder: (context, provider, _) {
          final user = provider.currentUser;

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF833AB4), Color(0xFFFD1D1D)],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white,
                        backgroundImage: user?.profilePicUrl != null
                            ? CachedNetworkImageProvider(user!.profilePicUrl!)
                            : null,
                        child: user?.profilePicUrl == null
                            ? Icon(Icons.person,
                            size: 40, color: Color(0xFFE1306C))
                            : null,
                      ),
                      SizedBox(height: 15),
                      Text(
                        user?.username ?? 'مستخدم',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        user?.fullName ?? '',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ListTile(
                      leading: Icon(Icons.chat, color: Color(0xFFE1306C)),
                      title: Text('الرسائل'),
                      trailing: Container(
                        padding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Color(0xFFE1306C),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${provider.threads.length}',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                      },
                    ),
                    Divider(),
                    ListTile(
                      leading: Icon(Icons.refresh, color: Colors.blue),
                      title: Text('تحديث المحادثات'),
                      onTap: () {
                        Navigator.pop(context);
                        _refreshThreads();
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.info_outline, color: Colors.orange),
                      title: Text('حول التطبيق'),
                      onTap: () {
                        Navigator.pop(context);
                        showAboutDialog(
                          context: context,
                          applicationName: 'Instagram Messages',
                          applicationVersion: '1.0.0',
                          applicationIcon: Icon(Icons.chat_bubble,
                              size: 50, color: Color(0xFFE1306C)),
                          children: [
                            Text('تطبيق لعرض رسائل Instagram'),
                            SizedBox(height: 10),
                            Text('للأغراض التعليمية فقط',
                                style: TextStyle(color: Colors.red)),
                          ],
                        );
                      },
                    ),
                    Divider(),
                    ListTile(
                      leading: Icon(Icons.logout, color: Colors.red),
                      title: Text('تسجيل الخروج',
                          style: TextStyle(color: Colors.red)),
                      onTap: () {
                        Navigator.pop(context);
                        _showLogoutDialog();
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'نسخة 1.0.0',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildThreadItem(InboxThread thread, User? user) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Color(0xFFE1306C).withOpacity(0.2),
            child: user?.profilePicUrl != null
                ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: user!.profilePicUrl!,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    CircularProgressIndicator(strokeWidth: 2),
                errorWidget: (context, url, error) => Icon(Icons.person,
                    color: Color(0xFFE1306C), size: 30),
              ),
            )
                : Icon(Icons.person, color: Color(0xFFE1306C), size: 30),
          ),
          if (thread.hasUnread)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 14,
                height: 14,
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
                fontWeight:
                thread.hasUnread ? FontWeight.bold : FontWeight.w600,
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (user?.isVerified == true)
            Icon(Icons.verified, size: 16, color: Colors.blue),
        ],
      ),
      subtitle: Padding(
        padding: EdgeInsets.only(top: 4),
        child: Text(
          thread.lastMessage?.getDisplayText() ?? 'رسالة',
          style: TextStyle(
            color: thread.hasUnread ? Colors.black87 : Colors.grey[600],
            fontWeight:
            thread.hasUnread ? FontWeight.w500 : FontWeight.normal,
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
              fontWeight:
              thread.hasUnread ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(thread: thread, user: user),
          ),
        );
      },
    );
  }
}