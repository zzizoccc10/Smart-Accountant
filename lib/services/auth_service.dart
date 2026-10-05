// ============================================================================
// خدمة المصادقة — AuthService
// ----------------------------------------------------------------------------
// طبقة موحّدة فوق Firebase Auth (عند توفّر السحابة) مع دعم كامل للعمل المحلي.
// تُستخدم لكل من: مالك النظام، أصحاب المنشآت، المستخدمين، والزوار.
//
// الميزات:
//   • دخول/إنشاء بالبريد وكلمة المرور.
//   • الدخول عبر Google (Web: popup، Android/iOS: google_sign_in).
//   • إعادة تعيين كلمة المرور عبر البريد.
//   • الدخول المجهول (Anonymous) لتأمين الكتابة السحابية.
//   • كل العمليات محصّنة — لا تُسقط التطبيق إن فشلت.
// ============================================================================
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import 'firebase_config.dart';

/// نتيجة عملية مصادقة
class AuthResult {
  final bool success;
  final String? uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? error;

  const AuthResult({
    required this.success,
    this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.error,
  });

  static const AuthResult disabled = AuthResult(
    success: false,
    error: 'المصادقة السحابية غير مُفعّلة — سيتم الدخول محلياً',
  );
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

  static bool get isCloudAvailable => _auth != null;

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

  static String? get currentPhotoUrl {
    try {
      return _auth?.currentUser?.photoURL;
    } catch (_) {
      return null;
    }
  }

  // ==========================================================================
  // ============================ البريد وكلمة المرور ============================
  // ==========================================================================

  /// تسجيل الدخول بالبريد وكلمة المرور
  static Future<AuthResult> signIn(String email, String password) async {
    final auth = _auth;
    if (auth == null) return AuthResult.disabled;
    try {
      final cred = await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return AuthResult(
        success: true,
        uid: cred.user?.uid,
        email: cred.user?.email,
        displayName: cred.user?.displayName,
      );
    } on fb.FirebaseAuthException catch (e) {
      return AuthResult(success: false, error: mapError(e));
    } catch (e) {
      return AuthResult(success: false, error: 'فشل تسجيل الدخول: $e');
    }
  }

  /// إنشاء حساب جديد بالبريد وكلمة المرور
  static Future<AuthResult> signUp(
    String email,
    String password, {
    String? displayName,
  }) async {
    final auth = _auth;
    if (auth == null) return AuthResult.disabled;
    try {
      final cred = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (displayName != null && displayName.trim().isNotEmpty) {
        try {
          await cred.user?.updateDisplayName(displayName.trim());
        } catch (_) {}
      }
      return AuthResult(
        success: true,
        uid: cred.user?.uid,
        email: cred.user?.email,
        displayName: displayName,
      );
    } on fb.FirebaseAuthException catch (e) {
      return AuthResult(success: false, error: mapError(e));
    } catch (e) {
      return AuthResult(success: false, error: 'فشل إنشاء الحساب: $e');
    }
  }

  /// إرسال رابط إعادة تعيين كلمة المرور
  static Future<AuthResult> sendPasswordReset(String email) async {
    final auth = _auth;
    if (auth == null) {
      return const AuthResult(
        success: false,
        error: 'إعادة التعيين عبر البريد تحتاج تفعيل السحابة',
      );
    }
    try {
      await auth.sendPasswordResetEmail(email: email.trim());
      return const AuthResult(success: true);
    } on fb.FirebaseAuthException catch (e) {
      return AuthResult(success: false, error: mapError(e));
    } catch (e) {
      return AuthResult(success: false, error: 'تعذّر الإرسال: $e');
    }
  }

  /// تغيير كلمة مرور المستخدم الحالي (يحتاج إعادة مصادقة آمنة)
  static Future<AuthResult> updatePassword(String newPassword) async {
    final auth = _auth;
    final u = auth?.currentUser;
    if (auth == null || u == null) return AuthResult.disabled;
    try {
      await u.updatePassword(newPassword);
      return const AuthResult(success: true);
    } on fb.FirebaseAuthException catch (e) {
      return AuthResult(success: false, error: mapError(e));
    } catch (e) {
      return AuthResult(success: false, error: 'تعذّر تغيير كلمة المرور: $e');
    }
  }

  // ==========================================================================
  // ============================ الدخول عبر Google ============================
  // ==========================================================================

  /// تسجيل الدخول عبر Google.
  /// • الويب: يستخدم signInWithPopup من firebase_auth.
  /// • Android/iOS: يتطلّب تهيئة OAuth (SHA-1 + client id) — يُتخطّى بهدوء إن لم تُهيّأ.
  static Future<AuthResult> signInWithGoogle() async {
    final auth = _auth;
    if (auth == null) {
      return const AuthResult(
        success: false,
        error: 'الدخول عبر Google يحتاج تفعيل السحابة',
      );
    }
    try {
      if (kIsWeb) {
        final provider = fb.GoogleAuthProvider();
        provider.setCustomParameters({'prompt': 'select_account'});
        final cred = await auth.signInWithPopup(provider);
        return AuthResult(
          success: true,
          uid: cred.user?.uid,
          email: cred.user?.email,
          displayName: cred.user?.displayName,
          photoUrl: cred.user?.photoURL,
        );
      }
      // المنصّات الأصلية تتطلّب google_sign_in + تهيئة OAuth في Console.
      return const AuthResult(
        success: false,
        error: 'الدخول عبر Google على الجوال يحتاج تهيئة OAuth في Firebase Console',
      );
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'operation-not-allowed') {
        return const AuthResult(
          success: false,
          error: 'يجب تفعيل مزوّد Google من Firebase Console أولاً',
        );
      }
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        return const AuthResult(success: false, error: 'أُلغي الدخول');
      }
      return AuthResult(success: false, error: mapError(e));
    } catch (e) {
      return AuthResult(success: false, error: 'تعذّر الدخول عبر Google: $e');
    }
  }

  // ==========================================================================
  // ============================ الدخول المجهول ============================
  // ==========================================================================

  /// تسجيل دخول مجهول (Anonymous) — لتأمين الكتابة في Firestore دون حساب.
  static Future<bool> ensureSignedIn() async {
    final auth = _auth;
    if (auth == null) return false;
    try {
      if (auth.currentUser != null) return true;
      await auth.signInAnonymously();
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthService] anonymous sign-in skipped: $e');
      }
      return false;
    }
  }

  // ==========================================================================
  // ============================ الخروج والحالة ============================
  // ==========================================================================

  static Future<void> signOut() async {
    try {
      await _auth?.signOut();
    } catch (_) {}
  }

  static Stream<String?> authStateChanges() {
    final auth = _auth;
    if (auth == null) return const Stream.empty();
    return auth.authStateChanges().map((u) => u?.uid);
  }

  /// ترجمة أخطاء Firebase إلى رسائل عربية
  static String mapError(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'لا يوجد مستخدم بهذا البريد';
      case 'wrong-password':
      case 'invalid-credential':
        return 'بيانات الدخول غير صحيحة';
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
        return 'طريقة الدخول هذه غير مُفعّلة في Firebase Console';
      case 'requires-recent-login':
        return 'أعد تسجيل الدخول ثم حاول مجدداً';
      default:
        return e.message ?? 'خطأ غير معروف (${e.code})';
    }
  }

  static void logStatus() {
    if (kDebugMode) {
      debugPrint('[AuthService] cloud available: $isCloudAvailable');
    }
  }
}
