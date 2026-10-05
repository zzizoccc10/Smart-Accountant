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
import 'device_service.dart';
import 'firebase_config.dart';
import 'security_service.dart';

class ControlService {
  // ---------------------------- أسماء الصناديق ----------------------------
  static const boxCompanies = 'companies'; // حسابات المنشآت
  static const boxSystemOwner = 'system_owner'; // مالك النظام (مفتاح: owner)
  static const boxDevices = 'devices'; // سجل الأجهزة
  static const boxGuests = 'guest_accounts'; // الزوار (دخول بدون حساب)
  static const boxGoogle = 'google_accounts'; // حسابات Google
  static const boxOwnerConfig = 'owner_config'; // إعدادات/صلاحيات لوحة المالك

  static const String _ownerKey = 'owner';
  static const String _ownerConfigKey = 'config';
  static const String _activeCompanyKey = 'activeCompanyId';

  static Box get _companies => Hive.box(boxCompanies);
  static Box get _ownerBox => Hive.box(boxSystemOwner);
  static Box get _devices => Hive.box(boxDevices);
  static Box get _guests => Hive.box(boxGuests);
  static Box get _google => Hive.box(boxGoogle);
  static Box get _ownerCfg => Hive.box(boxOwnerConfig);

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
    if (!Hive.isBoxOpen(boxGuests)) await Hive.openBox(boxGuests);
    if (!Hive.isBoxOpen(boxGoogle)) await Hive.openBox(boxGoogle);
    if (!Hive.isBoxOpen(boxOwnerConfig)) await Hive.openBox(boxOwnerConfig);
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

  /// إنشاء حساب مالك النظام الأول (username + password).
  /// يُسمح بالإنشاء مرة واحدة فقط — ما لم يُسمح بإعادة الإنشاء صراحةً.
  static Future<SystemOwner> createSystemOwner({
    required String name,
    required String username,
    required String password,
    String email = '',
    bool force = false,
  }) async {
    if (hasSystemOwner && !force) {
      return systemOwner!;
    }
    final cred = SecurityService.createPassword(password);
    final owner = SystemOwner(
      name: name.trim().isEmpty ? 'مالك النظام' : name.trim(),
      username: username.trim(),
      email: email.trim(),
      passwordHash: cred.hash,
      passwordSalt: cred.salt,
    );
    await _ownerBox.put(_ownerKey, owner.toMap());
    // سجّل الجهاز الأول الذي أنشأ حساب المالك (المصرّح له)
    final cfg = ownerConfig;
    await _saveOwnerConfig(cfg.copyWith(ownerDeviceId: DeviceService.deviceId));
    _pushSystemOwnerToCloud(owner);
    _pushOwnerConfigToCloud(ownerConfig);
    return owner;
  }

  /// تعديل بيانات مالك النظام (اسم/بريد)
  static Future<void> updateSystemOwner(SystemOwner owner) async {
    await _ownerBox.put(_ownerKey, owner.toMap());
    _pushSystemOwnerToCloud(owner);
  }

  /// تعديل اسم مستخدم مالك النظام (مع التحقق من عدم التكرار)
  static Future<bool> changeSystemOwnerUsername(String newUsername) async {
    final owner = systemOwner;
    if (owner == null) return false;
    final u = newUsername.trim();
    if (u.length < 3) return false;
    final updated = SystemOwner(
      name: owner.name,
      username: u,
      email: owner.email,
      passwordHash: owner.passwordHash,
      passwordSalt: owner.passwordSalt,
      mustChangePassword: owner.mustChangePassword,
      createdAt: owner.createdAt,
      lastLoginAt: owner.lastLoginAt,
    );
    await updateSystemOwner(updated);
    return true;
  }

  /// تحديث الاسم/البريد لمالك النظام
  static Future<void> updateSystemOwnerProfile({
    String? name,
    String? email,
  }) async {
    final owner = systemOwner;
    if (owner == null) return;
    final updated = SystemOwner(
      name: (name ?? owner.name).trim().isEmpty ? owner.name : name!.trim(),
      username: owner.username,
      email: (email ?? owner.email).trim(),
      passwordHash: owner.passwordHash,
      passwordSalt: owner.passwordSalt,
      mustChangePassword: owner.mustChangePassword,
      createdAt: owner.createdAt,
      lastLoginAt: owner.lastLoginAt,
    );
    await updateSystemOwner(updated);
  }

