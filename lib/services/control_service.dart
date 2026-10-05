// ============================================================================
// خدمة لوحة التحكم المركزية — ControlService
// ----------------------------------------------------------------------------
// تدير (محلياً عبر Hive + اختيارياً سحابياً عبر Firestore):
//   • حساب مالك النظام (SystemOwner) — واحد فقط.
//   • حسابات المنشآت (CompanyAccount) — إنشاء/تفعيل/إيقاف/صلاحيات.
//   • سجل الأجهزة/التنزيلات (DeviceRegistry).
//   • ربط منشأة معيّنة بمساحة بياناتها (companyId) في المزامنة السحابية.
//
// تصميم موحّد: كل العمليات محصّنة — إن تعذّرت السحابة نكمل محلياً بهدوء.
// ============================================================================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/app_database.dart';
import '../models/control_models.dart';
import 'firebase_config.dart';
import 'security_service.dart';

class ControlService {
  // ---------------------------- أسماء الصناديق ----------------------------
  static const boxCompanies = 'companies'; // حسابات المنشآت
  static const boxSystemOwner = 'system_owner'; // مالك النظام (مفتاح: owner)
  static const boxDevices = 'devices'; // سجل الأجهزة

  static const String _ownerKey = 'owner';
  static const String _activeCompanyKey = 'activeCompanyId';

  static Box get _companies => Hive.box(boxCompanies);
  static Box get _ownerBox => Hive.box(boxSystemOwner);
  static Box get _devices => Hive.box(boxDevices);

  static FirebaseFirestore? get _db {
    if (!FirebaseConfig.isConfigured) return null;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  static bool get isCloudAvailable => _db != null;

  /// تهيئة الصناديق (تُستدعى من main)
  static Future<void> initBoxes() async {
    if (!Hive.isBoxOpen(boxCompanies)) await Hive.openBox(boxCompanies);
    if (!Hive.isBoxOpen(boxSystemOwner)) await Hive.openBox(boxSystemOwner);
    if (!Hive.isBoxOpen(boxDevices)) await Hive.openBox(boxDevices);
  }

  // ==========================================================================
  // ============================ مالك النظام ============================
  // ==========================================================================

  /// هل تم إنشاء حساب مالك النظام؟
  static bool get hasSystemOwner => _ownerBox.get(_ownerKey) != null;

  /// جلب مالك النظام
  static SystemOwner? get systemOwner {
    final m = _ownerBox.get(_ownerKey);
    if (m is Map) return SystemOwner.fromMap(Map<String, dynamic>.from(m));
    return null;
  }

  /// إنشاء حساب مالك النظام الأول (username + password)
  static Future<SystemOwner> createSystemOwner({
    required String name,
    required String username,
    required String password,
    String email = '',
  }) async {
    final cred = SecurityService.createPassword(password);
    final owner = SystemOwner(
      name: name.trim().isEmpty ? 'مالك النظام' : name.trim(),
      username: username.trim(),
      email: email.trim(),
      passwordHash: cred.hash,
      passwordSalt: cred.salt,
    );
    await _ownerBox.put(_ownerKey, owner.toMap());
    _pushSystemOwnerToCloud(owner);
    return owner;
  }

  /// تعديل بيانات مالك النظام
  static Future<void> updateSystemOwner(SystemOwner owner) async {
    await _ownerBox.put(_ownerKey, owner.toMap());
    _pushSystemOwnerToCloud(owner);
  }

  /// تغيير كلمة مرور مالك النظام
  static Future<bool> changeSystemOwnerPassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final owner = systemOwner;
    if (owner == null) return false;
    if (!SecurityService.verify(
        oldPassword, owner.passwordHash, owner.passwordSalt)) {
      return false;
    }
    final cred = SecurityService.createPassword(newPassword);
    final updated = SystemOwner(
      name: owner.name,
      username: owner.username,
      email: owner.email,
      passwordHash: cred.hash,
      passwordSalt: cred.salt,
      mustChangePassword: false,
      createdAt: owner.createdAt,
      lastLoginAt: owner.lastLoginAt,
    );
    await updateSystemOwner(updated);
    return true;
  }

