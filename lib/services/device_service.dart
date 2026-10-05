// ============================================================================
// خدمة الجهاز — DeviceService
// ----------------------------------------------------------------------------
// تُنشئ معرّفاً فريداً ثابتاً للجهاز، وتتتبّع كل جهاز حَمّل التطبيق:
//   • نوع الهاتف (الشركة + الطراز) + إصدار النظام.
//   • البلد (من رمز الدولة للجهاز / لغة النظام).
//   • سجلات الزوار (دخول بدون حساب) وحسابات Google.
// ============================================================================
import 'dart:ui' as ui;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'control_service.dart';
import 'security_service.dart';

class DeviceService {
  static const boxSettings = 'device_meta';
  static const _kDeviceId = 'deviceId';

  static Box? _box;

  // بيانات الجهاز الحالي (تُملأ في init)
  static String _platform = '';
  static String _model = '';
  static String _brand = '';
  static String _osVersion = '';
  static String _country = '';
  static String _countryCode = '';

  static String get platform => _platform;
  static String get model => _model;
  static String get brand => _brand;
  static String get osVersion => _osVersion;
  static String get country => _country;
  static String get countryCode => _countryCode;

  /// معرّف الجهاز الحالي
  static String get deviceId {
    try {
      if (_box == null) return 'dev_unknown';
      final id = _box!.get(_kDeviceId);
      if (id is String && id.isNotEmpty) return id;
      return 'dev_unknown';
    } catch (_) {
      return 'dev_unknown';
    }
  }

