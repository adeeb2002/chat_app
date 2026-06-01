import 'dart:async';
import 'package:ChatApp/Provider/chatProvider.dart';
import 'package:ChatApp/Provider/userProvide.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_database/firebase_database.dart';

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
  bool _permissionDenied = false;
  List<ContactItem> _contacts = [];
  List<ContactItem> _filteredContacts = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_filterContacts);
  }

  @override
  void dispose() {
    receiverController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ✅ تنظيف رقم الهاتف (إزالة المسافات والشرطات)
  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^\d]'), '');
  }

  // ✅ تحميل جهات الاتصال والتحقق منها
  Future<void> _loadContacts() async {
    setState(() {
      _isLoadingContacts = true;
      _permissionDenied = false;
    });

    // 1. طلب الصلاحية
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

    try {
      // 2. جلب أرقام المستخدمين المسجلين في التطبيق من Firebase
      final db = FirebaseDatabase.instance;
      final usersSnapshot = await db.ref('users').get();
      final registeredPhones = <String>{};

      if (usersSnapshot.exists) {
        final data = usersSnapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final phone = (value as Map)['phone']?.toString() ?? '';
          if (phone.isNotEmpty) {
            registeredPhones.add(_normalizePhone(phone));
          }
        });
      }

      // 3. جلب جهات الاتصال من الهاتف
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      final contactItems = <ContactItem>[];
      final seenPhones = <String>{};

      for (var contact in contacts) {
        if (contact.phones.isEmpty) continue;

        for (var phone in contact.phones) {
          final normalized = _normalizePhone(phone.number);

          // تجنب تكرار نفس الرقم
          if (normalized.length < 6 || seenPhones.contains(normalized)) continue;
          seenPhones.add(normalized);

          // التحقق هل الرقم مسجل في التطبيق
          bool isRegistered = registeredPhones.contains(normalized) ||
              registeredPhones.any((p) => normalized.endsWith(p) || p.endsWith(normalized));

          contactItems.add(ContactItem(
            name: contact.displayName,
            phone: normalized,
            displayPhone: phone.number,
            isRegistered: isRegistered,
          ));
        }
      }

      // ترتيب: المسجلين أولاً، ثم أبجدياً
      contactItems.sort((a, b) {
        if (a.isRegistered != b.isRegistered) return a.isRegistered ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      if (mounted) {
        setState(() {
          _contacts = contactItems;
          _filteredContacts = contactItems;
          _isLoadingContacts = false;
        });
      }
    } catch (e) {
      print('❌ خطأ في تحميل جهات الاتصال: $e');
      if (mounted) {
        setState(() => _isLoadingContacts = false);
      }
    }
  }

  // ✅ البحث في جهات الاتصال
  void _filterContacts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredContacts = _contacts.where((contact) {
        return contact.name.toLowerCase().contains(query) ||
            contact.phone.contains(query);
      }).toList();
    });
  }

  // ✅ إنشاء محادثة (للمسجلين في التطبيق)
  Future<void> _createChat(String receiverPhone, String receiverName) async {
    final currentUser = ref.read(appUserDataProvider);
    if (currentUser == null) {
      _showSnackBar('الرجاء تسجيل الدخول أولاً');
      return;
    }

    if (receiverPhone.contains(currentUser.phone) || receiverPhone == currentUser.phone) {
      _showSnackBar('لا يمكنك إنشاء محادثة مع نفسك');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final chatService = ref.read(chatServiceProvider);
      final chatId = await chatService.createChat(
        user1Phone: currentUser.phone,
        user2Phone: receiverPhone,
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

  // ✅ إنشاء محادثة يدوي (بإدخال الرقم)
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

      if (receiverPhone.contains(currentUser.phone) || receiverPhone == currentUser.phone) {
        _showSnackBar('لا يمكنك إنشاء محادثة مع نفسك');
        return;
      }

      final targetUser = await ref.read(authServiceProvider).getUserByPhone(receiverPhone);
      if (targetUser == null) {
        // الرقم غير مسجل، عرض خيار الدعوة
        _showInviteDialog(receiverPhone);
        return;
      }

      final chatId = await chatService.createChat(
        user1Phone: currentUser.phone,
        user2Phone: receiverPhone,
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

  // ✅ فتح واتساب لإرسال دعوة
  Future<void> _inviteToWhatsApp(String phone, String name) async {
    // تنسيق الرقم (إضافة رمز الدولة إذا لم يكن موجوداً)
    String formattedPhone = phone;
    if (!phone.startsWith('+') && !phone.startsWith('00')) {
      if (phone.startsWith('0')) {
        formattedPhone = '970${phone.substring(1)}'; // تغيير 970 حسب رمز دولتك (فلسطين مثال)
      } else {
        formattedPhone = '970$phone';
      }
    } else {
      formattedPhone = phone.replaceAll('+', '').replaceAll('00', '');
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
        if (mounted) _showSnackBar('لا يمكن فتح واتساب، تأكد من تثبيته');
      }
    } catch (e) {
      if (mounted) _showSnackBar('حدث خطأ: $e');
    }
  }

  // ✅ حوار تأكيد الدعوة
  void _showInviteDialog(String phone) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رقم غير مسجل'),
        content: Text('الرقم $phone غير مسجل في التطبيق. هل تريد إرسال دعوة عبر واتساب؟'),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Colors.green, width: 2),
                ),
              ),
            ),
          ),

          // ✅ إدخال يدوي للرقم (مطوي)
          ExpansionTile(
            leading: const Icon(Icons.dialpad, color: Color(0xFF075E54)),
            title: const Text('إدخال رقم يدوياً', style: TextStyle(fontWeight: FontWeight.bold)),
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
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(color: Colors.green, width: 2),
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
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
                  const Text('لم يتم السماح بالوصول لجهات الاتصال'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => openAppSettings(),
                    icon: const Icon(Icons.settings),
                    label: const Text('فتح الإعدادات'),
                  ),
                  TextButton(
                    onPressed: _loadContacts,
                    child: const Text('حاول مرة أخرى'),
                  ),
                ],
              ),
            )
                : _filteredContacts.isEmpty
                ? const Center(child: Text('لا توجد جهات اتصال'))
                : ListView.builder(
              itemCount: _filteredContacts.length,
              itemBuilder: (context, index) {
                final contact = _filteredContacts[index];
                return _buildContactItem(contact);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ✅ تصميم عنصر جهة الاتصال
  Widget _buildContactItem(ContactItem contact) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: contact.isRegistered ? Colors.green[100] : Colors.grey[200],
        child: Icon(
          contact.isRegistered ? Icons.person : Icons.person_outline,
          color: contact.isRegistered ? Colors.green : Colors.grey,
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
          ? Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          Text(
            'متاح',
            style: TextStyle(fontSize: 10, color: Colors.green[700]),
          ),
        ],
      )
          : const Icon(Icons.message, color: Color(0xFF25D366)), // لون واتساب
      onTap: () {
        if (contact.isRegistered) {
          _createChat(contact.phone, contact.name);
        } else {
          _inviteToWhatsApp(contact.phone, contact.name);
        }
      },
    );
  }
}