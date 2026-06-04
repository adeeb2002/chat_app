import 'dart:async';
import 'package:ChatApp/Provider/chatProvider.dart';
import 'package:ChatApp/Provider/userProvide.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class ContactItem {
  final String name;
  final String phone;
  final String displayPhone;
  bool isRegistered;

  ContactItem({
    required this.name,
    required this.phone,
    required this.displayPhone,
    this.isRegistered = false,
  });

  // ✅ نسخة للكاش
  ContactItem copyWith({bool? isRegistered}) {
    return ContactItem(
      name: name,
      phone: phone,
      displayPhone: displayPhone,
      isRegistered: isRegistered ?? this.isRegistered,
    );
  }
}

class AddChatScreen extends ConsumerStatefulWidget {
  const AddChatScreen({super.key});

  @override
  ConsumerState<AddChatScreen> createState() => _AddChatScreenState();
}

class _AddChatScreenState extends ConsumerState<AddChatScreen> {
  final receiverController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLoadingContacts = true;
  bool _isCheckingRegistration = false;
  bool _permissionDenied = false;
  List<ContactItem> _contacts = [];
  List<ContactItem> _filteredContacts = [];
  final TextEditingController _searchController = TextEditingController();

  // ✅ كاش محسن
  static List<ContactItem>? _cachedContacts;
  static DateTime? _lastCacheTime;
  static Set<String>? _cachedRegisteredPhones;
  static DateTime? _lastFirebaseCacheTime;
  static const Duration _cacheDuration = Duration(minutes: 10);

