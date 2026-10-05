// ============================================================================
// إعدادات Firebase — المحاسب السهل
// ----------------------------------------------------------------------------
// هذا الملف يحتوي على مفاتيح المشروع الحقيقية (مشروع easy-accountant-1acb8).
// تُحدَّث القيم تلقائياً عند تشغيل:  python3 tool/link_firebase.py <json>
//
// ملاحظة معمارية: التطبيق يعمل «محلياً بالكامل» (Offline-First) عبر Hive،
//   ويُفعِّل السحابة تلقائياً عند توفّر مفاتيح المنصّة الصحيحة.
// ============================================================================
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// إعدادات Firebase لمنصات مختلفة.
class FirebaseConfig {
  // -------- Android (مُهيّأ من google-services.json) --------
  static const String androidApiKey = 'AIzaSyDAxvd7thR_bPN2mtehLwYEu7D_sYAkP8c';
  static const String androidAppId = '1:462002399803:android:dfe82af1661b5a16974a1e';
  static const String androidMessagingSenderId = '462002399803';
  static const String androidProjectId = 'easy-accountant-1acb8';
  static const String androidStorageBucket = 'easy-accountant-1acb8.firebasestorage.app';

  // -------- Web (يُملأ بعد إنشاء «تطبيق ويب» في Firebase Console) --------
  static const String webApiKey = '';
  static const String webAppId = '';
  static const String webMessagingSenderId = '';
  static const String webProjectId = '';
  static const String webAuthDomain = '';
  static const String webStorageBucket = '';

  // -------- iOS (يُملأ بعد رفع GoogleService-Info.plist) --------
  static const String iosApiKey = '';
  static const String iosAppId = '';
  static const String iosMessagingSenderId = '';
  static const String iosProjectId = '';
  static const String iosStorageBucket = '';
  static const String iosBundleId = 'com.easyaccountant.erp';

  // --------------------------------------------------------------------------
  // تحقّقات صلاحية الإعداد لكل منصّة (نتجنّب أي معرّف غير مطابق)
  // --------------------------------------------------------------------------
  static bool get androidConfigured =>
      androidApiKey.isNotEmpty &&
      androidProjectId.isNotEmpty &&
      androidAppId.contains(':android:');

  static bool get iosConfigured =>
      iosApiKey.isNotEmpty &&
      iosProjectId.isNotEmpty &&
      iosAppId.contains(':ios:');

  static bool get webConfigured =>
      webApiKey.isNotEmpty &&
      webProjectId.isNotEmpty &&
      webAppId.contains(':web:');

  /// هل السحابة مُهيّأة للمنصّة الحالية؟
  static bool get isConfigured {
    if (kIsWeb) return webConfigured;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return iosConfigured || androidConfigured;
    }
    return androidConfigured;
  }

  /// اسم مشروع Firebase (يُستخدم في مسارات Firestore)
  static String get projectId {
    if (kIsWeb && webProjectId.isNotEmpty) return webProjectId;
    if (androidProjectId.isNotEmpty) return androidProjectId;
    if (iosProjectId.isNotEmpty) return iosProjectId;
    return webProjectId;
  }

  /// خيارات التهيئة حسب المنصّة — تُعيد null إن لم تكن المنصّة مُهيّأة.
  ///
  /// ملاحظة: على أندرويد/iOS يمكن أيضاً استخدام `Firebase.initializeApp()`
  /// بدون خيارات لأنَّ التهيئة تُقرأ من google-services.json / plist، لكننا
  /// نمرّل الخيارات صراحةً لتوحيد السلوك ودعم الويب.
  static FirebaseOptions? get currentPlatformOptions {
    if (kIsWeb) {
      if (!webConfigured) return null;
      return FirebaseOptions(
        apiKey: webApiKey,
        appId: webAppId,
        messagingSenderId: webMessagingSenderId,
        projectId: webProjectId,
        authDomain: webAuthDomain.isEmpty
            ? '$webProjectId.firebaseapp.com'
            : webAuthDomain,
        storageBucket: webStorageBucket,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS && iosConfigured) {
      return FirebaseOptions(
        apiKey: iosApiKey,
        appId: iosAppId,
        messagingSenderId: iosMessagingSenderId,
        projectId: iosProjectId,
        storageBucket: iosStorageBucket,
        iosBundleId: iosBundleId,
      );
    }
    if (androidConfigured) {
      return FirebaseOptions(
        apiKey: androidApiKey,
        appId: androidAppId,
        messagingSenderId: androidMessagingSenderId,
        projectId: androidProjectId,
        storageBucket: androidStorageBucket,
      );
    }
    return null;
  }
}
