// ============================================================================
// خدمة الصلاحيات — طلب وإدارة أذونات أندرويد وقت التشغيل
// جهات الاتصال / التخزين / الهاتف وواتساب / رسائل SMS / الكاميرا
// ============================================================================
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// الصلاحيات التي يحتاجها التطبيق بشكل أساسي
  static const List<Permission> corePermissions = [
    Permission.contacts, // جهات الاتصال
    Permission.storage, // التخزين الداخلي
    Permission.phone, // الهاتف (للاتصال)
    Permission.sms, // رسائل SMS
    Permission.camera, // الكاميرا
  ];

  /// طلب كل الصلاحيات الأساسية دفعة واحدة
  /// ترجع خريطة: الصلاحية -> هل مُنحت
  static Future<Map<Permission, PermissionStatus>> requestCore() async {
    if (kIsWeb) {
      return {for (final p in corePermissions) p: PermissionStatus.granted};
    }
    try {
      final result = await corePermissions.request();
      return result;
    } catch (_) {
      return {for (final p in corePermissions) p: PermissionStatus.denied};
    }
  }

  /// حالة صلاحية واحدة
  static Future<PermissionStatus> status(Permission p) async {
    if (kIsWeb) return PermissionStatus.granted;
    try {
      return await p.status;
    } catch (_) {
      return PermissionStatus.denied;
    }
  }

  /// طلب صلاحية واحدة
  static Future<PermissionStatus> request(Permission p) async {
    if (kIsWeb) return PermissionStatus.granted;
    try {
      return await p.request();
    } catch (_) {
      return PermissionStatus.denied;
    }
  }

  /// فتح إعدادات التطبيق (لمنح الصلاحيات يدوياً عند الرفض الدائم)
  static Future<bool> openSettings() async {
    if (kIsWeb) return false;
    return openAppSettings();
  }

  /// خريطة حالة كل الصلاحيات الأساسية
  static Future<Map<Permission, PermissionStatus>> statusMap() async {
    final map = <Permission, PermissionStatus>{};
    for (final p in corePermissions) {
      map[p] = await status(p);
    }
    return map;
  }

  /// هل كل الصلاحيات الأساسية مُنحت؟
  static Future<bool> allGranted() async {
    final map = await statusMap();
    return map.values.every((s) => s.isGranted);
  }

  /// اسم عربي مختصر لكل صلاحية
  static String label(Permission p) {
    if (p == Permission.contacts) return 'جهات الاتصال';
    if (p == Permission.storage) return 'وحدة التخزين';
    if (p == Permission.phone) return 'الهاتف / واتساب';
    if (p == Permission.sms) return 'رسائل SMS';
    if (p == Permission.camera) return 'الكاميرا';
    return p.toString();
  }

  /// وصف الاستخدام
  static String usage(Permission p) {
    if (p == Permission.contacts) {
      return 'لإضافة العملاء والموردين من دفتر الهاتف مباشرة';
    }
    if (p == Permission.storage) {
      return 'لحفظ الفواتير والتقارير والنسخ الاحتياطية';
    }
    if (p == Permission.phone) {
      return 'للاتصال بالعميل أو فتح واتساب لإرسال الفاتورة';
    }
    if (p == Permission.sms) {
      return 'لإرسال تفاصيل الفاتورة والسند عبر رسالة نصية';
    }
    if (p == Permission.camera) {
      return 'لتصوير المستندات ومسح الباركود';
    }
    return '';
  }

  /// نص حالة الصلاحية بالعربية
  static String statusLabel(PermissionStatus s) {
    if (s.isGranted) return 'مسموح';
    if (s.isPermanentlyDenied) return 'مرفوض نهائياً';
    if (s.isRestricted) return 'مقيّد';
    if (s.isLimited) return 'محدود';
    return 'غير مسموح';
  }
}
