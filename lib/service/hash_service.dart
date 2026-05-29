import 'dart:convert';
import 'package:crypto/crypto.dart';

class HashService {
  /// ✅ تشفير كلمة المرور باستخدام SHA-256 مع إضافة Salt لتأمينها
  static String hashPassword(String password) {
    const String salt = "chat_app_secure_salt_2026";
    final bytes = utf8.encode(password + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
