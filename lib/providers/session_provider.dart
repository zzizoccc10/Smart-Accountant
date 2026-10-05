// ============================================================================
// مزوّد الجلسة — SessionProvider
// ----------------------------------------------------------------------------
// يدير: المستخدم الحالي، تسجيل الدخول/الخروج، الصلاحيات، المزامنة، الإشعارات.
// يُستخدم عبر Provider في جميع أنحاء التطبيق للتحقق من الصلاحيات.
// ============================================================================
import 'package:flutter/foundation.dart';

import '../models/user_models.dart';
import '../services/auth_service.dart';
import '../services/firebase_config.dart';
import '../services/push_notifications.dart';
import '../services/sync_service.dart';
import '../services/user_service.dart';

class SessionProvider extends ChangeNotifier {
  AppUser? _currentUser;
  bool _busy = false;
  String? _error;

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get busy => _busy;
  String? get error => _error;

  bool get isOwner => _currentUser?.isOwner ?? false;
  bool get cloudEnabled => FirebaseConfig.isConfigured;

  SyncStatus _syncStatus = SyncStatus.idle;
  SyncResult? _lastSyncResult;
  SyncStatus get syncStatus => _syncStatus;
  SyncResult? get lastSyncResult => _lastSyncResult;
  DateTime? get lastSync => SyncService.lastSync;

  /// تحميل الجلسة عند بدء التطبيق
  Future<void> bootstrap() async {
    final savedId = UserService.hasUsers ? _savedUserId() : null;
    if (savedId != null) {
      _currentUser = UserService.byId(savedId);
    }
    // إن لم يوجد مستخدم محفوظ، اختر المالك
    _currentUser ??= UserService.owner;
    notifyListeners();
  }

  String? _savedUserId() {
    // نستخدم أول مستخدم محفوظ كجلسة افتراضية (يمكن ربطه بـ Firebase Auth)
    final users = UserService.all();
    if (users.isEmpty) return null;
    return users.first.id;
  }

  /// إنشاء حساب المالك الأول
  Future<AppUser> createOwner({
    required String name,
    required String email,
    String phone = '',
  }) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      // تأمين: تسجيل دخول مجهول قبل الكتابة السحابية (إن كانت السحابة مُفعّلة)
      await AuthService.ensureSignedIn();
      final owner = await UserService.ensureOwner(
        name: name,
        email: email,
        uid: AuthService.currentUid,
      );
      await UserService.update(owner.copyWith(phone: phone));
      _currentUser = UserService.byId(owner.id) ?? owner;
      await _pushTokenToUser();
      return _currentUser!;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// تسجيل الدخول (سحابياً عبر Firebase Auth، مع رجوع محلي)
  Future<bool> signIn(String email, String password) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      // 1) محاولة سحابية
      if (AuthService.isCloudAvailable) {
        final res = await AuthService.signIn(email, password);
        if (!res.success) {
          // قد يكون مستخدماً محلياً بدون حساب سحابي — نجرّب المحلي
          final local = UserService.byEmail(email);
          if (local != null && local.isActive) {
            _currentUser = local;
            await _afterLogin(local);
            return true;
          }
          _error = res.error;
          return false;
        }
        // نجح سحابياً — اربطه بمستخدم محلي
        final user = UserService.byEmail(email) ??
            await UserService.create(AppUser(
              id: res.uid ?? UserService.newId(),
              name: email.split('@').first,
              email: email,
              role: UserRole.viewer,
            ));
        _currentUser = user;
        await _afterLogin(user);
        return true;
      } else {
        // وضع محلي بالكامل: تحقق بالبريد فقط
        final local = UserService.byEmail(email);
        if (local == null) {
          _error = 'لا يوجد مستخدم بهذا البريد (الوضع المحلي)';
          return false;
        }
        if (!local.isActive) {
          _error = 'هذا المستخدم مُعطّل';
          return false;
        }
        _currentUser = local;
        await _afterLogin(local);
        return true;
      }
    } catch (e) {
      _error = '$e';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _afterLogin(AppUser user) async {
    await UserService.logActivity(
      userId: user.id,
      userName: user.name,
      action: 'login',
    );
    await _pushTokenToUser();
    await PushNotifications.subscribe('role_${user.role.name}');
    if (user.branchId != null && user.branchId!.isNotEmpty) {
      await PushNotifications.subscribe('branch_${user.branchId}');
    }
  }

  Future<void> _pushTokenToUser() async {
    final tok = PushNotifications.token;
    if (tok != null && _currentUser != null) {
      await UserService.updateFcmToken(_currentUser!.id, tok);
    }
  }

  /// تسجيل الخروج
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
    notifyListeners();
  }

  /// تبديل المستخدم (للاختبار / تبديل سريع)
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
    debugPrint('[Session] user: ${_currentUser?.name}, '
        'cloud: $cloudEnabled, role: ${_currentUser?.role.labelAr}');
  }
}