  /// تغيير كلمة مرور مالك النظام
  static Future<bool> changeSystemOwnerPassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final owner = systemOwner;
    if (owner == null) return false;
    if (!SecurityService.verify(
      oldPassword,
      owner.passwordHash,
      owner.passwordSalt,
    )) {
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
      password,
      owner.passwordHash,
      owner.passwordSalt,
    );
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
  // ====================== إعدادات/صلاحيات لوحة المالك ======================
  // ==========================================================================

  /// إعدادات الوصول إلى لوحة المالك (محلياً).
  static OwnerConfig get ownerConfig {
    final m = _ownerCfg.get(_ownerConfigKey);
    if (m is Map) return OwnerConfig.fromMap(Map<String, dynamic>.from(m));
    return OwnerConfig();
  }

  /// هل هذا الجهاز هو «الجهاز الأول» الذي أُنشئ عليه حساب المالك؟
  static bool get isPrimaryOwnerDevice {
    final cfg = ownerConfig;
    if (cfg.ownerDeviceId.isEmpty) return false;
    return cfg.ownerDeviceId == DeviceService.deviceId;
  }

  /// حفظ إعدادات المالك محلياً + بثّها سحابياً.
  static Future<void> _saveOwnerConfig(OwnerConfig cfg) async {
    await _ownerCfg.put(_ownerConfigKey, cfg.toMap());
    _pushOwnerConfigToCloud(cfg);
  }

  /// بدء/تحديث جلسة مالك النظام (تجعلها فعّالة على كل الأجهزة).
  static Future<void> activateOwnerSession() async {
    final cfg = ownerConfig.copyWith(
      sessionActive: true,
      sessionDeviceId: DeviceService.deviceId,
      lastActiveAt: DateTime.now().toIso8601String(),
    );
    await _saveOwnerConfig(cfg);
  }

  /// تحديث نبضة النشاط لجلسة المالك (تبقى فعّالة).
  static Future<void> heartbeatOwnerSession() async {
    final cfg = ownerConfig;
    if (!cfg.sessionActive) return;
    if (cfg.sessionDeviceId != DeviceService.deviceId) return;
    await _ownerCfg.put(
      _ownerConfigKey,
      cfg.copyWith(lastActiveAt: DateTime.now().toIso8601String()).toMap(),
    );
  }

  /// إنهاء جلسة مالك النظام (تظهر إمكانية الدخول للأجهزة المصرّح لها).
  static Future<void> endOwnerSession() async {
    final cfg = ownerConfig.copyWith(sessionActive: false, sessionDeviceId: '');
    await _saveOwnerConfig(cfg);
  }

  /// (المالك) السماح لأجهزة أخرى بإظهار قسم الدخول إلى اللوحة.
  static Future<void> setAllowDeviceEntry(bool allow) async {
    await _saveOwnerConfig(ownerConfig.copyWith(allowDeviceEntry: allow));
  }

  /// (المالك) ربط «أول منشأة» لتتمكّن من فتح لوحة المالك من داخل التطبيق.
  static Future<void> setAllowCompanyEntry(
    bool allow, {
    String? companyId,
  }) async {
    await _saveOwnerConfig(
      ownerConfig.copyWith(
        allowCompanyEntry: allow,
        linkedCompanyId: companyId ?? ownerConfig.linkedCompanyId,
      ),
    );
  }

  /// هل يُسمح لهذا الجهاز بإظهار قسم دخول المالك؟
  ///   • الجهاز الأول (المُنشئ) → دائماً.
  ///   • غيره → فقط إن سمح المالك صراحةً.
  static bool get canShowOwnerEntryOnDevice {
    if (isPrimaryOwnerDevice) return true;
    return ownerConfig.allowDeviceEntry;
  }