  /// التحقق من بيانات دخول مالك النظام
  static bool verifySystemOwner(String username, String password) {
    final owner = systemOwner;
    if (owner == null) return false;
    if (owner.username.toLowerCase() != username.trim().toLowerCase()) {
      return false;
    }
    return SecurityService.verify(
        password, owner.passwordHash, owner.passwordSalt);
  }

  /// تحديث وقت آخر دخول لمالك النظام
  static Future<void> touchSystemOwnerLogin() async {
    final owner = systemOwner;
    if (owner == null) return;
    final updated = SystemOwner(
      name: owner.name,
      username: owner.username,
      email: owner.email,
      passwordHash: owner.passwordHash,
      passwordSalt: owner.passwordSalt,
      mustChangePassword: owner.mustChangePassword,
      createdAt: owner.createdAt,
      lastLoginAt: DateTime.now().toIso8601String(),
    );
    await _ownerBox.put(_ownerKey, updated.toMap());
  }

  // ==========================================================================
  // ============================ حسابات المنشآت ============================
  // ==========================================================================

  /// كل المنشآت (مرتّبة بالأحدث)
  static List<CompanyAccount> allCompanies() {
    try {
      final list = _companies.values
          .whereType<Map>()
          .map((m) => CompanyAccount.fromMap(Map<String, dynamic>.from(m)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  static CompanyAccount? companyById(String id) {
    final m = _companies.get(id);
    if (m is Map) return CompanyAccount.fromMap(Map<String, dynamic>.from(m));
    return null;
  }

  /// البحث بالبريد أو اسم المستخدم (لتسجيل الدخول)
  static CompanyAccount? companyByLogin(String login) {
    final key = login.trim().toLowerCase();
    if (key.isEmpty) return null;
    for (final c in allCompanies()) {
      if (c.username.toLowerCase() == key ||
          (c.email.isNotEmpty && c.email.toLowerCase() == key)) {
        return c;
      }
    }
    return null;
  }

  static bool get hasCompanies => _companies.isNotEmpty;
  static int get activeCompanyCount =>
      allCompanies().where((c) => c.isActive).length;

  /// إنشاء حساب منشأة جديد (تسجيل من الواجهة الرئيسية)
  static Future<CompanyAccount> createCompany({
    required String companyName,
    required String username,
    required String password,
    String ownerName = '',
    String email = '',
    String phone = '',
    String deviceId = '',
    String createdVia = 'email',
    String appVersion = '1.0.0',
  }) async {
    final id = 'co_${DateTime.now().microsecondsSinceEpoch}';
    final cred = SecurityService.createPassword(password);
    final acc = CompanyAccount(
      id: id,
      companyName: companyName.trim(),
      ownerName: ownerName.trim(),
      username: username.trim(),
      email: email.trim(),
      passwordHash: cred.hash,
      passwordSalt: cred.salt,
      phone: phone.trim(),
      isActive: true,
      plan: CompanyPlan.free,
      privileges: CompanyPrivileges(
        granted: CompanyPrivileges.allKeys.toSet(),
      ),
      deviceId: deviceId,
      createdVia: createdVia,
      appVersion: appVersion,
    );
    await _companies.put(id, acc.toMap());
    _pushCompanyToCloud(acc);
    return acc;
  }

  /// تحديث منشأة
  static Future<void> updateCompany(CompanyAccount acc) async {
    final updated = acc.copyWith(
      updatedAt: DateTime.now().toIso8601String(),
      synced: false,
    );
    await _companies.put(updated.id, updated.toMap());
    _pushCompanyToCloud(updated);
  }

  /// تفعيل/إيقاف منشأة (يتحكم بها مالك النظام)
  static Future<void> setCompanyActive(String id, bool active) async {
    final c = companyById(id);
    if (c == null) return;
    await updateCompany(c.copyWith(isActive: active));
  }

  /// منح/سحب صلاحية واحدة
  static Future<void> togglePrivilege(String id, String key) async {
    final c = companyById(id);
    if (c == null) return;
    final set = c.privileges.granted.toSet();
    if (set.contains(key)) {
      set.remove(key);
    } else {
      set.add(key);
    }
    await updateCompany(
      c.copyWith(privileges: c.privileges.copyWith(granted: set)),
    );
  }

  /// تحديث خطة/امتيازات منشأة بالكامل
  static Future<void> updatePrivileges(
      String id, CompanyPrivileges privileges) async {
    final c = companyById(id);
    if (c == null) return;
    await updateCompany(c.copyWith(privileges: privileges));
  }

  /// تغيير كلمة مرور منشأة (من لوحة مالك النظام)
  static Future<void> resetCompanyPassword(String id, String newPassword) async {
    final c = companyById(id);
    if (c == null) return;
    final cred = SecurityService.createPassword(newPassword);
    await updateCompany(c.copyWith(
      passwordHash: cred.hash,
      passwordSalt: cred.salt,
    ));
  }

  /// حذف منشأة
  static Future<void> deleteCompany(String id) async {
    await _companies.delete(id);
    try {
      await _db?.collection('tenant_registry').doc(id).delete();
    } catch (_) {}
  }

  /// التحقق من دخول منشأة (username/email + password)
  static CompanyAccount? verifyCompanyLogin(String login, String password) {
    final c = companyByLogin(login);
    if (c == null) return null;
    if (!SecurityService.verify(password, c.passwordHash, c.passwordSalt)) {
      return null;
    }
    return c;
  }

  /// تسجيل دخول منشأة: تحديث lastLoginAt + تفعيل مساحتها
  static Future<void> touchCompanyLogin(String id) async {
    final c = companyById(id);
    if (c == null) return;
    await _companies.put(
      id,
      c.copyWith(lastLoginAt: DateTime.now().toIso8601String(),
              synced: false).toMap(),
    );
  }

  // ==========================================================================
  // ============================ المنشأة النشطة ============================
  // ==========================================================================

  /// تحديد المنشأة النشطة الحالية (تُستخدم كـ companyId في المزامنة)
  static Future<void> setActiveCompany(String companyId) async {
    await AppDatabase.setSetting(_activeCompanyKey, companyId);
    await AppDatabase.setSetting('companyId', companyId);
  }

  static String get activeCompanyId =>
      AppDatabase.getSetting(_activeCompanyKey, '');

  /// هل المنشأة النشطة مفعّلة؟ (فحص الأمان عند الدخول)
  static bool get activeCompanyIsEnabled {
    final id = activeCompanyId;
    if (id.isEmpty) return true; // وضع محلي قديم بلا لوحة تحكم
    final c = companyById(id);
    return c?.isActive ?? true;
  }

  // ==========================================================================
  // ============================ سجل الأجهزة ============================
  // ==========================================================================

  static List<DeviceRegistry> allDevices() {
    try {
      final list = _devices.values
          .whereType<Map>()
          .map((m) => DeviceRegistry.fromMap(Map<String, dynamic>.from(m)))
          .toList()
        ..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  static DeviceRegistry? deviceById(String id) {
    final m = _devices.get(id);
    if (m is Map) return DeviceRegistry.fromMap(Map<String, dynamic>.from(m));
    return null;
  }

  /// تسجيل/تحديث جهاز عند كل إقلاع للتطبيق.
  /// يُعيد معرّف الجهاز الحالي.
  static Future<String> registerDevice({
    required String deviceId,
    String platform = '',
    String appVersion = '1.0.0',
    String model = '',
  }) async {
    final existing = deviceById(deviceId);
    final DeviceRegistry dev;
    if (existing == null) {
      dev = DeviceRegistry(
        deviceId: deviceId,
        platform: platform,
        appVersion: appVersion,
        model: model,
        launchCount: 1,
      );
    } else {
      dev = existing.copyWith(
        platform: platform.isEmpty ? existing.platform : platform,
        appVersion: appVersion,
        launchCount: existing.launchCount + 1,
        synced: false,
      );
    }
    await _devices.put(deviceId, dev.toMap());
    _pushDeviceToCloud(dev);
    return deviceId;
  }

  /// ربط الجهاز بمنشأة/مستخدم (يُستدعى بعد الدخول)
  static Future<void> linkDeviceToUser({
    required String deviceId,
    required String companyId,
    required String userId,
    required String userName,
    bool accountCreated = false,
  }) async {
    final dev = deviceById(deviceId);
    if (dev == null) return;
    final updated = dev.copyWith(
      companyId: companyId,
      userId: userId,
      userName: userName,
      accountCreated: accountCreated || dev.accountCreated,
      synced: false,
    );
    await _devices.put(deviceId, updated.toMap());
    _pushDeviceToCloud(updated);
  }

  static Future<void> clearDevices() => _devices.clear();

  // ==========================================================================
  // ============================ السحابة ============================
  // ==========================================================================

  static Future<void> _pushSystemOwnerToCloud(SystemOwner owner) async {
    final db = _db;
    if (db == null) return;
    try {
      await db.collection('app_admin').doc('system_owner').set(
        {
          'name': owner.name,
          'username': owner.username,
          'email': owner.email,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[ControlService] owner push fail: $e');
    }
  }

  static Future<void> _pushCompanyToCloud(CompanyAccount acc) async {
    final db = _db;
    if (db == null) return;
    try {
      await db.collection('tenant_registry').doc(acc.id).set(
        {
          'id': acc.id,
          'companyName': acc.companyName,
          'ownerName': acc.ownerName,
          'username': acc.username,
          'email': acc.email,
          'phone': acc.phone,
          'isActive': acc.isActive,
          'plan': acc.plan.name,
          'privileges': acc.privileges.toMap(),
          'lastLoginAt': acc.lastLoginAt,
          'deviceId': acc.deviceId,
          'createdVia': acc.createdVia,
          'appVersion': acc.appVersion,
          'createdAt': acc.createdAt,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await _companies.put(acc.id, acc.copyWith(synced: true).toMap());
    } catch (e) {
      if (kDebugMode) debugPrint('[ControlService] company push fail: $e');
    }
  }

  static Future<void> _pushDeviceToCloud(DeviceRegistry dev) async {
    final db = _db;
    if (db == null) return;
    try {
      await db.collection('devices').doc(dev.deviceId).set(
        {
          'deviceId': dev.deviceId,
          'platform': dev.platform,
          'appVersion': dev.appVersion,
          'model': dev.model,
          'firstSeenAt': dev.firstSeenAt,
          'lastSeenAt': dev.lastSeenAt,
          'launchCount': dev.launchCount,
          'companyId': dev.companyId,
          'userId': dev.userId,
          'userName': dev.userName,
          'accountCreated': dev.accountCreated,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await _devices.put(dev.deviceId, dev.copyWith(synced: true).toMap());
    } catch (e) {
      if (kDebugMode) debugPrint('[ControlService] device push fail: $e');
    }
  }

  /// جلب كل المنشآت من السحابة (للوحة تحكم مالك النظام)
  static Future<int> pullCompaniesFromCloud() async {
    final db = _db;
    if (db == null) return 0;
    int count = 0;
    try {
      final snap = await db.collection('tenant_registry').get();
      for (final doc in snap.docs) {
        final map = Map<String, dynamic>.from(doc.data());
        map['synced'] = true;
        map.putIfAbsent('id', () => doc.id);
        // نحافظ على hash/salt المحلي إن وُجد (لا نستبدلها من السحابة)
        final local = _companies.get(map['id']);
        if (local is Map) {
          final lm = Map<String, dynamic>.from(local);
          map['passwordHash'] = lm['passwordHash'] ?? '';
          map['passwordSalt'] = lm['passwordSalt'] ?? '';
        }
        await _companies.put(map['id'], map);
        count++;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ControlService] pull companies fail: $e');
    }
    return count;
  }

  static void logStatus() {
    if (kDebugMode) {
      debugPrint('[ControlService] cloud: $isCloudAvailable, '
          'companies: ${_companies.length}, '
          'devices: ${_devices.length}, '
          'owner: $hasSystemOwner');
    }
  }
}
