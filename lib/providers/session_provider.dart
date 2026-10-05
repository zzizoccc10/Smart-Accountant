// ============================================================================
// مزوّد الجلسة — SessionProvider
// ----------------------------------------------------------------------------
// يدير ثلاثة أوضاع دخول من الواجهة الرئيسية:
//   1) مالك النظام (SystemOwner) → لوحة التحكم المركزية.
//   2) منشأة/مستخدم (CompanyAccount أو AppUser فرعي) → التطبيق المحاسبي.
//   3) زائر بدون حساب (Guest) → وضع تجريبي.
// كما يدير: الصلاحيات، المزامنة، إلخ.
// ============================================================================
import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../models/control_models.dart';
import '../models/user_models.dart';
import '../services/auth_service.dart';
import '../services/control_service.dart';
import '../services/device_service.dart';
import '../services/firebase_config.dart';
import '../services/operation_service.dart';
import '../services/push_notifications.dart';
import '../services/sync_service.dart';
import '../services/user_service.dart';

class SessionProvider extends ChangeNotifier {
  // ---------------------------- الحالة ----------------------------
  AuthMode _mode = AuthMode.companyUser;
  AppUser? _currentUser;
  CompanyAccount? _activeCompany;
  SystemOwner? _systemOwner;
  bool _busy = false;
  String? _error;

  // ---------------------------- الوصول ----------------------------
  AuthMode get mode => _mode;
  AppUser? get currentUser => _currentUser;
  CompanyAccount? get activeCompany => _activeCompany;
  SystemOwner? get systemOwner => _systemOwner;

  bool get busy => _busy;
  String? get error => _error;

  bool get isLoggedIn => _mode == AuthMode.systemOwner
      ? _systemOwner != null
      : _currentUser != null;

  bool get isSystemOwner => _mode == AuthMode.systemOwner && _systemOwner != null;
  bool get isGuest => _mode == AuthMode.guest;
  bool get isCompanyMode => _mode == AuthMode.companyUser;

  bool get isOwner => _currentUser?.isOwner ?? false;
  bool get cloudEnabled => FirebaseConfig.isConfigured;

  String get currentCompanyId =>
      _activeCompany?.id ??
      AppDatabase.getSetting('companyId', 'default_company');

  // المزامنة
  SyncStatus _syncStatus = SyncStatus.idle;
  SyncResult? _lastSyncResult;
  SyncStatus get syncStatus => _syncStatus;
  SyncResult? get lastSyncResult => _lastSyncResult;
  DateTime? get lastSync => SyncService.lastSync;

  // ==========================================================================
  // ============================ التهيئة ============================
  // ==========================================================================

  /// تحميل الجلسة عند بدء التطبيق (لا يُسجّل الدخول تلقائياً — نعرض شاشة الدخول)
  Future<void> bootstrap() async {
    notifyListeners();
  }

  // ==========================================================================
  // ============================ دخول المنشأة ============================
  // ============================================================================

  /// تسجيل الدخول بوضع المنشأة (مالك منشأة أو مستخدم فرعي).
  /// يقبل: اسم المستخدم أو البريد.
  Future<bool> signInCompany(String login, String password) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      // 1) محاولة السحابة أولاً (إن مُفعّلة وبريد صالح)
      if (AuthService.isCloudAvailable && login.contains('@')) {
        final res = await AuthService.signIn(login, password);
        if (!res.success) {
          // نكمل بالمصادقة المحلية
        }
      }

      // 2) البحث في حسابات المنشآت (المالك الرئيسي للمنشأة)
      final company = ControlService.verifyCompanyLogin(login, password);
      if (company != null) {
        if (!company.isActive) {
          _error = 'هذه المنشأة موقوفة — تواصل مع مالك النظام';
          return false;
        }
        await _enterCompany(company);
        return true;
      }

      // 3) البحث في المستخدمين الفرعيين (أُنشئوا داخل الحساب الرئيسي)
      final user = UserService.verifyCredentials(login, password);
      if (user != null) {
        if (!user.isActive) {
          _error = 'هذا المستخدم مُعطّل';
          return false;
        }
        final co = ControlService.companyById(user.companyId);
        if (co != null && !co.isActive) {
          _error = 'المنشأة موقوفة — تواصل مع مالك النظام';
          return false;
        }
        _mode = AuthMode.companyUser;
        _activeCompany = co;
        _currentUser = user;
        if (co != null) {
          await ControlService.setActiveCompany(co.id);
        }
        await _afterLogin(user);
        return true;
      }

      // 4) رجوع: دخول محلي قديم بالبريد فقط (بيانات ما قبل لوحة التحكم)
      final legacy = UserService.byEmail(login);
      if (legacy != null && legacy.isActive && !legacy.hasCredentials) {
        _mode = AuthMode.companyUser;
        _currentUser = legacy;
        await _afterLogin(legacy);
        return true;
      }

