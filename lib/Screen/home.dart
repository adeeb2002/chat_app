import 'dart:async';

import 'package:ChatApp/Combonant/CustomSearchBar.dart';
import 'package:ChatApp/Provider/chatProvider.dart';
import 'package:ChatApp/Provider/userProvide.dart';
import 'package:ChatApp/Screen/addChatScreen.dart';
import 'package:ChatApp/Screen/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/chat.dart';
import '../model/user.dart';
import 'chatScreen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  bool isConnected = false;
  final searchController = TextEditingController();
  StreamSubscription? connectionSubscription;

  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // ✅ الطريقة الصحيحة لاستدعاء الدوال المستقلة
    _checkUserLoggedIn();

    // 2️⃣ الاستماع للتغييرات في حقل البحث وتحديث الواجهة فوراً
    searchController.addListener(() {
      setState(() {
        _searchQuery = searchController.text.trim().toLowerCase();
      });
    });

    // مراقبة الاتصال بشكل حي
    connectionSubscription = InternetConnection().onStatusChange.listen((
      status,
    ) {
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
  }

  @override
  void dispose() {
    connectionSubscription?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _checkUserLoggedIn() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('userEmail');
      final userId = prefs.getString('userId');
      final userName = prefs.getString('userName'); // يفضل حفظ الاسم أيضاً

      if (userEmail != null && userId != null && mounted) {
        // ✅ لا تنتظر getUser hierarchies من السيرفر هنا
        // قم بتعبئة البيانات الأساسية فوراً من الذاكرة المحلية
        final localUser = AppUser(
          id: userId,
          email: userEmail,
          displayName: userName ?? userEmail.split('@')[0],
          isOnline: false, // افتراضياً أوفلاين
        );

        ref.read(appUserDataProvider.notifier).state = localUser;
        ref.read(appUserEmailProvider.notifier).state = userEmail;

        // تحديث الحالة في السيرفر يتم "في الخلفية" ولا يعطل الدخول
        if (isConnected) {
          ref.read(authServiceProvider).updateUserStatus(userId, true);
        }

        print('✅ تم الدخول السريع (وضع الأوفلاين)');
      } else {
        _navigateToLogin();
      }
    } catch (e) {
      print('❌ خطأ: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToLogin() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
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
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      return 'أمس';
    } else if (date.year == now.year && date.month == now.month) {
      return DateFormat('d MMM').format(date);
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('تسجيل خروج'),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    try {
      final currentUser = ref.read(appUserDataProvider);
      final authService = ref.read(authServiceProvider);

      if (currentUser?.id != null) {
        await authService.updateUserStatus(currentUser!.id!, false);
      }

      await authService.logout();

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      ref.read(appUserDataProvider.notifier).state = null;
      ref.read(appUserEmailProvider.notifier).state = null;

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      print('❌ خطأ في تسجيل الخروج: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في تسجيل الخروج: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final currentUser = ref.watch(appUserDataProvider);
    final currentUserEmail = ref.watch(appUserEmailProvider);

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.green),
              SizedBox(height: 16),
              Text('جاري التحميل...'),
            ],
          ),
        ),
      );
    }

    if (currentUser == null || currentUserEmail == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToLogin();
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final chatsAsync = ref.watch(chatsProvider(currentUserEmail));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.chat, color: Colors.white),
            const SizedBox(width: 8),
            const Text(
              'المحادثات',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 10), // مسافة صغيرة تفصل العنوان عن الحالة
            Text(
              isConnected ? 'متصل' : 'في انتظار الشبكة...',
              style: TextStyle(
                fontSize: 11,
                color: isConnected ? Colors.greenAccent : Colors.orangeAccent,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            color: Colors.white,
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              } else if (value == 'profile') {
                _showProfileDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, size: 20, color: Colors.black),
                    SizedBox(width: 12),
                    Text('الملف الشخصي'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text(
                      'تسجيل الخروج',
                      style: TextStyle(color: Colors.red),
                    ), // تعديل لون النص ليناسب اللوجو الأحمر
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        // الـ Stack هنا فقط للتحكم في شريط الإشعارات العلوي الطائر
        children: [
          // المحتوى الأساسي مرتب عمودياً بشكل سليم
          Column(
            children: [
              // 1️⃣ حقل البحث مع هوامش مناسبة
              Padding(
                padding: const EdgeInsets.only(
                  top: 12,
                  left: 12,
                  right: 12,
                  bottom: 8,
                ),
                child: CustomSearchBar(
                  controller: searchController,
                  onClear: () {
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.trim().toLowerCase();
                    });
                  },
                ),
              ),

              // 2️⃣ قائمة المحادثات مرنة تأخذ باقي مساحة الشاشة عمودياً
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(chatsProvider(currentUserEmail));
                  },
                  child: chatsAsync.when(
                    data: (chats) {
                      if (chats.isEmpty) return _buildEmptyState(currentUser);

                      // 3️⃣ تصفية القائمة برمجياً بناءً على نص البحث
                      final filteredChats = chats.where((chat) {
                        final otherEmail = chat.getOtherParticipant(
                          currentUserEmail,
                        );

                        // جلب بيانات المستخدم الآخر من الـ Provider (الاسم المقترن به)
                        final otherUser = ref
                            .read(userDataProvider(otherEmail))
                            .value;
                        final otherName =
                            otherUser?.displayName?.toLowerCase() ??
                            otherEmail.split('@')[0].toLowerCase();

                        // التحقق مما إذا كان الاسم أو الإيميل يحتوي على نص البحث
                        return otherName.contains(_searchQuery) ||
                            otherEmail.toLowerCase().contains(_searchQuery);
                      }).toList();

                      // إذا كانت نتائج البحث فارغة نوضح ذلك للمستخدم
                      if (filteredChats.isEmpty && _searchQuery.isNotEmpty) {
                        return const Center(
                          child: Text(
                            'لا توجد نتائج مطابقة لبحثك',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        );
                      }

                      // عرض القائمة المصفاة فقط
                      return ListView.builder(
                        itemCount: filteredChats.length,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemBuilder: (context, index) {
                          final chat = filteredChats[index];
                          final otherEmail = chat.getOtherParticipant(
                            currentUserEmail,
                          );
                          return _buildChatItem(
                            chat,
                            otherEmail,
                            currentUserEmail,
                          );
                        },
                      );
                    },
                    loading: () => isConnected
                        ? const Center(child: CircularProgressIndicator())
                        : const Center(
                            child: Text(
                              "لا يوجد اتصال، جاري محاولة جلب البيانات محلياً...",
                            ),
                          ),
                    error: (error, stackTrace) =>
                        _buildErrorState(error.toString()),
                  ),
                ),
              ),
            ],
          ),

          // 3️⃣ شريط نحيف يعلو كل شيء ويختفي عند توفر الإنترنت دون حجز مساحة من الـ Column
          if (!isConnected)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.redAccent.withOpacity(
                  0.9,
                ), // تم تغيير اللون للأحمر الهادئ ليعطي انطباع التحذير
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: const Text(
                  'أنت تعمل حالياً في وضع الأوفلاين (يتم العرض من الكاش)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddChatScreen()),
          );
        },
        backgroundColor: const Color(0xFF075E54),
        child: const Icon(Icons.chat, color: Colors.white),
      ),
    );
  }

  // ✅ استخدام Consumer بدلاً من FutureBuilder
  Widget _buildChatItem(Chat chat, String otherEmail, String currentUserEmail) {
    final userAsync = ref.watch(userDataProvider(otherEmail));

    return userAsync.when(
      data: (user) {
        final name = user?.displayName ?? otherEmail.split('@')[0];
        final imageUrl = user?.imageUrl;
        return _buildChatTile(
          chat: chat,
          name: name,
          otherEmail: otherEmail,
          imageUrl: imageUrl,
          currentUserEmail: currentUserEmail,
        );
      },
      loading: () => _buildLoadingChatTile(),
      error: (error, _) => _buildErrorChatTile(error.toString()),
    );
  }

  Widget _buildChatTile({
    required Chat chat,
    required String name,
    required String otherEmail,
    required String? imageUrl,
    required String currentUserEmail,
  }) {
    // 1️⃣ جلب عدد الرسائل غير المقروءة من الـ chat model
    // تأكد من مطابقة اسم المتغير لديك، سأفترض اسمه unreadCount أو نقوم بمثال افتراضي
    final int unreadCount = chat.unreadCount ?? 0;
    final bool hasUnread = unreadCount > 0;

    return Dismissible(
      key: Key(chat.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 30),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('حذف المحادثة'),
            content: Text('هل أنت متأكد من حذف المحادثة مع $name؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('حذف'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        try {
          final chatService = ref.read(chatServiceProvider);
          final currentUser = ref.read(appUserDataProvider);
          final currentUserId = currentUser?.id ?? currentUserEmail;

          await chatService.deleteChatForUser(chat.id, currentUserId);

          if (mounted) {
            ref.invalidate(chatsProvider(currentUserEmail));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم حذف المحادثة')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('خطأ في الحذف: $e')),
            );
            ref.invalidate(chatsProvider(currentUserEmail));
          }
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(15),
          ),
          child: ListTile(
            leading: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.green[50],
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? ClipOval(
                child: Image.network(
                  imageUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Text(
                    name[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              )
                  : Text(
                name[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              chat.isBlocked ?? false
                  ? 'هذه المحادثة محظورة'
                  : chat.lastMessage.isNotEmpty
                  ? chat.lastMessage
                  : 'ابدأ المحادثة',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // جعل لون آخر رسالة أغمق قليلاً إذا كانت غير مقروءة
              style: TextStyle(
                color: hasUnread ? Colors.black87 : Colors.grey[600],
                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            // 2️⃣ التعديل الجوهري هنا: ترتيب الوقت والعداد عمودياً
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // الوقت في الأعلى
                Text(
                  _formatTime(chat.lastMessageTime),
                  style: TextStyle(
                    fontSize: 11,
                    color: hasUnread ? const Color(0xFF075E54) : Colors.grey,
                    fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 5), // مسافة بسيطة بين الوقت والعداد

                // العداد الدائري يظهر فقط إذا كان هناك رسائل غير مقروءة
                if (hasUnread)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF075E54), // اللون الأخضر الخاص بالواتساب
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      '$unreadCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
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
                  builder: (context) => ChatScreen(
                    chat: chat,
                    receiverEmail: otherEmail,
                    receiverName: name,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingChatTile() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(15),
        ),
        child: const ListTile(
          leading: CircleAvatar(
            radius: 28,
            backgroundColor: Colors.grey,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: Text('جاري التحميل...'),
          subtitle: Text('...'),
        ),
      ),
    );
  }

  Widget _buildErrorChatTile(String error) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(15),
        ),
        child: const ListTile(
          leading: CircleAvatar(
            radius: 28,
            backgroundColor: Colors.red,
            child: Icon(Icons.error, color: Colors.white),
          ),
          title: Text('خطأ في التحميل'),
          subtitle: Text('يرجى المحاولة مرة أخرى'),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppUser currentUser) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green[50],
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 60,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'مرحباً ${currentUser.displayName}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF075E54),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'لا توجد محادثات بعد',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'ابدأ محادثة جديدة الآن',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddChatScreen()),
            ),
            icon: const Icon(Icons.add),
            label: const Text('محادثة جديدة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF075E54),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
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
          const Text(
            'حدث خطأ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              final currentUserEmail = ref.read(appUserEmailProvider);
              if (currentUserEmail != null) {
                ref.invalidate(chatsProvider(currentUserEmail));
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('البحث عن محادثة'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'أدخل اسم المستخدم أو البريد الإلكتروني',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            // TODO: تنفيذ البحث
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  void _showProfileDialog() {
    final currentUser = ref.read(appUserDataProvider);
    if (currentUser == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الملف الشخصي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.green[100],
              child: Text(
                currentUser.displayName[0].toUpperCase(),
                style: const TextStyle(fontSize: 40, color: Colors.green),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              currentUser.displayName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(currentUser.email, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: currentUser.isOnline ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  currentUser.isOnline ? 'متصل الآن' : 'غير متصل',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}