  /// هل يُسمح للمنشأة المرتبطة بفتح اللوحة من داخل التطبيق؟
  static bool canCompanyOpenOwnerPanel(String companyId) {
    final cfg = ownerConfig;
    if (!cfg.allowCompanyEntry) return false;
    if (cfg.linkedCompanyId.isEmpty) return false;
    return cfg.linkedCompanyId == companyId;
  }

  /// هل جلسة المالك فعّالة الآن (وتُخفي قسم الدخول عن الجميع)؟
  static bool get isOwnerSessionActive => ownerConfig.isSessionFresh;

  /// دمج إعدادات المالك القادمة من السحابة (بدون دهس نبضة أحدث محلياً).
  static Future<void> applyCloudOwnerConfig(OwnerConfig remote) async {
    final local = ownerConfig;
    // نبضة أحدث محلياً (نفس الجهاز) → لا نتراجع
    final localAt = DateTime.tryParse(local.lastActiveAt);
    final remoteAt = DateTime.tryParse(remote.lastActiveAt);
    if (local.sessionDeviceId == DeviceService.deviceId &&
        local.sessionActive &&
        localAt != null &&
        (remoteAt == null || localAt.isAfter(remoteAt))) {
      // حدّث فقط الحقول الإدارية (allowDeviceEntry / linkedCompany)
      final merged = remote.copyWith(
        sessionActive: local.sessionActive,
        sessionDeviceId: local.sessionDeviceId,
        lastActiveAt: local.lastActiveAt,
      );
      await _ownerCfg.put(_ownerConfigKey, merged.toMap());
      return;
    }
    await _ownerCfg.put(_ownerConfigKey, remote.toMap());
  }

  // ==========================================================================
  // ============================ حسابات المنشآت ============================
  // ==========================================================================

