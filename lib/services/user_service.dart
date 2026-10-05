// ============================================================================
// خدمة المستخدمين — UserService
// ----------------------------------------------------------------------------
// تدير المستخدمين محلياً (Hive) وتُزامنهم مع Firestore عند تفعيل السحابة.
// تحتوي: إضافة/تعديل/حذف المستخدمين، التحقق من الصلاحيات، سجل النشاط.
// ============================================================================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/app_database.dart';
import '../models/user_models.dart';
import 'firebase_config.dart';
import 'operation_service.dart';
import 'security_service.dart';

class UserService {
  static const boxUsers = 'users';
  static const boxUserActivity = 'user_activity';

  static Box get _users => Hive.box(boxUsers);
  static Box get _activity => Hive.box(boxUserActivity);

  static FirebaseFirestore? get _db {
    if (!FirebaseConfig.isConfigured) return null;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  static bool get isCloudAvailable => _db != null;

  /// تهيئة صناديق المستخدمين (تُستدعى من AppDatabase.init)
  static Future<void> initBoxes() async {
    if (!Hive.isBoxOpen(boxUsers)) await Hive.openBox(boxUsers);
    if (!Hive.isBoxOpen(boxUserActivity)) await Hive.openBox(boxUserActivity);
  }

  static String newId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'u_$now';
  }

