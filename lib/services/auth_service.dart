// ============================================================================
// خدمة المصادقة — AuthService
// ----------------------------------------------------------------------------
// تدعم وضعين:
//   1) سحابي (Firebase Auth) عند تفعيل Firebase.
//   2) محلي (بدون إنترنت) — مستخدم محلي افتراضي "المالك".
// جميع العمليات تُغلَّف بأمان: إن فشلت السحابة، نكمل محلياً.
// ============================================================================
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import 'firebase_config.dart';

class AuthResult {
  final bool success;
  final String? uid;
  final String? email;
  final String? error;
  const AuthResult({
    required this.success,
    this.uid,
    this.email,
    this.error,
  });
}

class AuthService {
  static fb.FirebaseAuth? get _auth {
    if (!FirebaseConfig.isConfigured) return null;
    try {
      return fb.FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  /// هل المصادقة السحابية متاحة؟
  static bool get isCloudAvailable => _auth != null;

  /// المستخدم الحالي (uid) أو null
  static String? get currentUid {
    try {
      return _auth?.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  static String? get currentEmail {
    try {
      return _auth?.currentUser?.email;
    } catch (_) {
      return null;
    }
  }

  /// تسجيل الدخول بالبريد وكلمة المرور
  static Future<AuthResult> signIn(String email, String password) async {
    final auth = _auth;
    if (auth == null) {
      return const AuthResult(
        success: false,
        error: 'المصادقة السحابية غير مُفعّلة (لم يتم رفع إعدادات Firebase بعد)',
      );
    }
    try {
      final cred = await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return AuthResult(
        success: true,
        uid: cred.user?.uid,
        email: cred.user?.email,
      );
    } on fb.FirebaseAuthException catch (e) {
      return AuthResult(success: false, error: _mapError(e));
    } catch (e) {
      return AuthResult(success: false, error: 'فشل تسجيل الدخول: $e');
    }
  }

  /// إنشاء حساب جديد
  static Future<AuthResult> signUp(String email, String password) async {
    final auth = _auth;
    if (auth == null) {
      return const AuthResult(
        success: false,
        error: 'المصادقة السحابية غير مُفعّلة',
      );
    }
    try {
      final cred = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return AuthResult(
        success: true,
        uid: cred.user?.uid,
        email: cred.user?.email,
      );
    } on fb.FirebaseAuthException catch (e) {
      return AuthResult(success: false, error: _mapError(e));
    } catch (e) {
      return AuthResult(success: false, error: 'فشل إنشاء الحساب: $e');
    }
  }

  /// إرسال رابط إعادة تعيين كلمة المرور
  static Future<AuthResult> sendPasswordReset(String email) async {
    final auth = _auth;
    if (auth == null) {
      return const AuthResult(success: false, error: 'غير مُفعّل');
    }
    try {
      await auth.sendPasswordResetEmail(email: email.trim());
      return const AuthResult(success: true);
    } on fb.FirebaseAuthException catch (e) {
      return AuthResult(success: false, error: _mapError(e));
    }
  }

  /// تسجيل الخروج
  static Future<void> signOut() async {
    try {
      await _auth?.signOut();
    } catch (_) {}
  }

  /// بث تغيّر حالة الدخول
  static Stream<String?> authStateChanges() {
    final auth = _auth;
    if (auth == null) return const Stream.empty();
    return auth.authStateChanges().map((u) => u?.uid);
  }

  /// ترجمة أخطاء Firebase إلى رسائل عربية
  static String _mapError(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'لا يوجد مستخدم بهذا البريد';
      case 'wrong-password':
        return 'كلمة المرور غير صحيحة';
      case 'invalid-email':
        return 'البريد الإلكتروني غير صالح';
      case 'user-disabled':
        return 'هذا الحساب مُعطّل';
      case 'email-already-in-use':
        return 'البريد مستخدم بالفعل';
      case 'weak-password':
        return 'كلمة المرور ضعيفة (6 أحرف على الأقل)';
      case 'too-many-requests':
        return 'محاولات كثيرة — حاول لاحقاً';
      case 'network-request-failed':
        return 'تحقق من اتصال الإنترنت';
      case 'operation-not-allowed':
        return 'طريقة الدخول بالبريد غير مُفعّلة في Firebase Console';
      default:
        return e.message ?? 'خطأ غير معروف (${e.code})';
    }
  }

  /// تسجيل حالة عدم التوفر (للتشخيص)
  static void logStatus() {
    if (kDebugMode) {
      debugPrint('[AuthService] cloud available: $isCloudAvailable');
    }
  }
}
