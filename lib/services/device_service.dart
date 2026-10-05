// ============================================================================
// خدمة الجهاز — DeviceService
// ----------------------------------------------------------------------------
// تُنشئ معرّفاً فريداً ثابتاً للجهاز، وتتتبّع كل جهاز حَمّل التطبيق.
// تُخزَّن محلياً (shared_preferences / Hive) وترتبط بـ ControlService.DeviceRegistry.
// ============================================================================
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'control_service.dart';
import 'security_service.dart';

class DeviceService {
  static const boxSettings = 'device_meta';
  static const _kDeviceId = 'deviceId';

  static Box? _box;

  /// معرّف الجهاز الحالي (يُنشأ مرة واحدة ويثبت)
  static String get deviceId {
    try {
      if (_box == null) return _fallbackId();
      final id = _box!.get(_kDeviceId);
      if (id is String && id.isNotEmpty) return id;
      return _fallbackId();
    } catch (_) {
      return _fallbackId();
    }
  }

  static String _fallbackId() => 'dev_unknown';

  /// تهيئة الخدمة وتسجيل الجهاز (تُستدعى من main)
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
      await ControlService.registerDevice(
        deviceId: id,
        platform: _platform(),
        appVersion: appVersion,
        model: _model(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[DeviceService] init failed: $e');
    }
  }

  static String _platform() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.linux:
        return 'linux';
      default:
        return 'unknown';
    }
  }

  static String _model() {
    if (kIsWeb) return 'Web Browser';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android Device';
      case TargetPlatform.iOS:
        return 'iOS Device';
      default:
        return _platform();
    }
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
    } catch (e) {
      if (kDebugMode) debugPrint('[DeviceService] markAccountCreated failed: $e');
    }
  }
}