  // ---------------------------- القراءة ----------------------------
  static List<AppUser> all() {
    try {
      return _users.values
          .whereType<Map>()
          .map((m) => AppUser.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static AppUser? byId(String id) {
    final m = _users.get(id);
    if (m is Map) return AppUser.fromMap(Map<String, dynamic>.from(m));
    return null;
  }

  static AppUser? byEmail(String email) {
    final e = email.trim().toLowerCase();
    if (e.isEmpty) return null;
    for (final u in all()) {
      if (u.email.toLowerCase() == e) return u;
    }
    return null;
  }

  /// البحث باسم المستخدم (للدخول من داخل المنشأة)
  static AppUser? byUsername(String username) {
    final key = username.trim().toLowerCase();
    if (key.isEmpty) return null;
    for (final u in all()) {
      if (u.username.toLowerCase() == key) return u;
    }
    return null;
  }

  /// البحث ببريد أو اسم مستخدم (موحّد لشاشة الدخول)
  static AppUser? byLogin(String login) {
    return byEmail(login) ?? byUsername(login);
  }

  /// التحقق من بيانات دخول مستخدم (اسم مستخدم/بريد + كلمة مرور)
  static AppUser? verifyCredentials(String login, String password) {
    final u = byLogin(login);
    if (u == null) return null;
    if (!u.hasCredentials) return null;
    if (!SecurityService.verify(password, u.passwordHash, u.passwordSalt)) {
      return null;
    }
    return u;
  }

  /// إنشاء مستخدم ببيانات دخول (اسم مستخدم + كلمة مرور) من داخل الحساب الرئيسي
  static Future<AppUser> createWithCredentials({
    required String name,
    required String username,
    required String password,
    String email = '',
    String phone = '',
    required UserRole role,
    Set<String>? permissions,
    bool useRoleDefaults = true,
    String? branchId,
    String companyId = '',
    String createdBy = '',
  }) async {
    final cred = SecurityService.createPassword(password);
    final u = AppUser(
      id: newId(),
      name: name.trim(),
      username: username.trim(),
      passwordHash: cred.hash,
      passwordSalt: cred.salt,
      email: email.trim(),
      phone: phone.trim(),
      role: role,
      permissions: permissions ?? {},
      useRoleDefaults: useRoleDefaults,
      branchId: branchId,
      companyId: companyId,
      createdBy: createdBy,
    );
    return create(u);
  }

  /// تغيير كلمة مرور مستخدم
  static Future<void> setPassword(String userId, String newPassword) async {
    final u = byId(userId);
    if (u == null) return;
    final cred = SecurityService.createPassword(newPassword);
    await update(u.copyWith(passwordHash: cred.hash, passwordSalt: cred.salt));
  }

  /// عدد مستخدمي منشأة معيّنة
  static int countOfCompany(String companyId) {
    if (companyId.isEmpty) return all().length;
    return all().where((u) => u.companyId == companyId).length;
  }

  /// مستخدمو منشأة معيّنة
  static List<AppUser> ofCompany(String companyId, {String? excludeId}) {
    return all()
        .where(
          (u) =>
              u.companyId == companyId &&
              (excludeId == null || u.id != excludeId),
        )
        .toList();
  }

  /// هل يوجد أي مستخدم مُعرَّف؟ (لتحديد إن كنا بحاجة لإنشاء المالك الأول)
  static bool get hasUsers => _users.isNotEmpty;

  /// المستخدم المالك (أول مستخدم بدور owner)
  static AppUser? get owner {
    for (final u in all()) {
      if (u.role == UserRole.owner) return u;
    }
    return null;
  }

  // ---------------------------- الكتابة ----------------------------
  static Future<AppUser> create(AppUser user) async {
    var u = user;
    if (u.id.isEmpty) {
      u = AppUser(
        id: newId(),
        name: u.name,
        email: u.email,
        phone: u.phone,
        role: u.role,
        permissions: u.permissions,
        useRoleDefaults: u.useRoleDefaults,
        isActive: u.isActive,
        branchId: u.branchId,
        photoUrl: u.photoUrl,
      );
    }
    u = u.copyWith(synced: false);
    await _users.put(u.id, u.toMap());
    _pushToCloud(u);
    return u;
  }

  static Future<void> update(AppUser user) async {
    final u = user.copyWith(synced: false);
    await _users.put(u.id, u.toMap());
    _pushToCloud(u);
  }

  static Future<void> delete(String id) async {
    await _users.delete(id);
    try {
      await _db
          ?.collection('companies')
          .doc(AppDatabase.getSetting('companyId', 'default_company'))
          .collection('users')
          .doc(id)
          .delete();
    } catch (_) {}
  }

  /// إنشاء المستخدم المالك الأول (عند أول تشغيل)
  static Future<AppUser> ensureOwner({
    String name = 'المالك',
    String email = 'owner@easyaccountant.app',
    String? uid,
  }) async {
    final existing = owner;
    if (existing != null) return existing;
    final u = AppUser(
      id: (uid != null && uid.isNotEmpty) ? uid : newId(),
      name: name,
      email: email,
      role: UserRole.owner,
      useRoleDefaults: true,
    );
    await _users.put(u.id, u.toMap());
    return u;
  }

  /// تحديث رمز الإشعارات (FCM) لمستخدم
  static Future<void> updateFcmToken(String userId, String token) async {
    final u = byId(userId);
    if (u == null) return;
    final updated = u.copyWith(fcmToken: token);
    await _users.put(updated.id, updated.toMap());
    _pushToCloud(updated);
  }

  // ---------------------------- السجل ----------------------------
  static Future<void> logActivity({
    required String userId,
    required String userName,
    required String action,
    String details = '',
  }) async {
    final act = UserActivity(
      id: 'act_${DateTime.now().microsecondsSinceEpoch}',
      userId: userId,
      userName: userName,
      action: action,
      details: details,
    );
    await _activity.put(act.id, act.toMap());
    // سجّل العملية أيضاً في لوحة تحكم مالك النظام (عدّادات المنشآت/المستخدمين)
    try {
      await OperationService.log(
        action: action,
        companyId: AppDatabase.getSetting('companyId', ''),
        userId: userId,
        userName: userName,
        details: details,
      );
    } catch (_) {}
  }

  static List<UserActivity> recentActivity({int limit = 100}) {
    try {
      final list =
          _activity.values
              .whereType<Map>()
              .map((m) => UserActivity.fromMap(Map<String, dynamic>.from(m)))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list.take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> clearActivity() => _activity.clear();

  // ---------------------------- السحابة ----------------------------
  static Future<void> _pushToCloud(AppUser u) async {
    final db = _db;
    if (db == null) return;
    try {
      await db
          .collection('companies')
          .doc(AppDatabase.getSetting('companyId', 'default_company'))
          .collection('users')
          .doc(u.id)
          .set({
            'id': u.id,
            'name': u.name,
            'email': u.email,
            'phone': u.phone,
            'role': u.role.name,
            'isActive': u.isActive,
            'branchId': u.branchId,
            'fcmToken': u.fcmToken,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      // علّم كمُزامَن
      await _users.put(u.id, u.copyWith(synced: true).toMap());
    } catch (e) {
      if (kDebugMode) debugPrint('[UserService] push fail: $e');
    }
  }

  /// جلب المستخدمين من السحابة (للمزامنة)
  static Future<int> pullFromCloud() async {
    final db = _db;
    if (db == null) return 0;
    int count = 0;
    try {
      final snap = await db
          .collection('companies')
          .doc(AppDatabase.getSetting('companyId', 'default_company'))
          .collection('users')
          .get();
      for (final doc in snap.docs) {
        final map = Map<String, dynamic>.from(doc.data());
        map['synced'] = true;
        map.putIfAbsent('id', () => doc.id);
        await _users.put(map['id'], map);
        count++;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[UserService] pull fail: $e');
    }
    return count;
  }

  static void logStatus() {
    if (kDebugMode) {
      debugPrint(
        '[UserService] cloud: $isCloudAvailable, users: ${_users.length}',
      );
    }
  }
}
