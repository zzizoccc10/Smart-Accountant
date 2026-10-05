// ============================================================================
// خدمة التشفير — SecurityService
// ----------------------------------------------------------------------------
// تجزئة كلمات المرور باستخدام SHA-256 + ملح عشوائي (salt).
// تُستخدم لمصادقة محلية آمنة (اسم مستخدم + كلمة مرور) دون كشف كلمة المرور.
// ملاحظة: عند تفعيل Firebase Auth يُستخدم أيضاً كطبقة مصادقة ثانية.
// ============================================================================
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class SecurityService {
  static final Random _rnd = Random.secure();

  /// توليد ملح عشوائي (16 بايت → hex)
  static String generateSalt([int bytes = 16]) {
    final data = List<int>.generate(bytes, (_) => _rnd.nextInt(256));
    return data.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// تجزئة كلمة المرور مع الملح (SHA-256) → hex
  static String hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt::$password');
    return sha256.convert(bytes).toString();
  }

  /// إنشاء زوج (hash, salt) لكلمة مرور جديدة
  static ({String hash, String salt}) createPassword(String password) {
    final salt = generateSalt();
    return (hash: hashPassword(password, salt), salt: salt);
  }

  /// التحقق من كلمة المرور مقابل تجزئتها المخزّنة
  static bool verify(String password, String hash, String salt) {
    if (hash.isEmpty || salt.isEmpty) return false;
    return hashPassword(password, salt) == hash;
  }

  /// توليد معرّف جهاز ثابت/عشوائي
  static String newDeviceId() {
    final data = List<int>.generate(12, (_) => _rnd.nextInt(256));
    final part = data.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'dev_$part';
  }

  /// قوة كلمة المرور (0..4)
  static int strength(String password) {
    if (password.isEmpty) return 0;
    int score = 0;
    if (password.length >= 6) score++;
    if (password.length >= 10) score++;
    if (RegExp(r'[A-Za-z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password)) {
      score++;
    }
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;
    return score.clamp(0, 4);
  }

  static String strengthLabel(int score) {
    switch (score) {
      case 0:
        return 'فارغة';
      case 1:
        return 'ضعيفة';
      case 2:
        return 'متوسطة';
      case 3:
        return 'جيدة';
      default:
        return 'قوية';
    }
  }
}
