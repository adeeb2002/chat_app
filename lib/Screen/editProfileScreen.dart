import 'dart:async';

import 'package:ChatApp/Provider/userProvide.dart';
import 'package:ChatApp/service/ImageUploadService.dart';
import 'package:ChatApp/theme/app_theme.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  String? _selectedImageUrl;
  bool _isSaving = false;
  bool _isUploading = false;
  bool _initialized = false;
  bool _isConnected = true;

  // ✅ متغيرات لتغيير رقم الهاتف
  bool _isChangingPhone = false;
  late TextEditingController _newPhoneController;
  String? _currentPhone;

  late StreamSubscription _internetSubscription;

  @override
  void initState() {
    super.initState();
    _internetSubscription = InternetConnection().onStatusChange.listen((status) {
      if (mounted) {
        setState(() {
          _isConnected = status == InternetStatus.connected;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final user = ref.read(appUserDataProvider);
      _nameController = TextEditingController(text: user?.displayName ?? '');
      _emailController = TextEditingController(text: user?.email ?? '');
      _phoneController = TextEditingController(text: user?.phone ?? '');
      _selectedImageUrl = user?.imageUrl;
      _currentPhone = user?.phone;
      _newPhoneController = TextEditingController();
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _internetSubscription.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _newPhoneController.dispose();
    super.dispose();
  }

  // ✅ التحقق من الاتصال بالإنترنت
  bool _checkInternetConnection() {
    if (!_isConnected) {
      _showNoInternetSnackBar();
      return false;
    }
    return true;
  }

  void _showNoInternetSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(child: Text('لا يوجد اتصال بالإنترنت، يرجى التحقق من اتصالك')),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _pickImage(bool fromCamera) async {
    // ✅ التحقق من الاتصال بالإنترنت قبل رفع الصورة
    if (!_checkInternetConnection()) return;

    final imageService = ImageUploadService();
    final imageFile = await imageService.pickImage(fromCamera: fromCamera);
    if (imageFile == null) return;

    setState(() => _isUploading = true);
    try {
      final url = await imageService.uploadImage(imageFile);
      if (url != null && mounted) {
        setState(() {
          _selectedImageUrl = url;
          _isUploading = false;
        });
        _showSuccessSnackBar('تم رفع الصورة بنجاح');
      } else {
        if (mounted) {
          setState(() => _isUploading = false);
          _showErrorSnackBar('فشل رفع الصورة');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        _showErrorSnackBar('خطأ: $e');
      }
    }
  }

  void _showImagePickerDialog() {
    // ✅ التحقق من الاتصال بالإنترنت قبل فتح نافذة اختيار الصورة
    if (!_checkInternetConnection()) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('تغيير الصورة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.photo_library, color: AppTheme.primaryLight),
                title: const Text('اختيار من المعرض'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(false);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt, color: AppTheme.primaryLight),
                title: const Text('التقاط صورة'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ تغيير رقم الهاتف (مع التحقق من الإنترنت)
  Future<void> _changePhoneDirectly() async {
    if (!_checkInternetConnection()) return;

    final newPhone = _newPhoneController.text.trim();
    if (newPhone.isEmpty) {
      _showErrorSnackBar('الرجاء إدخال رقم الهاتف الجديد');
      return;
    }

    if (newPhone == _currentPhone) {
      _showErrorSnackBar('الرقم الجديد مطابق للرقم الحالي');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final database = FirebaseDatabase.instance;

      // 1️⃣ التأكد من أن الرقم الجديد غير مستخدم
      final checkSnapshot = await database.ref('users').child(newPhone).get();
      if (checkSnapshot.exists) {
        setState(() => _isSaving = false);
        _showErrorSnackBar('رقم الهاتف الجديد مستخدم بالفعل');
        return;
      }

      final currentUser = ref.read(appUserDataProvider);
      if (currentUser != null) {
        final oldPhone = currentUser.phone;

        final oldSnapshot = await database.ref('users').child(oldPhone).get();

        if (oldSnapshot.exists) {
          final userData = Map<String, dynamic>.from(oldSnapshot.value as Map);

          // نقل البيانات إلى الرقم الجديد
          await database.ref('users').child(newPhone).set({
            ...userData,
            'phone': newPhone,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          });

          // حذف الرقم القديم
          await database.ref('users').child(oldPhone).remove();

          // تحديث المحادثات
          final chatsSnapshot = await database.ref('chats').get();
          if (chatsSnapshot.exists) {
            final chats = chatsSnapshot.value as Map;
            for (var entry in chats.entries) {
              final chatId = entry.key;
              final chatData = Map<String, dynamic>.from(entry.value);
              final participants = List<String>.from(chatData['participants'] ?? []);

              if (participants.contains(oldPhone)) {
                participants.remove(oldPhone);
                participants.add(newPhone);
                await database.ref('chats').child(chatId).update({'participants': participants});
              }
            }
          }

          // تحديث SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('phone', newPhone);
          await prefs.setString('userId', newPhone);

          // تحديث Providers
          final updatedUser = currentUser.copyWith(phone: newPhone, id: newPhone);
          ref.read(appUserDataProvider.notifier).state = updatedUser;
          ref.read(appUserPhoneProvider.notifier).state = newPhone;

          if (mounted) {
            _showSuccessSnackBar('تم تغيير رقم الهاتف بنجاح');
            Navigator.pop(context);
          }

          setState(() {
            _isChangingPhone = false;
            _phoneController.text = newPhone;
            _currentPhone = newPhone;
            _newPhoneController.clear();
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('فشل تغيير الرقم: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ✅ حفظ التعديلات (مع التحقق من الإنترنت)
  Future<void> _saveProfile() async {
    if (!_checkInternetConnection()) return;

    final user = ref.read(appUserDataProvider);
    if (user == null || user.id == null) return;

    final newName = _nameController.text.trim();
    final newEmail = _emailController.text.trim();

    if (newName.isEmpty) {
      _showErrorSnackBar('الاسم لا يمكن أن يكون فارغاً');
      return;
    }
    if (newEmail.isEmpty) {
      _showErrorSnackBar('البريد الإلكتروني لا يمكن أن يكون فارغاً');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final database = FirebaseDatabase.instance;

      final updates = <String, dynamic>{
        'email': newEmail,
        'displayName': newName,
      };
      if (_selectedImageUrl != null) {
        updates['imageUrl'] = _selectedImageUrl;
      }

      await database.ref('users').child(user.id!).update(updates);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userEmail', newEmail);
      await prefs.setString('userName', newName);

      ref.read(appUserDataProvider.notifier).state = user.copyWith(
        displayName: newName,
        email: newEmail,
        imageUrl: _selectedImageUrl,
      );

      if (mounted) {
        _showSuccessSnackBar('تم تحديث البيانات بنجاح');
        Navigator.pop(context);
      }
    } catch (e) {
      _showErrorSnackBar('حدث خطأ: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ✅ نافذة تغيير رقم الهاتف
  void _showChangePhoneDialog() {
    setState(() {
      _isChangingPhone = true;
      _newPhoneController.clear();
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'تغيير رقم الهاتف',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            const Text('الرقم الحالي', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone, color: Colors.grey),
                  const SizedBox(width: 12),
                  Text(_currentPhone ?? '', style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('الرقم الجديد', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _newPhoneController,
              keyboardType: TextInputType.phone,
              enabled: _isConnected, // ✅ تعطيل الحقل إذا كان الإنترنت مقطوع
              decoration: InputDecoration(
                hintText: '0590000000',
                prefixIcon: const Icon(Icons.phone_android),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryColor),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _isChangingPhone = false);
                      Navigator.pop(ctx);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving || !_isConnected ? null : _changePhoneDirectly,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : const Text('تأكيد وحفظ الرقم'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ).then((_) {
      setState(() => _isChangingPhone = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserDataProvider);
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppTheme.surfaceContainer(context),
      appBar: AppBar(
        title: const Text('تعديل الملف الشخصي'),
        centerTitle: true,
        elevation: 0,
        actions: [
          // ✅ إضافة أيقونة حالة الاتصال
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(
                  _isConnected ? Icons.wifi : Icons.wifi_off,
                  size: 20,
                  color: _isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  _isConnected ? 'متصل' : 'غير متصل',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isConnected ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 16),

              // ✅ صورة الملف الشخصي
              Center(
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryLight.withOpacity(0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 65,
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        backgroundImage: _selectedImageUrl != null && _selectedImageUrl!.isNotEmpty
                            ? NetworkImage(_selectedImageUrl!)
                            : null,
                        child: (_selectedImageUrl == null || _selectedImageUrl!.isEmpty)
                            ? Text(
                          user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U',
                          style: TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _isUploading || !_isConnected ? null : _showImagePickerDialog,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: !_isConnected ? Colors.grey : AppTheme.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: _isUploading
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                              : Icon(
                            Icons.camera_alt,
                            color: !_isConnected ? Colors.grey.shade400 : Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ✅ حقل الاسم
              const Text('الاسم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                enabled: _isConnected, // ✅ تعطيل إذا كان الإنترنت مقطوع
                decoration: InputDecoration(
                  hintText: 'أدخل اسمك',
                  prefixIcon: Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF075E54), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ✅ حقل البريد الإلكتروني
              const Text('البريد الإلكتروني', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                enabled: _isConnected, // ✅ تعطيل إذا كان الإنترنت مقطوع
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'example@gmail.com',
                  prefixIcon: Icon(Icons.email, color: Theme.of(context).colorScheme.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF075E54), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ✅ رقم الهاتف
              const Text('رقم الهاتف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phone, color: Colors.grey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(user.phone, style: Theme.of(context).textTheme.titleMedium),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: _isConnected
                            ? AppTheme.primaryColor.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextButton.icon(
                        onPressed: !_isConnected ? null : _showChangePhoneDialog,
                        icon: Icon(Icons.edit, size: 16, color: _isConnected ? null : Colors.grey),
                        label: Text(
                          'تغيير',
                          style: TextStyle(fontSize: 12, color: _isConnected ? null : Colors.grey),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'سيتم تحديث رقم الهاتف مباشرة ونقل محادثاتك للرقم الجديد.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 32),

              // ✅ زر الحفظ
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving || !_isConnected ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !_isConnected ? Colors.grey : AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Text(
                    'حفظ التعديلات',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),

          // ✅ Banner في الأعلى عند انقطاع الإنترنت
          if (!_isConnected)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: Colors.red.shade700,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off, size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'لا يوجد اتصال بالإنترنت - التعديل غير متاح',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}