      _error = 'بيانات الدخول غير صحيحة';
      return false;
    } catch (e) {
      _error = '$e';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _enterCompany(CompanyAccount company) async {
    _mode = AuthMode.companyUser;
    _activeCompany = company;
    await ControlService.setActiveCompany(company.id);
    await ControlService.touchCompanyLogin(company.id);

    // ابحث عن مالك المنشأة (مستخدم بدور owner داخل نفس المنشأة)
    AppUser? owner;
    for (final u in UserService.all()) {
      if (u.companyId == company.id && u.role == UserRole.owner) {
        owner = u;
        break;
      }
    }
    // إن لم يوجد مستخدم داخلي، أنشئ مالكاً افتراضياً مرتبطاً بالمنشأة
    owner ??= await UserService.create(AppUser(
      id: UserService.newId(),
      name: company.ownerName.isEmpty ? company.companyName : company.ownerName,
      email: company.email,
      username: company.username,
      phone: company.phone,
      role: UserRole.owner,
      companyId: company.id,
      useRoleDefaults: true,
    ));
    _currentUser = owner;
    await _afterLogin(owner);
  }

  // ==========================================================================
  // ============================ دخول مالك النظام ============================
  // ==========================================================================

  /// هل يوجد حساب مالك نظام مُنشأ؟
  bool get hasSystemOwner => ControlService.hasSystemOwner;

  /// إنشاء حساب مالك النظام الأول
  Future<bool> createSystemOwner({
    required String name,
    required String username,
    required String password,
    String email = '',
  }) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await ControlService.createSystemOwner(
        name: name,
        username: username,
        password: password,
        email: email,
      );
      _systemOwner = ControlService.systemOwner;
      _mode = AuthMode.systemOwner;
      await ControlService.touchSystemOwnerLogin();
      return true;
    } catch (e) {
      _error = '$e';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// تسجيل دخول مالك النظام
  Future<bool> signInSystemOwner(String username, String password) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      if (!ControlService.verifySystemOwner(username, password)) {
        _error = 'بيانات مالك النظام غير صحيحة';
        return false;
      }
      _mode = AuthMode.systemOwner;
      _systemOwner = ControlService.systemOwner;
      await ControlService.touchSystemOwnerLogin();
      // زامن قائمة المنشآت من السحابة (لو متاحة)
      if (ControlService.isCloudAvailable) {
        // لا ننتظر
        ControlService.pullCompaniesFromCloud();
      }
      return true;
    } catch (e) {
      _error = '$e';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  // ==========================================================================
  // ============================ الدخول كزائر ============================
  // ==========================================================================

  /// الدخول بدون حساب (وضع تجريبي محلي)
  Future<void> continueAsGuest() async {
    _mode = AuthMode.guest;
    _activeCompany = null;
    // مستخدم زائر افتراضي بصلاحيات مشاهدة موسّعة للاستكشاف
    var guest = UserService.byEmail('guest@local');
    guest ??= await UserService.create(AppUser(
      id: 'guest_local',
      name: 'زائر',
      email: 'guest@local',
      role: UserRole.owner, // للاستكشاف الكامل، دون كتابة سحابية
      useRoleDefaults: true,
    ));
    _currentUser = guest;
    // سجّل الزائر في لوحة مالك النظام (قائمة الزوار)
    await DeviceService.recordGuestVisit();
    await OperationService.log(action: 'guest_login');
    notifyListeners();
  }

  // ==========================================================================
  // ============================ تسجيل منشأة جديدة ============================
  // ==========================================================================

  /// إنشاء حساب منشأة جديد من الواجهة الرئيسية.
  Future<bool> registerCompany({
    required String companyName,
    required String ownerName,
    required String username,
    required String password,
    String email = '',
    String phone = '',
  }) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      // منع تكرار اسم المستخدم/البريد
      if (ControlService.companyByLogin(username) != null) {
        _error = 'اسم المستخدم مستخدم بالفعل';
        return false;
      }
      if (email.isNotEmpty && ControlService.companyByLogin(email) != null) {
        _error = 'البريد مستخدم بالفعل';
        return false;
      }

      // محاولة سحابية (اختيارية): إنشاء حساب Firebase Auth بالبريد
      String createdVia = 'device';
      if (AuthService.isCloudAvailable && email.contains('@')) {
        final res = await AuthService.signUp(
          email,
          password,
          displayName: ownerName,
        );
        if (res.success) createdVia = 'email';
      }

      final company = await ControlService.createCompany(
        companyName: companyName,
        ownerName: ownerName,
        username: username,
        password: password,
        email: email,
        phone: phone,
        deviceId: DeviceService.deviceId,
        createdVia: createdVia,
      );

      // سجّل أن هذا الجهاز أنشأ حساباً
      await DeviceService.markAccountCreated(company.id, ownerName);

      // دخول مباشر إلى المنشأة الجديدة
      await _enterCompany(company);
      return true;
    } catch (e) {
      _error = '$e';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  // ==========================================================================
  // ============================ الدخول عبر Google ============================
  // ==========================================================================

  /// الدخول عبر Google ثم إدخال المستخدم إلى التطبيق.
  /// ينشئ/يربط منشأة بالبريد لدى Google تلقائياً عند أول دخول.
  Future<bool> signInWithGoogleAndEnter() async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final res = await AuthService.signInWithGoogle();
      if (!res.success) {
        _error = res.error;
        return false;
      }
      final email = res.email ?? '';
      if (email.isEmpty) {
        _error = 'تعذّر الحصول على البريد من حساب Google';
        return false;
      }

      // ابحث عن منشأة مرتبطة بهذا البريد
      var company = ControlService.companyByLogin(email);
      if (company == null) {
        // أنشئ منشأة جديدة مرتبطة بالبريد
        final name = res.displayName?.trim().isNotEmpty == true
            ? res.displayName!.trim()
            : email.split('@').first;
        company = await ControlService.createCompany(
          companyName: name,
          ownerName: name,
          username: email.split('@').first,
          password: AuthService.currentUid ?? 'google_${DateTime.now().millisecondsSinceEpoch}',
          email: email,
          deviceId: DeviceService.deviceId,
          createdVia: 'google',
        );
        await DeviceService.markAccountCreated(company.id, name);
      }
      if (!company.isActive) {
        _error = 'هذه المنشأة موقوفة — تواصل مع مالك النظام';
        return false;
      }
      // سجّل حساب Google (أو حدّثه) في لوحة مالك النظام
      await DeviceService.recordGoogleLogin(
        uid: AuthService.currentUid ?? '',
        email: email,
        displayName: res.displayName ?? '',
        photoUrl: res.photoUrl ?? '',
        companyId: company.id,
      );
      await OperationService.log(
        action: 'google_login',
        companyId: company.id,
        userName: res.displayName ?? email,
        details: email,
      );
      await _enterCompany(company);
      return true;
    } catch (e) {
      _error = 'تعذّر الدخول عبر Google: $e';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  // ==========================================================================
  // ============================ مساعدات ============================
  // ==========================================================================

  Future<void> _afterLogin(AppUser user) async {
    await UserService.logActivity(
      userId: user.id,
      userName: user.name,
      action: 'login',
      details: _activeCompany?.companyName ?? '',
    );
    // سجّل العملية في لوحة مالك النظام (عدّادات المنشآت/المستخدمين)
    await OperationService.log(
      action: 'login',
      companyId: user.companyId,
      userId: user.id,
      userName: user.name,
      details: _activeCompany?.companyName ?? '',
    );
    await _pushTokenToUser();
    // اربط الجهاز بالمستخدم
    await DeviceService.linkUser(
      companyId: user.companyId,
      userId: user.id,
      userName: user.name,
    );
    try {
      await PushNotifications.subscribe('role_${user.role.name}');
      if (user.branchId != null && user.branchId!.isNotEmpty) {
        await PushNotifications.subscribe('branch_${user.branchId}');
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _pushTokenToUser() async {
    final tok = PushNotifications.token;
    if (tok != null && _currentUser != null) {
      await UserService.updateFcmToken(_currentUser!.id, tok);
    }
  }

  /// تسجيل الخروج (يعود لشاشة الدخول)
  Future<void> signOut() async {
    final u = _currentUser;
    if (u != null) {
      await UserService.logActivity(
        userId: u.id,
        userName: u.name,
        action: 'logout',
      );
    }
    await AuthService.signOut();
    _currentUser = null;
    _activeCompany = null;
    _systemOwner = null;
    _mode = AuthMode.companyUser;
    notifyListeners();
  }

  /// تبديل المستخدم
  Future<void> switchUser(String userId) async {
    final u = UserService.byId(userId);
    if (u == null) return;
    _currentUser = u;
    await _afterLogin(u);
    notifyListeners();
  }

  /// التحقق من صلاحية
  bool can(String permission) => _currentUser?.can(permission) ?? false;
  bool canAny(List<String> permissions) =>
      _currentUser?.canAny(permissions) ?? false;

  // ---------------------------- المزامنة ----------------------------
  Future<void> syncNow() async {
    _syncStatus = SyncStatus.syncing;
    notifyListeners();
    final res = await SyncService.syncAll();
    _lastSyncResult = res;
    _syncStatus = res.status;
    notifyListeners();
  }

  void logStatus() {
    debugPrint('[Session] mode: ${_mode.name}, '
        'user: ${_currentUser?.name}, cloud: $cloudEnabled');
  }
}
