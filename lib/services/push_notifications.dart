// ============================================================================
// خدمة الإشعارات السحابية — PushNotifications (FCM)
// ----------------------------------------------------------------------------
// • تسجيل الجهاز للحصول على رمز FCM.
// • استقبال الإشعارات (Foreground / Background / عند الفتح).
// • الاشتراك في مواضيع (topics) حسب الدور/الفرع.
// محصّنة بالكامل: إن لم تكن السحابة مُفعّلة أو على الويب => تتجاهل بهدوء.
// ============================================================================
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'firebase_config.dart';
import 'user_service.dart';

/// معالج الرسائل في الخلفية (يجب أن يكون دالة عليا)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    debugPrint('[FCM] background message: ${message.messageId}');
  }
}

class PushNotifications {
  static FirebaseMessaging? get _fcm {
    if (!FirebaseConfig.isConfigured) return null;
    if (kIsWeb) return null; // Web يحتاج service worker خاص
    try {
      return FirebaseMessaging.instance;
    } catch (_) {
      return null;
    }
  }

  static bool get isAvailable => _fcm != null;

  /// الرمز الحالي للجهاز
  static String? _token;
  static String? get token => _token;

  /// دالة تُستدعى عند وصول إشعار في المقدمة (لعرض SnackBar مثلاً)
  static void Function(RemoteMessage message)? onForegroundMessage;
  static void Function(RemoteMessage message)? onNotificationTap;

  /// تهيئة الإشعارات السحابية
  static Future<void> init({String? userId}) async {
    final fcm = _fcm;
    if (fcm == null) {
      if (kDebugMode) debugPrint('[FCM] not available (not configured/web)');
      return;
    }
    try {
      // طلب الإذن (iOS + Android 13+)
      final settings = await fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (kDebugMode) {
        debugPrint('[FCM] permission: ${settings.authorizationStatus}');
      }

      // الرمز
      _token = await fcm.getToken();
      if (kDebugMode) debugPrint('[FCM] token: $_token');

      // تحديث الرمز تلقائياً
      fcm.onTokenRefresh.listen((newToken) {
        _token = newToken;
        if (userId != null) {
          UserService.updateFcmToken(userId, newToken);
        }
      });

      // إشعار في المقدمة
      FirebaseMessaging.onMessage.listen((msg) {
        if (kDebugMode) {
          debugPrint('[FCM] foreground: ${msg.notification?.title}');
        }
        onForegroundMessage?.call(msg);
      });

      // فتح التطبيق من إشعار في الخلفية
      FirebaseMessaging.onMessageOpenedApp.listen((msg) {
        onNotificationTap?.call(msg);
      });

      // فتح التطبيق من إشعار مغلق تماماً
      final initial = await fcm.getInitialMessage();
      if (initial != null) onNotificationTap?.call(initial);

      // الاشتراك في الموضوع العام
      await fcm.subscribeToTopic('all_users');
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] init error: $e');
    }
  }

  /// الاشتراك في موضوع (topic) — مثل: branch_xxx أو role_accountant
  static Future<void> subscribe(String topic) async {
    try {
      await _fcm?.subscribeToTopic(topic);
    } catch (_) {}
  }

  static Future<void> unsubscribe(String topic) async {
    try {
      await _fcm?.unsubscribeFromTopic(topic);
    } catch (_) {}
  }

  static void logStatus() {
    if (kDebugMode) debugPrint('[FCM] available: $isAvailable, token: $_token');
  }
}
