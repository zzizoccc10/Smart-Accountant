// ============================================================================
// خدمة الإشعارات المحلية — LocalNotifications
// إشعارات فورية: نقص مخزون، فواتير مستحقة، مديونية، نسخ احتياطي
// ============================================================================
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotifications {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _inited = false;

  static const _channelId = 'easy_accountant_main';
  static const _channelName = 'تنبيهات المحاسب السهل';
  static const _channelDesc = 'تنبيهات نقص المخزون والديون والفواتير المستحقة';

  /// تهيئة قناة الإشعارات (تُستدعى مرة عند بدء التطبيق)
  static Future<void> init() async {
    if (kIsWeb || _inited) return;
    try {
      const androidInit =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
      );

      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (_) {},
      );

      final androidImpl =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.high,
        ),
      );
      _inited = true;
    } catch (_) {
      // تجاهل الأخطاء على المنصات غير المدعومة
    }
  }

  static bool _permRequested = false;

  /// طلب صلاحية الإشعارات عند الحاجة فقط (أول إشعار فعلي)
  static Future<void> _ensurePermission() async {
    if (kIsWeb || _permRequested) return;
    _permRequested = true;
    try {
      final androidImpl =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
      final iosImpl = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await iosImpl?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
    macOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  /// إظهار إشعار
  static Future<void> show(int id, String title, String body) async {
    if (kIsWeb) return;
    if (!_inited) await init();
    await _ensurePermission();
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _details,
      );
    } catch (_) {}
  }

  // ============================ إشعارات جاهزة ============================

  /// تنبيه نقص مخزون
  static Future<void> lowStock(String itemName, double qty, double reorder) =>
      show(
        1001,
        'نقص في المخزون',
        'الصنف "$itemName" وصل للحد الأدنى (المتاح: $qty، حد الطلب: $reorder)',
      );

  /// تنبيه فاتورة مستحقة
  static Future<void> invoiceDue(String invoiceNumber, String contact,
          double remaining, String currency) =>
      show(
        1002,
        'فاتورة مستحقة السداد',
        'الفاتورة $invoiceNumber للعميل "$contact" — المتبقي: $remaining $currency',
      );

  /// تنبيه مديونية تجاوزت حد الائتمان
  static Future<void> creditLimitExceeded(
          String contact, double balance, double limit) =>
      show(
        1003,
        'تجاوز حد الائتمان',
        'العميل "$contact" تجاوز حد الائتمان (الرصيد: $balance، الحد: $limit)',
      );

  /// تنبيه نجاح النسخ الاحتياطي
  static Future<void> backupDone(String message) =>
      show(1004, 'نسخة احتياطية', message);
}
