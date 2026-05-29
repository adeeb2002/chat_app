import 'package:ChatApp/Provider/chatProvider.dart';
import 'package:ChatApp/Provider/userProvide.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/contact.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../service/share_service.dart';
import 'chatScreen.dart';

class AddChatScreen extends ConsumerStatefulWidget {
  const AddChatScreen({super.key});

  @override
  ConsumerState<AddChatScreen> createState() => _AddChatScreenState();
}

class _AddChatScreenState extends ConsumerState<AddChatScreen> {
  final receiverController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _selectedUserEmail;

  @override
  void dispose() {
    receiverController.dispose();
    super.dispose();
  }

  Future<void> _createChat() async {
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

      if(receiverPhone.contains(currentUser.phone) || receiverPhone==currentUser.phone){
        _showSnackBar('لا يمكن ان تنشء محادثة مع نفسك');
        return;
      }
      
      // إنشاء محادثة جديدة
      final chatId = await chatService.createChat(
        user1Phone: currentUser.phone,
        user2Phone: receiverPhone,
      );
      
      if (mounted && chatId!='noUser') {
        _showSnackBar('تم إنشاء المحادثة بنجاح', isError: false);
        
        // العودة إلى الشاشة الرئيسية مع تمرير chatId
        Navigator.pop(context, chatId);
      }

    } catch (e) {
      _showSnackBar('خطأ في إنشاء المحادثة: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
        backgroundColor:const Color(0xFF075E54),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // صورة توضيحية
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chat,
                    size: 50,
                    color: Colors.green,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              const Text(
                'بدء محادثة جديدة',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'أدخل الرقم للشخص الذي تريد التحدث معه',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 32),
              
              // معلومات المستخدم الحالي
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'أنت تتحدث بصفتك',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            currentUser?.displayName ?? 'المستخدم',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // حقل الرقم للمستلم
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
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال الرقم للمستلم';
                  }
                  if (value.length<10) {
                    return 'رقم الهاتف غير صالح';
                  }
                  if (value == currentUser?.email) {
                    return 'لا يمكنك إنشاء محادثة مع نفسك';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // نص توضيحي
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'سيتم إنشاء المحادثة فوراً، ويمكنك البدء في إرسال الرسائل',
                        style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // زر إنشاء المحادثة
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createChat,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF075E54),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat),
                            SizedBox(width: 8),
                            Text(
                              'بدء المحادثة',
                              style: TextStyle(fontSize: 18),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleContactTap(Contact contact) async {
    final myPhone = ref.read(appUserPhoneProvider); // الـ Provider الجديد لرقم هاتف المستخدم الحالي
    if (myPhone == null) return;

    if (contact.phones.isEmpty) {
      _showInviteDialog(contact.displayName, "لا يمتلك رقم هاتف مخزن.",contact.photo.toString());
      return;
    }

    // جلب رقم الهاتف وتجهيزه (يفضل أن تكون الأرقام مخزنة بصيغة دولية كاملة)
    final rawPhone = contact.phones.first.number;

    // تنظيف الرقم من المساحات أو الشرطات الافتراضية التي يضعها الهاتف (مثل: 059-999-999)
    final contactPhone = rawPhone.replaceAll(' ', '').replaceAll('-', '');

    setState(() => _isLoading = true);

    String _cleanPhone(String phone){
      return phone.replaceAll('+', 'p');
    }

    try {
      final db = FirebaseDatabase.instance;
      final cleanTargetPhone = _cleanPhone(contactPhone);

      // الفحص في عقدة users بناءً على رقم الهاتف
      final userSnapshot = await db.ref('users').child(cleanTargetPhone).get();

      if (userSnapshot.exists) {
        // المستخدم مسجل! ننشئ المحادثة برقم الهاتف مباشرة
        final chatService = ref.read(chatServiceProvider);
        final chatId = await chatService.createChat(
          user1Phone: myPhone, // المعامل هنا سيمثل رقم هاتف المرسل
          user2Phone: contactPhone, // رقم هاتف المستقبل
          initialMessage: "مرحباً! لقد أضفتك من جهات الاتصال.",
        );

        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        // غير مسجل -> دعوة عبر SMS
        //_showInviteDialog(contact.displayName, "هذا الرقم غير مسجل بالتطبيق.",cleanTargetPhone);
        ShareService().shareOnWhatsApp(context);
      }
    } catch (e) {
      print("❌ خطأ في المطابقة: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  void _showInviteDialog(String name, String phoneNumber, String reason) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('دعوة $name'),
        content: Text('$reason\nهل تود الانتقال إلى واتساب لدعوته لتحميل التطبيق وبدء الشات؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context); // إغلاق النافذة
/*
              // استدعاء دالة الواتساب الذكية
              await ref.watch(firebaseDatabaseProvider).sendWhatsAppInvite(
                phoneNumber: phoneNumber,
                contactName: name,
              );

 */
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF075E54), // لون الواتساب الأخضر المميز
              foregroundColor: Colors.white,
            ),
            icon: Container(height: 40, width: 40, decoration: BoxDecoration(image: DecorationImage(image: NetworkImage('https://cdn-icons-png.flaticon.com/128/3536/3536445.png'))),), // أيقونة الواتساب
            label: const Text('دعوة عبر واتساب'),
          ),
        ],
      ),
    );
  }
}