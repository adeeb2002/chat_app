import 'dart:async';
import 'package:ChatApp/Animation/RouteAnimation.dart';
import 'package:ChatApp/Provider/chatProvider.dart';
import 'package:ChatApp/Provider/userProvide.dart';
import 'package:ChatApp/Screen/addChatScreen.dart';
import 'package:ChatApp/Screen/loginScreen.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:intl/intl.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../Notifications/CacheService.dart';
import '../Provider/network_provider.dart';
import '../model/chat.dart';
import '../model/user.dart';
import '../service/NetworkOptimizationService.dart';
import '../theme/app_theme.dart';
import '../widgets/CustomSearchBar.dart';
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
        final localUser = AppUser(
          id: userId,
          phone: phone,
          email: userEmail,
          displayName: userName ?? phone,
          isOnline: false,
        );

        ref.read(appUserDataProvider.notifier).state = localUser;
        ref.read(appUserPhoneProvider.notifier).state = phone;

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
    WidgetsBinding.instance.removeObserver(this);
    connectionSubscription?.cancel();
    searchController.dispose();
    _cacheService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      print('🔄 التطبيق عاد للمقدمة، فحص حالة الاتصال...');

      // ✅ فحص حالة الاتصال
      final currentUserPhone = ref.read(appUserPhoneProvider);
      final isOnline = ref.read(internetConnectionProvider);

      if (isOnline && currentUserPhone != null) {
        print('🌐 الاتصال متاح، تحديث البيانات...');

        // تحديث حالة المستخدم في Firebase
        final currentUser = ref.read(appUserDataProvider);
        if (currentUser?.id != null) {
          ref.read(authServiceProvider).setupPresence(currentUser!.id!);
        }

        // تحديث المحادثات
        ref.invalidate(chatsProvider(currentUserPhone));
      } else {
        print('📴 لا يوجد اتصال، الاستمرار في الوضع Offline');
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

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final currentUser = ref.watch(appUserDataProvider);
    final currentUserPhone = ref.watch(appUserPhoneProvider);

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

    if (NetworkOptimizationService().isSlowConnection) {
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.speed, size: 18, color: Colors.orange),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'اتصال بطيء - تم تفعيل الوضع الموفر للبيانات',
                style: TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ),
          ],
        ),
      );
    };

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
                    color: AppTheme.warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
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
                      if (chats.isEmpty &&
                          !isConnected &&
                          _cacheService.hasCachedData()) {
                        final cachedChats = _cacheService.getCachedChats();
                        if (cachedChats.isNotEmpty) {
                          return _buildChatList(cachedChats, currentUserPhone);
                        }
                      }

                      if (chats.isEmpty) return _buildEmptyState(currentUser, currentUserPhone);

                      return _buildChatList(chats, currentUserPhone);
                    },
                    loading: () {
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
      // ✅ FloatingActionButton يظهر فقط عند وجود محادثات
      floatingActionButton: _buildFloatingActionButton(currentUserPhone),
    );
  }

  // ✅ دالة بناء الزر العائم (يظهر فقط عند وجود محادثات)
  Widget? _buildFloatingActionButton(String currentUserPhone) {
    final chatsAsync = ref.watch(chatsProvider(currentUserPhone));

    // استخدام when الموجود في Riverpod بدلاً من FutureBuilder
    return chatsAsync.when(
      data: (chats) {
        // ✅ إذا كانت قائمة المحادثات غير فارغة، نعرض الزر
        if (chats.isNotEmpty) {
          return FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                RouteAnimation.slideFromRight(AddChatScreen()),
              );
            },
            backgroundColor: const Color(0xFF075E54),
            child: const Icon(Icons.chat, color: Colors.white),
          );
        }
        // ✅ إذا كانت القائمة فارغة، نخفي الزر
        return null;
      },
      loading: () => null, // أثناء التحميل لا نعرض الزر
      error: (_, __) => null, // في حالة الخطأ لا نعرض الزر
    );
  }

  // ✅ دالة بناء الشاشة الفارغة مع زر في المنتصف
  Widget _buildEmptyState(AppUser currentUser, String currentUserPhone) {
    final theme = Theme.of(context);
    final chatsAsync = ref.watch(chatsProvider(currentUserPhone));

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
                    theme.colorScheme.primary.withOpacity(0.1),
                    AppTheme.primaryLight.withOpacity(0.1),
                  ],
                ),
              ),
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withOpacity(0.1),
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
                    color: theme.shadowColor.withOpacity(0.03),
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

            // ✅ زر إضافة محادثة في منتصف الشاشة
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  RouteAnimation.slideFromRight(AddChatScreen()),
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
            color: theme.colorScheme.primary.withOpacity(0.08),
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
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(15),
            child: ListTile(
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
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
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(15),
            child: ListTile(
              leading: CircleAvatar(
                radius: 28,
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
      ),
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
}