  // ✅ لتتبع حالة التحميل
  bool _isLoadingFirebase = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterContacts);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadContacts();
    });
  }

  @override
  void dispose() {
    receiverController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^\d]'), '');
  }

  // ✅ تحميل جهات الاتصال في Isolate
  Future<List<ContactItem>> _fetchContactsInBackground() async {
    try {
      final contacts = await FlutterContacts.getAll();

      final contactItems = <ContactItem>[];
      final seenPhones = <String>{};

      for (var contact in contacts) {
        if (contact.phones.isEmpty) continue;

        for (var phone in contact.phones) {
          final normalized = _normalizePhone(phone.number);
          if (normalized.length < 6 || seenPhones.contains(normalized)) continue;
          seenPhones.add(normalized);

          contactItems.add(ContactItem(
            name: contact.displayName!.isNotEmpty ? contact.displayName! : 'بدون اسم',
            phone: normalized,
            displayPhone: phone.number,
            isRegistered: false,
          ));
        }
      }

      // ترتيب أبجدي
      contactItems.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return contactItems;
    } catch (e) {
      print('❌ خطأ في تحميل جهات الاتصال: $e');
      return [];
    }
  }

  // ✅ تحميل الأرقام المسجلة من Firebase في الخلفية
  Future<Set<String>> _fetchRegisteredPhonesInBackground() async {
    try {
      final db = FirebaseDatabase.instance;
      final usersSnapshot = await db
          .ref('users')
          .get()
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Firebase timeout'),
      );

      final registeredPhones = <String>{};

      if (usersSnapshot.exists) {
        final data = usersSnapshot.value as Map<dynamic, dynamic>;
        for (var entry in data.entries) {
          if (entry.value is Map) {
            final phone = entry.value['phone']?.toString() ?? '';
            if (phone.isNotEmpty) {
              registeredPhones.add(_normalizePhone(phone));
            }
          }
        }
      }

      print('✅ تم جلب ${registeredPhones.length} رقم مسجل من Firebase');
      return registeredPhones;
    } catch (e) {
      print('❌ خطأ في جلب المستخدمين المسجلين: $e');
      return {};
    }
  }

  Future<void> _loadContacts() async {
    if (!mounted) return;

    // ✅ استخدام الكاش
    if (_cachedContacts != null &&
        _lastCacheTime != null &&
        DateTime.now().difference(_lastCacheTime!) < _cacheDuration) {
      if (mounted) {
        setState(() {
          _contacts = _cachedContacts!;
          _filteredContacts = _cachedContacts!;
          _isLoadingContacts = false;
        });
      }
      await _refreshRegistrationStatus();
      return;
    }

    // ✅ طلب الإذن
    var status = await Permission.contacts.status;
    if (!status.isGranted) {
      status = await Permission.contacts.request();
    }

    if (!status.isGranted) {
      if (mounted) {
        setState(() {
          _isLoadingContacts = false;
          _permissionDenied = true;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingContacts = true;
        _permissionDenied = false;
      });
    }

    try {
      // ✅ تحميل جهات الاتصال
      final contactItems = await _fetchContactsInBackground();

      if (!mounted) return;

      // ✅ حفظ في الكاش
      _cachedContacts = contactItems;
      _lastCacheTime = DateTime.now();

      if (mounted) {
        setState(() {
          _contacts = contactItems;
          _filteredContacts = contactItems;
          _isLoadingContacts = false;
        });
      }

      // ✅ تحميل الأرقام المسجلة في الخلفية
      await _refreshRegistrationStatus();

    } catch (e) {
      print('❌ خطأ في تحميل جهات الاتصال: $e');
      if (mounted) {
        setState(() {
          _isLoadingContacts = false;
        });
      }
    }
  }

  Future<void> _refreshRegistrationStatus() async {
    if (!mounted) return;

    // ✅ إذا كان هناك تحميل جارٍ، لا نبدأ آخر
    if (_isLoadingFirebase) return;

    setState(() {
      _isLoadingFirebase = true;
      _isCheckingRegistration = true;
    });

    // ✅ استخدام الكاش
    Set<String> registeredPhones;
    if (_cachedRegisteredPhones != null &&
        _lastFirebaseCacheTime != null &&
        DateTime.now().difference(_lastFirebaseCacheTime!) < _cacheDuration) {
      registeredPhones = _cachedRegisteredPhones!;
    } else {
      // ✅ تحميل في الخلفية
      registeredPhones = await _fetchRegisteredPhonesInBackground();

      // ✅ حفظ في الكاش
      _cachedRegisteredPhones = registeredPhones;
      _lastFirebaseCacheTime = DateTime.now();
    }

    if (!mounted) {
      setState(() => _isLoadingFirebase = false);
      return;
    }

    final currentUser = ref.read(appUserDataProvider);
    final currentPhone = _normalizePhone(currentUser?.phone ?? '');

    // ✅ تحديث حالة التسجيل (في خيط منفصل لتجنب التجميد)
    final updatedContacts = <ContactItem>[];

    for (var c in _contacts) {
      // استبعاد المستخدم الحالي
      if (c.phone == currentPhone) continue;

      final isReg = registeredPhones.any((p) =>
      c.phone == p || c.phone.endsWith(p) || p.endsWith(c.phone)
      );

      updatedContacts.add(c.copyWith(isRegistered: isReg));
    }

    // ✅ ترتيب: المسجلين أولاً
    updatedContacts.sort((a, b) {
      if (a.isRegistered != b.isRegistered) return a.isRegistered ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    // ✅ تحديث الكاش
    _cachedContacts = updatedContacts;

    if (mounted) {
      setState(() {
        _contacts = updatedContacts;
        final query = _searchController.text.toLowerCase();
        if (query.isEmpty) {
          _filteredContacts = updatedContacts;
        } else {
          _filteredContacts = updatedContacts.where((c) {
            return c.name.toLowerCase().contains(query) ||
                c.phone.contains(query);
          }).toList();
        }
        _isCheckingRegistration = false;
        _isLoadingFirebase = false;
      });
    }
  }

  void _filterContacts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredContacts = _contacts.where((contact) {
        return contact.name.toLowerCase().contains(query) ||
            contact.phone.contains(query);
      }).toList();
    });
  }

  Future<void> _createChat(String receiverPhone, String receiverName) async {
    final currentUser = ref.read(appUserDataProvider);
    if (currentUser == null) {
      _showSnackBar('الرجاء تسجيل الدخول أولاً');
      return;
    }

    final normalizedReceiver = _normalizePhone(receiverPhone);
    final normalizedCurrent = _normalizePhone(currentUser.phone);

    if (normalizedReceiver == normalizedCurrent) {
      _showSnackBar('لا يمكنك إنشاء محادثة مع نفسك');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final chatService = ref.read(chatServiceProvider);
      final targetUser = await ref.read(authServiceProvider).getUserByPhone(receiverPhone);

      if (targetUser == null) {
        _showSnackBar('الرقم غير مسجل في التطبيق');
        return;
      }

      final chatId = await chatService.createChat(
        user1Phone: currentUser.phone,
        user2Phone: targetUser.phone,
      );

      if (mounted && chatId != 'noUser') {
        _showSnackBar('تم إنشاء المحادثة مع $receiverName بنجاح', isError: false);
        Navigator.pop(context, chatId);
      }
    } catch (e) {
      _showSnackBar('خطأ في إنشاء المحادثة: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createManualChat() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) return;

    final currentUser = ref.read(appUserDataProvider);
    if (currentUser == null) {
      _showSnackBar('الرجاء تسجيل الدخول أولاً');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final chatService = ref.read(chatServiceProvider);
      final receiverPhone = receiverController.text.trim();
      final normalizedReceiver = _normalizePhone(receiverPhone);
      final normalizedCurrent = _normalizePhone(currentUser.phone);

      if (normalizedReceiver == normalizedCurrent) {
        _showSnackBar('لا يمكنك إنشاء محادثة مع نفسك');
        return;
      }

      final targetUser = await ref.read(authServiceProvider).getUserByPhone(receiverPhone);
      if (targetUser == null) {
        _showInviteDialog(receiverPhone);
        return;
      }

      final chatId = await chatService.createChat(
        user1Phone: currentUser.phone,
        user2Phone: targetUser.phone,
      );

      if (mounted && chatId != 'noUser') {
        _showSnackBar('تم إنشاء المحادثة بنجاح', isError: false);
        Navigator.pop(context, chatId);
      }
    } catch (e) {
      _showSnackBar('خطأ في إنشاء المحادثة: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _inviteToWhatsApp(String phone, String name) async {
    String formattedPhone = _normalizePhone(phone);

    if (formattedPhone.startsWith('0')) {
      formattedPhone = '970${formattedPhone.substring(1)}';
    }

    final message = Uri.encodeComponent(
      'مرحباً $name! 🚀\nأنا أستخدم تطبيق ChatApp للدردشة، حمّله الآن وتواصل معي!\n[رابط تحميل التطبيق]',
    );

    final url = 'https://wa.me/$formattedPhone?text=$message';

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) _showSnackBar('لا يمكن فتح واتساب');
      }
    } catch (e) {
      if (mounted) _showSnackBar('حدث خطأ: $e');
    }
  }

  void _showInviteDialog(String phone) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رقم غير مسجل'),
        content: Text('الرقم $phone غير مسجل في التطبيق.\nهل تريد إرسال دعوة عبر واتساب؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _inviteToWhatsApp(phone, '');
            },
            icon: const Icon(Icons.message, size: 18),
            label: const Text('دعوة عبر واتساب'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(appUserDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('محادثة جديدة'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () {
              _cachedContacts = null;
              _cachedRegisteredPhones = null;
              _lastCacheTime = null;
              _lastFirebaseCacheTime = null;
              _loadContacts();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ✅ شريط البحث
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو الرقم...',
                prefixIcon: const Icon(Icons.search, color: Colors.green),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _filterContacts();
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Colors.green, width: 2),
                ),
              ),
            ),
          ),

          // ✅ إدخال يدوي
          ExpansionTile(
            leading: const Icon(Icons.dialpad, color: Color(0xFF075E54)),
            title: const Text(
              'إدخال رقم يدوياً',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: receiverController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'الرقم للمستلم',
                          hintText: '0590000000',
                          prefixIcon: const Icon(Icons.person_add, color: Colors.green),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'الرجاء إدخال الرقم';
                          if (value.length < 10) return 'رقم الهاتف غير صالح';
                          if (value == currentUser?.phone) return 'لا يمكنك المحادثة مع نفسك';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _createManualChat,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF075E54),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          )
                              : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat),
                              SizedBox(width: 8),
                              Text('بدء المحادثة', style: TextStyle(fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const Divider(height: 1),

          // ✅ قائمة جهات الاتصال
          Expanded(
            child: _isLoadingContacts
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.green),
                  SizedBox(height: 16),
                  Text('جاري تحميل جهات الاتصال...'),
                ],
              ),
            )
                : _permissionDenied
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.contact_page, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'لم يتم السماح بالوصول لجهات الاتصال',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => openAppSettings(),
                    icon: const Icon(Icons.settings),
                    label: const Text('فتح الإعدادات'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loadContacts,
                    child: const Text('حاول مرة أخرى'),
                  ),
                ],
              ),
            )
                : _filteredContacts.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    _searchController.text.isEmpty
                        ? 'لا توجد جهات اتصال'
                        : 'لا توجد نتائج للبحث',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
                : Column(
              children: [
                // ✅ مؤشر التحقق من الأرقام
                if (_isCheckingRegistration)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 16,
                    ),
                    color: Colors.amber.withOpacity(0.15),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.amber,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'جاري التحقق من الأرقام المسجلة...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),

                // ✅ إحصائيات سريعة
                if (!_isCheckingRegistration && _filteredContacts.where((c) => c.isRegistered).isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 16,
                    ),
                    color: Colors.green.withOpacity(0.05),
                    child: Text(
                      '${_filteredContacts.where((c) => c.isRegistered).length} من أصدقائك على التطبيق',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredContacts.length,
                    itemBuilder: (context, index) {
                      final contact = _filteredContacts[index];
                      return _buildContactItem(contact);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(ContactItem contact) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: contact.isRegistered
              ? Colors.green[100]
              : Colors.grey[200],
          child: Text(
            contact.name.isNotEmpty
                ? contact.name[0].toUpperCase()
                : '?',
            style: TextStyle(
              color: contact.isRegistered ? Colors.green[700] : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          contact.name.isNotEmpty ? contact.name : contact.displayPhone,
          style: TextStyle(
            fontWeight: contact.isRegistered ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          contact.displayPhone,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing: contact.isRegistered
            ? Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chat, color: Colors.green, size: 14),
              const SizedBox(width: 4),
              Text(
                'محادثة',
                style: TextStyle(
                  color: Colors.green[700],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        )
            : Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF25D366)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.message, color: Color(0xFF25D366), size: 14),
              SizedBox(width: 4),
              Text(
                'دعوة',
                style: TextStyle(
                  color: Color(0xFF25D366),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        onTap: _isLoading
            ? null
            : () {
          if (contact.isRegistered) {
            _createChat(contact.phone, contact.name);
          } else {
            _inviteToWhatsApp(contact.phone, contact.name);
          }
        },
      ),
    );
  }
}