  /// كل المنشآت (مرتّبة بالأحدث)
  static List<CompanyAccount> allCompanies() {
    try {
      final list =
          _companies.values
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
      privileges: CompanyPrivileges(granted: CompanyPrivileges.allKeys.toSet()),
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
    String id,
    CompanyPrivileges privileges,
  ) async {
    final c = companyById(id);
    if (c == null) return;
    await updateCompany(c.copyWith(privileges: privileges));
  }

  /// تغيير كلمة مرور منشأة (من لوحة مالك النظام)
  static Future<void> resetCompanyPassword(
    String id,
    String newPassword,
  ) async {
    final c = companyById(id);
    if (c == null) return;
    final cred = SecurityService.createPassword(newPassword);
    await updateCompany(
      c.copyWith(passwordHash: cred.hash, passwordSalt: cred.salt),
    );
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
      c
          .copyWith(
            lastLoginAt: DateTime.now().toIso8601String(),
            synced: false,
          )
          .toMap(),
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
      final list =
          _devices.values
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

  /// أجهزة مستخدم معيّن
  static List<DeviceRegistry> devicesOfUser(String userId) =>
      allDevices().where((d) => d.userId == userId).toList();

  /// آخر جهاز استخدمه مستخدم (لجلب نوع الهاتف/الدولة)
  static DeviceRegistry? lastDeviceOfUser(String userId) {
    final list = devicesOfUser(userId);
    if (list.isEmpty) return null;
    return list.first;
  }

  /// أجهزة منشأة معيّنة
  static List<DeviceRegistry> devicesOfCompany(String companyId) =>
      allDevices().where((d) => d.companyId == companyId).toList();

  /// آخر جهاز استُخدم لفتح منشأة (لجلب نوع الهاتف/الدولة للمستخدم الرئيسي)
  static DeviceRegistry? lastDeviceOfCompany(String companyId) {
    final list = devicesOfCompany(companyId);
    if (list.isNotEmpty) return list.first;
    return null;
  }

  /// تسجيل/تحديث جهاز عند كل إقلاع للتطبيق.
  /// يُعيد معرّف الجهاز الحالي.
  static Future<String> registerDevice({
    required String deviceId,
    String platform = '',
    String appVersion = '1.0.0',
    String model = '',
    String brand = '',
    String osVersion = '',
    String country = '',
    String countryCode = '',
  }) async {
    final existing = deviceById(deviceId);
    final DeviceRegistry dev;
    if (existing == null) {
      dev = DeviceRegistry(
        deviceId: deviceId,
        platform: platform,
        appVersion: appVersion,
        model: model,
        brand: brand,
        osVersion: osVersion,
        country: country,
        countryCode: countryCode,
        launchCount: 1,
      );
    } else {
      dev = existing.copyWith(
        platform: platform.isEmpty ? existing.platform : platform,
        appVersion: appVersion,
        model: model.isEmpty ? existing.model : model,
        brand: brand.isEmpty ? existing.brand : brand,
        osVersion: osVersion.isEmpty ? existing.osVersion : osVersion,
        country: country.isEmpty ? existing.country : country,
        countryCode: countryCode.isEmpty ? existing.countryCode : countryCode,
        launchCount: existing.launchCount + 1,
        synced: false,
      );
    }
    await _devices.put(deviceId, dev.toMap());
    _pushDeviceToCloud(dev);
    return deviceId;
  }

  /// تحديث معلومات الجهاز (نوع/بلد) — يُستدعى عند توفّر بيانات أدقّ
  static Future<void> updateDeviceInfo({
    required String deviceId,
    String country = '',
    String countryCode = '',
    String model = '',
    String brand = '',
  }) async {
    final dev = deviceById(deviceId);
    if (dev == null) return;
    final updated = dev.copyWith(
      country: country.isEmpty ? dev.country : country,
      countryCode: countryCode.isEmpty ? dev.countryCode : countryCode,
      model: model.isEmpty ? dev.model : model,
      brand: brand.isEmpty ? dev.brand : brand,
      synced: false,
    );
    await _devices.put(deviceId, updated.toMap());
    _pushDeviceToCloud(updated);
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
  // ============================ الزوار (دخول بدون حساب) ============================
  // ==========================================================================

  static List<GuestAccount> allGuests() {
    try {
      final list =
          _guests.values
              .whereType<Map>()
              .map((m) => GuestAccount.fromMap(Map<String, dynamic>.from(m)))
              .toList()
            ..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  static GuestAccount? guestById(String id) {
    final m = _guests.get(id);
    if (m is Map) return GuestAccount.fromMap(Map<String, dynamic>.from(m));
    return null;
  }

  /// تسجيل زيارة زائر (يُنشئ السجل أول مرة ثم يزيد العدّاد)
  static Future<void> registerGuest({
    required String deviceId,
    String platform = '',
    String model = '',
    String country = '',
    String countryCode = '',
  }) async {
    final id = 'guest_$deviceId';
    final existing = guestById(id);
    final GuestAccount g;
    if (existing == null) {
      g = GuestAccount(
        id: id,
        deviceId: deviceId,
        platform: platform,
        model: model,
        country: country,
        countryCode: countryCode,
        visits: 1,
      );
    } else {
      g = existing.copyWith(
        platform: platform.isEmpty ? existing.platform : platform,
        model: model.isEmpty ? existing.model : model,
        country: country.isEmpty ? existing.country : country,
        countryCode: countryCode.isEmpty ? existing.countryCode : countryCode,
        visits: existing.visits + 1,
        synced: false,
      );
    }
    await _guests.put(id, g.toMap());
    _pushGuestToCloud(g);
  }

  /// تعليم أن زائراً تحوّل إلى حساب منشأة
  static Future<void> markGuestConverted(
    String deviceId,
    String companyId,
  ) async {
    final id = 'guest_$deviceId';
    final g = guestById(id);
    if (g == null) return;
    final updated = g.copyWith(
      converted: true,
      convertedToCompanyId: companyId,
      synced: false,
    );
    await _guests.put(id, updated.toMap());
    _pushGuestToCloud(updated);
  }

  static Future<void> deleteGuest(String id) async {
    await _guests.delete(id);
    try {
      await _db?.collection('guest_accounts').doc(id).delete();
    } catch (_) {}
  }

  // ==========================================================================
  // ============================ حسابات Google ============================
  // ==========================================================================

  static List<GoogleAccount> allGoogleAccounts() {
    try {
      final list =
          _google.values
              .whereType<Map>()
              .map((m) => GoogleAccount.fromMap(Map<String, dynamic>.from(m)))
              .toList()
            ..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  static GoogleAccount? googleById(String id) {
    final m = _google.get(id);
    if (m is Map) return GoogleAccount.fromMap(Map<String, dynamic>.from(m));
    return null;
  }

  /// تسجيل/تحديث حساب Google
  static Future<void> registerGoogleAccount({
    required String id,
    String email = '',
    String displayName = '',
    String photoUrl = '',
    String deviceId = '',
    String platform = '',
    String model = '',
    String country = '',
    String countryCode = '',
    String companyId = '',
  }) async {
    final existing = googleById(id);
    final GoogleAccount g;
    if (existing == null) {
      g = GoogleAccount(
        id: id,
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
        deviceId: deviceId,
        platform: platform,
        model: model,
        country: country,
        countryCode: countryCode,
        companyId: companyId,
        loginCount: 1,
      );
    } else {
      g = existing.copyWith(
        displayName: displayName.isEmpty ? existing.displayName : displayName,
        photoUrl: photoUrl.isEmpty ? existing.photoUrl : photoUrl,
        deviceId: deviceId.isEmpty ? existing.deviceId : deviceId,
        platform: platform.isEmpty ? existing.platform : platform,
        model: model.isEmpty ? existing.model : model,
        country: country.isEmpty ? existing.country : country,
        countryCode: countryCode.isEmpty ? existing.countryCode : countryCode,
        companyId: companyId.isEmpty ? existing.companyId : companyId,
        loginCount: existing.loginCount + 1,
        synced: false,
      );
    }
    await _google.put(id, g.toMap());
    _pushGoogleToCloud(g);
  }

  static Future<void> deleteGoogleAccount(String id) async {
    await _google.delete(id);
    try {
      await _db?.collection('google_accounts').doc(id).delete();
    } catch (_) {}
  }

  // ==========================================================================
  // ============================ بحث/فلتر/ترتيب المنشآت ============================
  // ==========================================================================

  /// بحث المنشآت بالاسم/اسم المستخدم/البريد/الهاتف
  static List<CompanyAccount> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return allCompanies();
    return allCompanies().where((c) {
      return c.companyName.toLowerCase().contains(q) ||
          c.username.toLowerCase().contains(q) ||
          c.ownerName.toLowerCase().contains(q) ||
          c.email.toLowerCase().contains(q) ||
          c.phone.contains(q);
    }).toList();
  }

  /// فلترة + ترتيب المنشآت.
  /// [sort] : newest | mostOps | mostUsers | oldest
  /// [withinDays] : عرض المنشآت خلال آخر N أيام (0 = الكل)
  static List<CompanyAccount> filterAndSort({
    String query = '',
    String sort = 'newest',
    int withinDays = 0,
    required int Function(String companyId) opsCount,
    required int Function(String companyId) usersCount,
  }) {
    var list = search(query);

    // فلتر الفترة
    if (withinDays > 0) {
      final since = DateTime.now().subtract(Duration(days: withinDays));
      list = list.where((c) {
        final d = DateTime.tryParse(c.createdAt);
        return d != null && d.isAfter(since);
      }).toList();
    }

    switch (sort) {
      case 'mostOps':
        list.sort((a, b) => opsCount(b.id).compareTo(opsCount(a.id)));
        break;
      case 'mostUsers':
        list.sort((a, b) => usersCount(b.id).compareTo(usersCount(a.id)));
        break;
      case 'oldest':
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'newest':
      default:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list;
  }

  // ==========================================================================
  // ============================ السحابة ============================
  // ==========================================================================

  static Future<void> _pushSystemOwnerToCloud(SystemOwner owner) async {
    final db = _db;
    if (db == null) return;
    try {
      await db.collection('app_admin').doc('system_owner').set({
        'name': owner.name,
        'username': owner.username,
        'email': owner.email,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('[ControlService] owner push fail: $e');
    }
  }

  /// بثّ إعدادات الوصول إلى لوحة المالك لكل الأجهزة المتصلة.
  static Future<void> _pushOwnerConfigToCloud(OwnerConfig cfg) async {
    final db = _db;
    if (db == null) return;
    try {
      await db.collection('app_admin').doc('owner_config').set({
        'ownerDeviceId': cfg.ownerDeviceId,
        'sessionActive': cfg.sessionActive,
        'sessionDeviceId': cfg.sessionDeviceId,
        'lastActiveAt': cfg.lastActiveAt,
        'allowDeviceEntry': cfg.allowDeviceEntry,
        'allowCompanyEntry': cfg.allowCompanyEntry,
        'linkedCompanyId': cfg.linkedCompanyId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _ownerCfg.put(_ownerConfigKey, cfg.copyWith(synced: true).toMap());
    } catch (e) {
      if (kDebugMode) debugPrint('[ControlService] ownerConfig push fail: $e');
    }
  }

  /// جلب إعدادات المالك + حساب المالك من السحابة (لتفعيل التوجيه الموحّد).
  static Future<void> pullOwnerConfigFromCloud() async {
    final db = _db;
    if (db == null) return;
    try {
      final doc = await db.collection('app_admin').doc('owner_config').get();
      final data = doc.data();
      if (data != null) {
        final map = Map<String, dynamic>.from(data);
        map.remove('updatedAt');
        await applyCloudOwnerConfig(OwnerConfig.fromMap(map));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ControlService] ownerConfig pull fail: $e');
    }
  }

  static Future<void> _pushCompanyToCloud(CompanyAccount acc) async {
    final db = _db;
    if (db == null) return;
    try {
      await db.collection('tenant_registry').doc(acc.id).set({
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
      }, SetOptions(merge: true));
      await _companies.put(acc.id, acc.copyWith(synced: true).toMap());
    } catch (e) {
      if (kDebugMode) debugPrint('[ControlService] company push fail: $e');
    }
  }

  static Future<void> _pushDeviceToCloud(DeviceRegistry dev) async {
    final db = _db;
    if (db == null) return;
    try {
      await db.collection('devices').doc(dev.deviceId).set({
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
      }, SetOptions(merge: true));
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

  static Future<void> _pushGuestToCloud(GuestAccount g) async {
    final db = _db;
    if (db == null) return;
    try {
      await db.collection('guest_accounts').doc(g.id).set({
        'id': g.id,
        'deviceId': g.deviceId,
        'platform': g.platform,
        'model': g.model,
        'country': g.country,
        'countryCode': g.countryCode,
        'firstSeenAt': g.firstSeenAt,
        'lastSeenAt': g.lastSeenAt,
        'visits': g.visits,
        'converted': g.converted,
        'convertedToCompanyId': g.convertedToCompanyId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _guests.put(g.id, g.copyWith(synced: true).toMap());
    } catch (e) {
      if (kDebugMode) debugPrint('[ControlService] guest push fail: $e');
    }
  }

  static Future<void> _pushGoogleToCloud(GoogleAccount g) async {
    final db = _db;
    if (db == null) return;
    try {
      await db.collection('google_accounts').doc(g.id).set({
        'id': g.id,
        'email': g.email,
        'displayName': g.displayName,
        'photoUrl': g.photoUrl,
        'deviceId': g.deviceId,
        'platform': g.platform,
        'model': g.model,
        'country': g.country,
        'countryCode': g.countryCode,
        'firstSeenAt': g.firstSeenAt,
        'lastSeenAt': g.lastSeenAt,
        'loginCount': g.loginCount,
        'companyId': g.companyId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _google.put(g.id, g.copyWith(synced: true).toMap());
    } catch (e) {
      if (kDebugMode) debugPrint('[ControlService] google push fail: $e');
    }
  }

  static void logStatus() {
    if (kDebugMode) {
      debugPrint(
        '[ControlService] cloud: $isCloudAvailable, '
        'companies: ${_companies.length}, '
        'devices: ${_devices.length}, '
        'owner: $hasSystemOwner',
      );
    }
  }
}
