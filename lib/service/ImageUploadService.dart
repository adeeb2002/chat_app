// lib/services/image_upload_service.dart

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ImageUploadService {
  static final ImageUploadService _instance = ImageUploadService._internal();
  factory ImageUploadService() => _instance;
  ImageUploadService._internal();

  // ✅ مفتاح API من ImgBB (ضع مفتاحك الحقيقي هنا)
  static const String _apiKey = 'af33820276aaa4314c6169f1bb387d7b'; // 🔑 استبدل بمفتاحك

  final ImagePicker _picker = ImagePicker();

  /// ✅ اختيار صورة من المعرض أو الكاميرا
  Future<File?> pickImage({required bool fromCamera}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 70, // جودة الصورة
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('❌ خطأ في اختيار الصورة: $e');
      return null;
    }
  }

  /// ✅ رفع الصورة إلى ImgBB والحصول على الرابط
  Future<String?> uploadImage(File imageFile) async {
    try {
      print('📤 بدء رفع الصورة إلى ImgBB...');

      // قراءة ملف الصورة
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // إرسال الطلب إلى ImgBB
      final response = await http.post(
        Uri.parse('https://api.imgbb.com/1/upload'),
        body: {
          'key': _apiKey,
          'image': base64Image,
          'name': 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
          'expiration': '0', // 0 = لا تنتهي أبداً
        },
      ).timeout(const Duration(seconds: 30));

      print('📡 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final imageUrl = data['data']['url'];
        print('✅ تم رفع الصورة بنجاح: $imageUrl');
        return imageUrl;
      } else {
        print('❌ فشل رفع الصورة: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ خطأ في رفع الصورة: $e');
      return null;
    }
  }

  /// ✅ عرض الصورة مع كاش (تخزين مؤقت)
  Widget buildCachedImage(String? imageUrl, {double width = 50, double height = 50}) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return CircleAvatar(
        radius: width / 2,
        backgroundColor: Colors.green[50],
        child: Icon(Icons.person, size: width / 2, color: Colors.green),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      imageBuilder: (context, imageProvider) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
        ),
      ),
      placeholder: (context, url) => CircleAvatar(
        radius: width / 2,
        backgroundColor: Colors.grey[200],
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green),
      ),
      errorWidget: (context, url, error) => CircleAvatar(
        radius: width / 2,
        backgroundColor: Colors.green[50],
        child: Icon(Icons.person, size: width / 2, color: Colors.green),
      ),
    );
  }
}