  /// تهيئة الخدمة وجمع بيانات الجهاز + تسجيله
  static Future<void> init({String appVersion = '1.0.0'}) async {
    try {
      if (!Hive.isBoxOpen(boxSettings)) {
        _box = await Hive.openBox(boxSettings);
      } else {
        _box = Hive.box(boxSettings);
      }
      var id = _box!.get(_kDeviceId);
      if (id is! String || id.isEmpty) {
        id = SecurityService.newDeviceId();
        await _box!.put(_kDeviceId, id);
      }

      await _collectDeviceInfo();

      await ControlService.registerDevice(
        deviceId: id,
        platform: _platform,
        appVersion: appVersion,
        model: _model,
        brand: _brand,
        osVersion: _osVersion,
        country: _country,
        countryCode: _countryCode,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[DeviceService] init failed: $e');
    }
  }

  /// جمع معلومات الجهاز (نوع الهاتف + النظام + البلد)
  static Future<void> _collectDeviceInfo() async {
    try {
      if (kIsWeb) {
        _platform = 'web';
        final info = DeviceInfoPlugin();
        try {
          final w = await info.webBrowserInfo;
          _webInfo = w;
          _brand = w.browserName.name.toUpperCase();
          _model = w.browserName.name;
          _osVersion = w.platform ?? '';
        } catch (_) {
          _brand = _detectBrowser();
          _model = 'Web Browser';
          _osVersion = '';
        }
      } else {
        final info = DeviceInfoPlugin();
        if (defaultTargetPlatform == TargetPlatform.android) {
          final a = await info.androidInfo;
          _platform = 'android';
          _brand = _cap(a.manufacturer);
          _model = a.model;
          _osVersion = 'Android ${a.version.release}';
        } else if (defaultTargetPlatform == TargetPlatform.iOS) {
          final i = await info.iosInfo;
          _platform = 'ios';
          _brand = 'Apple';
          _model = i.utsname.machine;
          _osVersion = '${i.systemName} ${i.systemVersion}';
        } else {
          _platform = defaultTargetPlatform.name;
          _model = _platform;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[DeviceService] info failed: $e');
      _platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
    }

    // البلد من لغة/إعداد النظام
    _detectCountry();
  }

  /// اسم المتصفح على الويب (best-effort من معلومات الجهاز)
  static String _detectBrowser() {
    if (!kIsWeb) return '';
    try {
      final info = _webInfo;
      if (info == null) return 'Browser';
      final ua = info.userAgent;
      if (ua.contains('Edg')) return 'Edge';
      if (ua.contains('OPR') || ua.contains('Opera')) return 'Opera';
      if (ua.contains('Chrome')) return 'Chrome';
      if (ua.contains('Firefox')) return 'Firefox';
      if (ua.contains('Safari')) return 'Safari';
      return 'Browser';
    } catch (_) {
      return 'Browser';
    }
  }

  /// معلومات المتصفح على الويب (تُملأ في _collectDeviceInfo)
  static dynamic _webInfo;

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// تحديد البلد من locale النظام (best-effort محلي بلا إنترنت)
  static void _detectCountry() {
    try {
      final locales = ui.PlatformDispatcher.instance.locales;
      final loc = locales.isNotEmpty ? locales.first : const ui.Locale('ar', 'EG');
      _countryCode = (loc.countryCode ?? '').toUpperCase();
      _country = _countryNameAr(_countryCode) ?? (_countryCode.isEmpty ? 'غير معروف' : _countryCode);
    } catch (_) {
      _countryCode = '';
      _country = 'غير معروف';
    }
  }

  /// خريطة أسماء الدول العربية الشائعة
  static const Map<String, String> _countryNames = {
    'YE': 'اليمن',
    'SA': 'السعودية',
    'AE': 'الإمارات',
    'EG': 'مصر',
    'OM': 'عُمان',
    'QA': 'قطر',
    'KW': 'الكويت',
    'BH': 'البحرين',
    'JO': 'الأردن',
    'IQ': 'العراق',
    'SY': 'سوريا',
    'LB': 'لبنان',
    'PS': 'فلسطين',
    'SD': 'السودان',
    'LY': 'ليبيا',
    'TN': 'تونس',
    'DZ': 'الجزائر',
    'MA': 'المغرب',
    'MR': 'موريتانيا',
    'SO': 'الصومال',
    'DJ': 'جيبوتي',
    'KM': 'جزر القمر',
    'TR': 'تركيا',
    'US': 'الولايات المتحدة',
    'GB': 'المملكة المتحدة',
    'IN': 'الهند',
  };

  static String? _countryNameAr(String code) => _countryNames[code.toUpperCase()];

  /// تحديث بيانات البلد (يُستدعى من الواجهة إن أردنا قراءة locale الحقيقي)
  static Future<void> setLocaleCountry(String code) async {
    _countryCode = code.toUpperCase();
    _country = _countryNameAr(_countryCode) ?? _countryCode;
    await ControlService.updateDeviceInfo(
      deviceId: deviceId,
      country: _country,
      countryCode: _countryCode,
    );
  }

  /// ربط الجهاز بمستخدم/منشأة بعد الدخول
  static Future<void> linkUser({
    required String companyId,
    required String userId,
    required String userName,
  }) async {
    try {
      await ControlService.linkDeviceToUser(
        deviceId: deviceId,
        companyId: companyId,
        userId: userId,
        userName: userName,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[DeviceService] linkUser failed: $e');
    }
  }

  /// تعليم أن هذا الجهاز أنشأ حساباً
  static Future<void> markAccountCreated(
      String companyId, String userName) async {
    try {
      await ControlService.linkDeviceToUser(
        deviceId: deviceId,
        companyId: companyId,
        userId: '',
        userName: userName,
        accountCreated: true,
      );
      // إن كان زائراً سابقاً، علّم أنه تحوّل لحساب
      await ControlService.markGuestConverted(deviceId, companyId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DeviceService] markAccountCreated failed: $e');
      }
    }
  }

  /// تسجيل دخول زائر
  static Future<void> recordGuestVisit() async {
    try {
      await ControlService.registerGuest(
        deviceId: deviceId,
        platform: _platform,
        model: deviceLabel(),
        country: _country,
        countryCode: _countryCode,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[DeviceService] guest visit failed: $e');
    }
  }

  /// تسجيل دخول Google
  static Future<void> recordGoogleLogin({
    required String uid,
    required String email,
    String displayName = '',
    String photoUrl = '',
    String companyId = '',
  }) async {
    try {
      await ControlService.registerGoogleAccount(
        id: uid.isNotEmpty ? uid : email,
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
        deviceId: deviceId,
        platform: _platform,
        model: deviceLabel(),
        country: _country,
        countryCode: _countryCode,
        companyId: companyId,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[DeviceService] google login failed: $e');
    }
  }

  /// وصف مختصر للجهاز
  static String deviceLabel() {
    if (_brand.isEmpty && _model.isEmpty) return _platform;
    if (_brand.isEmpty) return _model;
    if (_model.isEmpty) return _brand;
    return '$_brand $_model';
  }
}
