// ============================================================================
// إعدادات Firebase — المحاسب السهل
// ----------------------------------------------------------------------------
// ⚠️ مهم: هذا الملف يحتوي على مفاتيح المشروع. عند رفع google-services.json
//    سنُحدّث هذه القيم تلقائياً. حالياً القيم فارغة => يعمل التطبيق محلياً
//    بالكامل (Offline-First) دون أي خطأ.
// ============================================================================

/// إعدادات Firebase لمنصات مختلفة.
/// تُقرأ القيم من ملف google-services.json / GoogleService-Info.plist بعد رفعها.
class FirebaseConfig {
  // -------- Android --------
  static const String androidApiKey = '';
  static const String androidAppId = '';
  static const String androidMessagingSenderId = '';
  static const String androidProjectId = '';

  // -------- Web --------
  static const String webApiKey = '';
  static const String webAppId = '';
  static const String webMessagingSenderId = '';
  static const String webProjectId = '';
  static const String webAuthDomain = '';
  static const String webStorageBucket = '';
  static const String webMeasurementId = '';

  // -------- iOS --------
  static const String iosApiKey = '';
  static const String iosAppId = '';
  static const String iosMessagingSenderId = '';
  static const String iosProjectId = '';
  static const String iosStorageBucket = '';
  static const String iosBundleId = 'com.easyaccountant.erp';

  /// هل تم إعداد مفاتيح Firebase؟ (يُتحقق منه لتشغيل/إيقاف السحابة)
  static bool get isConfigured {
    // يكفي وجود المفاتيح الأساسية للوحة (Android + Web)
    final hasAndroid = androidApiKey.isNotEmpty &&
        androidAppId.isNotEmpty &&
        androidProjectId.isNotEmpty;
    final hasWeb = webApiKey.isNotEmpty &&
        webAppId.isNotEmpty &&
        webProjectId.isNotEmpty;
    return hasAndroid || hasWeb;
  }

  /// اسم مشروع Firebase (يُستخدم في مسارات Firestore)
  static String get projectId {
    if (webProjectId.isNotEmpty) return webProjectId;
    if (androidProjectId.isNotEmpty) return androidProjectId;
    return iosProjectId;
  }
}
