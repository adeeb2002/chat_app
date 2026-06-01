import 'dart:async';
import 'package:ChatApp/Animation/RouteAnimation.dart';
import 'package:ChatApp/Combonant/CustomSearchBar.dart';
import 'package:ChatApp/Provider/chatProvider.dart';
import 'package:ChatApp/Provider/userProvide.dart';
import 'package:ChatApp/Screen/addChatScreen.dart';
import 'package:ChatApp/Screen/login.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:intl/intl.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../Notifications/CacheService.dart';
import '../model/chat.dart';
import '../model/user.dart';
import '../service/ImageUploadService.dart';
import '../theme/app_theme.dart';
import 'chatScreen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  bool _isLoading = true;
  bool isConnected = false;
  final searchController = TextEditingController();
  StreamSubscription? connectionSubscription;
  String _searchQuery = '';
  late final AdvancedCacheService _cacheService;

  bool _isOfflineMode = false;
  bool _isFirstLoad = true;
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    // ✅ إضافة مراقب لدورة حياة التطبيق
    WidgetsBinding.instance.addObserver(this);

    _cacheService = AdvancedCacheService();
    _checkUserLoggedIn();

    searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = searchController.text.trim().toLowerCase();
        });
      }
    });

    connectionSubscription = InternetConnection().onStatusChange.listen((
      status,
    ) async {
      final hasConnection = status == InternetStatus.connected;

      if (isConnected != hasConnection) {
        if (mounted) {
          setState(() {
            isConnected = hasConnection;
          });
        }

        if (isConnected) {
          print('🌐 عودة الاتصال بالإنترنت');
          if (mounted) {
            await _retryLoadingAfterConnection();
          }
        } else {
          print('⚠️ انقطاع الاتصال بالإنترنت');
          _checkOfflineMode();
        }
      }
    });

    // _cacheService = AdvancedCacheService();

    // ✅ تأخير التحقق من تسجيل الدخول قليلاً
    Future.delayed(Duration.zero, () {
      _checkUserLoggedIn();
    });
  }

  Future<void> _checkUserLoggedIn() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('phone');
      final userEmail = prefs.getString('userEmail');
      final userId = prefs.getString('userId');
      final userName = prefs.getString('userName');

      if (phone != null && userId != null && mounted) {
        // ✅ تصحيح: المستخدم غير متصل حتى يثبت الاتصال
        final localUser = AppUser(
          id: userId,
          phone: phone,
          email: userEmail,
          displayName: userName ?? phone,
          isOnline: false, // ✅ غير متصل في البداية
        );

        ref.read(appUserDataProvider.notifier).state = localUser;
        ref.read(appUserPhoneProvider.notifier).state = phone;

        // ✅ إذا كان هناك اتصال، قم بتحديث الحالة
        if (isConnected) {
          await ref.read(authServiceProvider).updateUserStatus(userId, true);
        }

        print('✅ تم الدخول السريع بنجاح');
      } else {
        _navigateToLogin();
      }
    } catch (e) {
      print('❌ خطأ في فحص حالة الدخول: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    // ✅ إزالة المراقب
    WidgetsBinding.instance.removeObserver(this);
    connectionSubscription?.cancel();
    searchController.dispose();
    _cacheService.dispose();
    super.dispose();
  }

  // ✅ مراقبة عودة التطبيق إلى الواجهة الأمامية
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted && isConnected) {
      // ✅ عند العودة إلى التطبيق، تحديث البيانات
      final currentUserPhone = ref.read(appUserPhoneProvider);
      if (currentUserPhone != null) {
        ref.invalidate(chatsProvider(currentUserPhone));
      }
    }
  }

  void _checkOfflineMode() {
    if (!isConnected && _cacheService.hasCachedData()) {
      if (mounted) {
        setState(() {
          _isOfflineMode = true;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isOfflineMode = false;
        });
      }
    }
  }

  // ✅ في _retryLoadingAfterConnection
  Future<void> _retryLoadingAfterConnection() async {
    if (!isConnected) return;

    print('🔄 إعادة تحميل البيانات بعد عودة الاتصال...');

    if (!mounted) return;

    final currentUserPhone = ref.read(appUserPhoneProvider);
    final currentIdUser = await ref
        .read(authServiceProvider)
        .getUserByPhoneLocal();

    if (currentUserPhone != null) {
      if (currentIdUser?.id != null) {
        await ref
            .read(authServiceProvider)
            .updateUserStatus(currentIdUser!.id!, true);
      }

      // ✅ تحديث Providers
      ref.invalidate(chatsProvider(currentUserPhone));
      ref.invalidate(userDataProvider);

      final freshUser = await ref
          .read(authServiceProvider)
          .getUserByPhone(currentUserPhone);
      if (freshUser != null && mounted) {
        ref.read(appUserDataProvider.notifier).state = freshUser;
      }
    }

    _checkOfflineMode();
  }

  void _navigateToLogin() {
    if (mounted) {
      Navigator.pushReplacement(context, RouteAnimation.fade(LoginScreen()));
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
            child: const Text(
              'تسجيل خروج',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    try {
      final currentUser = ref.read(appUserDataProvider);
      final authService = ref.read(authServiceProvider);

      if (currentUser?.id != null && isConnected) {
        await authService.updateUserStatus(currentUser!.id!, false);
      }

      await authService.logout();

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      await _cacheService.clearAllCache();

      // ✅ إعادة تعيين المتغيرات
      _isFirstLoad = true;

      ref.read(appUserDataProvider.notifier).state = null;
      ref.read(appUserPhoneProvider.notifier).state = null;

      _navigateToLogin();
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
    final currentUserPhone = ref.watch(appUserPhoneProvider);

    // ✅ تحسين حالة التحميل
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

    if (currentUser == null || currentUserPhone == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _navigateToLogin();
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final chatsAsync = ref.watch(chatsProvider(currentUserPhone));

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
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isConnected
                    ? Colors.green.withOpacity(0.2)
                    : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isConnected ? Icons.wifi : Icons.wifi_off,
                    size: 14,
                    color: isConnected
                        ? Colors.greenAccent
                        : Colors.orangeAccent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isConnected ? 'متصل' : 'غير متصل',
                    style: TextStyle(
                      fontSize: 11,
                      color: isConnected
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Column(
            children: [
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

              if (!isConnected)
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.wifi_off, size: 18, color: AppTheme.warningColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'لا يوجد اتصال بالإنترنت، يتم عرض الرسائل المحفوظة فقط',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.warningColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    if (isConnected) {
                      ref.invalidate(chatsProvider(currentUserPhone));
                      ref.invalidate(userDataProvider);
                      await _retryLoadingAfterConnection();
                    } else {
                      Fluttertoast.showToast(
                        msg: 'لا يوجد اتصال بالإنترنت لتحديث البيانات',
                      );
                    }
                  },
                  child: chatsAsync.when(
                    data: (chats) {
                      // ✅ معالجة الحالة عندما تكون chats فارغة ولكن يوجد كاش
                      if (chats.isEmpty &&
                          !isConnected &&
                          _cacheService.hasCachedData()) {
                        final cachedChats = _cacheService.getCachedChats();
                        if (cachedChats.isNotEmpty) {
                          return _buildChatList(cachedChats, currentUserPhone);
                        }
                      }

                      if (chats.isEmpty) return _buildEmptyState(currentUser);

                      return _buildChatList(chats, currentUserPhone);
                    },
                    loading: () {
                      // ✅ تحسين حالة التحميل
                      if (_cacheService.hasCachedData()) {
                        final cachedChats = _cacheService.getCachedChats();
                        if (cachedChats.isNotEmpty) {
                          return _buildChatList(cachedChats, currentUserPhone);
                        }
                      }
                      return isConnected
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF075E54),
                              ),
                            )
                          : const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.wifi_off,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text("لا يوجد اتصال بالإنترنت"),
                                  SizedBox(height: 8),
                                  Text(
                                    "جاري عرض البيانات المخزنة...",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            );
                    },
                    error: (error, stackTrace) {
                      print('❌ خطأ في تحميل المحادثات: $error');
                      // ✅ عرض البيانات من الكاش في حالة الخطأ
                      if (_cacheService.hasCachedData()) {
                        final cachedChats = _cacheService.getCachedChats();
                        if (cachedChats.isNotEmpty) {
                          return _buildChatList(cachedChats, currentUserPhone);
                        }
                      }
                      return _buildErrorState(error.toString());
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            RouteAnimation.rotateAndFade(AddChatScreen()),
          );
        },
        backgroundColor: const Color(0xFF075E54),
        child: const Icon(Icons.chat, color: Colors.white),
      ),
    );
  }

  Widget _buildChatList(List<Chat> chats, String currentUserPhone) {
    final filteredChats = chats.where((chat) {
      final otherPhone = chat.getOtherParticipant(currentUserPhone);
      final otherUserAsync = ref.read(userDataProvider(otherPhone));
      final otherUser = otherUserAsync.value;
      final otherName =
          otherUser?.displayName.toLowerCase() ?? otherPhone.toLowerCase();
      return otherName.contains(_searchQuery) ||
          otherPhone.contains(_searchQuery);
    }).toList();

    if (filteredChats.isEmpty && _searchQuery.isNotEmpty) {
      return const Center(
        child: Text(
          'لا توجد نتائج مطابقة لبحثك',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredChats.length,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemBuilder: (context, index) {
        final chat = filteredChats[index];
        final otherPhone = chat.getOtherParticipant(currentUserPhone);
        return _buildChatItem(chat, otherPhone, currentUserPhone);
      },
    );
  }

  Widget _buildChatItem(Chat chat, String otherPhone, String currentUserPhone) {
    final userAsync = ref.watch(userDataProvider(otherPhone));

    return userAsync.when(
      data: (user) {
        final name = user?.displayName ?? otherPhone;
        final imageUrl = user?.imageUrl;
        return _buildChatTile(
          chat: chat,
          name: name,
          otherPhone: otherPhone,
          imageUrl: imageUrl,
          currentUserPhone: currentUserPhone,
        );
      },
      loading: () => _buildLoadingChatTile(chat, otherPhone),
      error: (error, _) {
        print('❌ خطأ في تحميل بيانات المستخدم $otherPhone: $error');
        return _buildChatTile(
          chat: chat,
          name: otherPhone,
          otherPhone: otherPhone,
          imageUrl: null,
          currentUserPhone: currentUserPhone,
        );
      },
    );
  }

  // ✅ دالة محسنة لعرض عنصر تحميل مع بيانات مؤقتة
  Widget _buildLoadingChatTile(Chat chat, String otherPhone) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          RouteAnimation.slideFromRight(
            ChatScreen(chat: chat, receiverPhone: otherPhone),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainer(context),
            borderRadius: BorderRadius.circular(15),
          ),
          child: ListTile(
            leading: CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              child: Text(
                otherPhone.isNotEmpty ? otherPhone[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            title: Text(
              otherPhone,
              style: theme.textTheme.titleMedium,
            ),
            subtitle: Text(
              chat.lastMessage.isNotEmpty
                  ? chat.lastMessage
                  : 'جاري التحميل...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            trailing: Text(
              _formatTime(chat.lastMessageTime),
              style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatTile({
    required Chat chat,
    required String name,
    required String otherPhone,
    required String? imageUrl,
    required String currentUserPhone,
  }) {
    final String cleanPhoneKey = currentUserPhone.replaceAll('+', 'p');
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    int unreadCount = 0;
    if (chat.unreadCount is int) {
      unreadCount = chat.unreadCount as int;
    } else if (chat.unreadCount is Map) {
      final map = chat.unreadCount as Map;
      unreadCount = map[cleanPhoneKey] ?? 0;
    } else {
      unreadCount = chat.unreadCount ?? 0;
    }

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
          await chatService.deleteChatForUser(chat.id, currentUserPhone);
          await _cacheService.deleteCachedChat(chat.id);

          if (mounted) {
            ref.invalidate(chatsProvider(currentUserPhone));
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('تم حذف المحادثة')));
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('خطأ في الحذف: $e')));
            ref.invalidate(chatsProvider(currentUserPhone));
          }
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainer(context),
            borderRadius: BorderRadius.circular(15),
          ),
          child: ListTile(
            leading: CircleAvatar(
              radius: 28,
              //backgroundColor: primaryColor,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        imageUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Text(
                          name[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    )
                  : Text(
                      name[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
            ),
            title: Text(
              name,
              style: theme.textTheme.titleMedium,
            ),
            subtitle: Text(
              chat.isBlocked ?? false
                  ? '🔒 هذه المحادثة محظورة'
                  : chat.lastMessage.isNotEmpty
                  ? chat.lastMessage
                  : '✨ ابدأ المحادثة',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: hasUnread ? AppTheme.textPrimary(context) : AppTheme.textSecondary(context),
                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            trailing: SizedBox(
              width: 60,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(chat.lastMessageTime),
                    style: TextStyle(
                      fontSize: 8,
                      color: hasUnread ? AppTheme.primaryLight : AppTheme.textSecondary(context),
                      fontWeight: hasUnread
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (hasUnread)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Center(
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 20, height: 20),
                ],
              ),
            ),
            onTap: () async {
              if (isConnected) {
                try {
                  final chatService = ref.read(chatServiceProvider);
                  await chatService.db
                      .ref('chats')
                      .child(chat.id)
                      .child('unreadCount')
                      .update({cleanPhoneKey: 0});
                } catch (e) {
                  print('❌ فشل تصفير العداد: $e');
                }
              }

              if (context.mounted) {
                Navigator.push(
                  context,
                  RouteAnimation.slideFromRight(
                    ChatScreen(
                      chat: chat,
                      receiverPhone: otherPhone,
                      receiverName: name,
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }



  Widget _buildEmptyState(AppUser currentUser) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.1),
                    AppTheme.primaryLight.withValues(alpha: 0.1),
                  ],
                ),
              ),
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                ),
                child: Icon(
                  Icons.chat_rounded,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 32),

            Text(
              'مرحباً ${currentUser.displayName}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainer(context),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildFeatureRow(
                    icon: Icons.chat_bubble_outline,
                    text: 'ابدأ محادثة مع أي شخص',
                  ),
                  const SizedBox(height: 8),
                  _buildFeatureRow(
                    icon: Icons.photo_outlined,
                    text: 'شارك الصور والوسائط',
                  ),
                  const SizedBox(height: 8),
                  _buildFeatureRow(
                    icon: Icons.lock_outline,
                    text: 'محادثات آمنة ومشفرة',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddChatScreen()),
                ),
                icon: const Icon(Icons.add_rounded, size: 22),
                label: const Text(
                  'ابدأ محادثة جديدة',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF075E54),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow({required IconData icon, required String text}) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(String error) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
          const SizedBox(height: 16),
          Text(
            'حدث خطأ',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary(context)),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              final currentUserPhone = ref.read(appUserPhoneProvider);
              if (currentUserPhone != null) {
                ref.invalidate(chatsProvider(currentUserPhone));
                ref.invalidate(userDataProvider);
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  // ✅ نافذة الملف الشخصي


  // ✅ نافذة تعديل الملف الشخصي
  void _showEditProfileBottomSheet() {
    final currentUser = ref.read(appUserDataProvider);
    if (currentUser == null) return;

    final nameController = TextEditingController(text: currentUser.displayName);
    final emailController = TextEditingController(
      text: currentUser.email ?? '',
    );
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(25),
                    topRight: Radius.circular(25),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
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

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
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
                                backgroundColor: const Color(
                                  0xFF075E54,
                                ).withOpacity(0.1),
                                child: currentUser.imageUrl != null
                                    ? Container(
                                  height: double.infinity,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(60),
                                    image: DecorationImage(
                                      fit: BoxFit.cover,
                                      image: NetworkImage(currentUser.imageUrl!),
                                    ),
                                  ),
                                )
                                    : Text(
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
                            const SizedBox(height: 10),
                            InkWell(
                              onTap: () => _showImagePickerOptions(context, setModalState, (p0) {}, () {}, () {}),
                              child: Container(
                                height: 30,
                                width: 80,
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    color: Colors.green
                                ),
                                child: Center(child: Text('تعديل',style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold),)),
                              ),
                            ),
                          ],
                        ),

                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'اسم المستخدم',
                        labelStyle: const TextStyle(color: Color(0xFF075E54)),
                        hintText: 'أدخل اسمك الجديد',
                        prefixIcon: const Icon(
                          Icons.person,
                          color: Color(0xFF075E54),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF075E54),
                            width: 2,
                          ),
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
                        prefixIcon: const Icon(
                          Icons.email,
                          color: Color(0xFF075E54),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF075E54),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSaving
                                ? null
                                : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Colors.grey),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'إلغاء',
                              style: TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    final newName = nameController.text.trim();
                                    final newEmail = emailController.text
                                        .trim();

                                    if (newName.isEmpty) {
                                      Fluttertoast.showToast(
                                        msg: 'الاسم لا يمكن أن يكون فارغاً',
                                      );
                                      return;
                                    }
                                    if (newEmail.isEmpty) {
                                      Fluttertoast.showToast(
                                        msg:
                                            'البريد الإلكتروني لا يمكن أن يكون فارغاً',
                                      );
                                      return;
                                    }

                                    setModalState(() => isSaving = true);

                                    try {
                                      if (currentUser.id == null) {
                                        setModalState(() => isSaving = false);
                                        return;
                                      }
                                      final database = ref.read(
                                        firebaseDatabaseProvider,
                                      );
                                      await database
                                          .ref('users')
                                          .child(currentUser.id!)
                                          .update({
                                            'email': newEmail,
                                            'displayName': newName,
                                          });

                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      await prefs.setString(
                                        'userEmail',
                                        newEmail,
                                      );
                                      await prefs.setString(
                                        'userName',
                                        newName,
                                      );

                                      ref
                                          .read(appUserDataProvider.notifier)
                                          .state = currentUser.copyWith(
                                        displayName: newName,
                                        email: newEmail,
                                      );

                                      Fluttertoast.showToast(
                                        msg: 'تم تحديث البيانات بنجاح',
                                      );

                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                    } catch (e) {
                                      print('❌ خطأ أثناء تحديث البيانات: $e');
                                      Fluttertoast.showToast(
                                        msg: 'حدث خطأ أثناء حفظ البيانات',
                                      );
                                    } finally {
                                      if (context.mounted) {
                                        setModalState(() => isSaving = false);
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF075E54),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'حفظ',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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
  // ✅ دالة عرض خيارات اختيار الصورة
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
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text('اختيار من المعرض', style: TextStyle(fontWeight: FontWeight.w500)),
              onTap: () async {
                Navigator.pop(context);
                await _pickAndUploadImage(false, setModalState, onImageUploaded, onUploadStart, onUploadEnd);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
              title: const Text('التقاط صورة', style: TextStyle(fontWeight: FontWeight.w500)),
              onTap: () async {
                Navigator.pop(context);
                await _pickAndUploadImage(true, setModalState, onImageUploaded, onUploadStart, onUploadEnd);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

// ✅ دالة اختيار الصورة ورفعها
  Future<void> _pickAndUploadImage(
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
          //_showSuccessSnackBar('تم رفع الصورة بنجاح');
        } else {
         // _showErrorSnackBar('فشل رفع الصورة، حاول مرة أخرى');
        }
      }
    } catch (e) {
      print('❌ خطأ في رفع الصورة: $e');
      //_showErrorSnackBar('حدث خطأ: ${e.toString()}');
    } finally {
      onUploadEnd();
    }
  }
}
