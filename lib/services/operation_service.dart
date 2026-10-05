// ============================================================================
// خدمة العمليات — OperationService
// ----------------------------------------------------------------------------
// تسجّل كل عملية تحصل في النظام (لكل منشأة/مستخدم) وتوفّر العدّادات والفلاتر
// التي تعتمد عليها لوحة تحكم مالك النظام.
// تخزين محلي (Hive: 'operations') + اختياري سحابي (Firestore collection 'operations').
// ============================================================================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/control_models.dart';
import 'firebase_config.dart';

class OperationService {
  static const boxOperations = 'operations';
  static const int _maxLocal = 5000; // حد أقصى للتخزين المحلي

  static Box get _box => Hive.box(boxOperations);

  static FirebaseFirestore? get _db {
    if (!FirebaseConfig.isConfigured) return null;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  /// تهيئة الصندوق (من main)
  static Future<void> initBox() async {
    if (!Hive.isBoxOpen(boxOperations)) await Hive.openBox(boxOperations);
  }

  // ---------------------------- الكتابة ----------------------------
  /// تسجيل عملية جديدة.
  static Future<void> log({
    required String action,
    String companyId = '',
    String userId = '',
    String userName = '',
    String details = '',
  }) async {
    try {
      final op = OperationLog(
        id: 'op_${DateTime.now().microsecondsSinceEpoch}',
        companyId: companyId,
        userId: userId,
        userName: userName,
        action: action,
        details: details,
      );
      await _box.put(op.id, op.toMap());
      _cache = null; // إبطال الذاكرة المؤقتة للعدّادات
      _byCompany = null;
      _byUser = null;
      // تقليم السجل المحلي عند تجاوز الحد
      if (_box.length > _maxLocal) {
        final list = all();
        for (final old in list.sublist(_maxLocal)) {
          await _box.delete(old.id);
        }
      }
      _pushToCloud(op);
    } catch (e) {
      if (kDebugMode) debugPrint('[OperationService] log failed: $e');
    }
  }

  // ---------------------------- القراءة ----------------------------
  /// كل العمليات (الأحدث أولاً)
  static List<OperationLog> all() {
    try {
      final list = _box.values
          .whereType<Map>()
          .map((m) => OperationLog.fromMap(Map<String, dynamic>.from(m)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  /// عمليات منشأة معيّنة
  static List<OperationLog> ofCompany(String companyId) =>
      all().where((o) => o.companyId == companyId).toList();

  /// عمليات مستخدم معيّن
  static List<OperationLog> ofUser(String userId) =>
      all().where((o) => o.userId == userId).toList();

  // ---------------------------- عدّادات سريعة (ذاكرة مؤقتة) ----------------------------
  // تجنّباً لمسح السجل كاملاً في كل استدعاء (قد تكون هناك آلاف العمليات).
  static List<OperationLog>? _cache;
  static int _cacheLen = -1;
  static Map<String, int>? _byCompany;
  static Map<String, int>? _byUser;

  static List<OperationLog> _cachedAll() {
    if (_cache != null && _cacheLen == _box.length) return _cache!;
    final fresh = all();
    _cache = fresh;
    _cacheLen = _box.length;
    _byCompany = null;
    _byUser = null;
    return fresh;
  }

  static Map<String, int> _companyIndex() {
    if (_byCompany != null) return _byCompany!;
    final m = <String, int>{};
    for (final o in _cachedAll()) {
      if (o.companyId.isEmpty) continue;
      m[o.companyId] = (m[o.companyId] ?? 0) + 1;
    }
    return _byCompany = m;
  }

  static Map<String, int> _userIndex() {
    if (_byUser != null) return _byUser!;
    final m = <String, int>{};
    for (final o in _cachedAll()) {
      if (o.userId.isEmpty) continue;
      m[o.userId] = (m[o.userId] ?? 0) + 1;
    }
    return _byUser = m;
  }

  /// عدد عمليات منشأة
  static int countOfCompany(String companyId) =>
      companyId.isEmpty ? 0 : (_companyIndex()[companyId] ?? 0);

  /// عدد عمليات مستخدم
  static int countOfUser(String userId) =>
      userId.isEmpty ? 0 : (_userIndex()[userId] ?? 0);

  /// عدد عمليات منشأة خلال فترة (عدد الأيام للخلف)
  static int countOfCompanySince(String companyId, int days) {
    final since = DateTime.now().subtract(Duration(days: days));
    return ofCompany(companyId).where((o) {
      final d = DateTime.tryParse(o.createdAt);
      return d != null && d.isAfter(since);
    }).length;
  }

  /// إجمالي العمليات اليوم
  static int todayCount() {
    final today = DateTime.now().toIso8601String().split('T').first;
    return all().where((o) => o.createdAt.startsWith(today)).length;
  }

  static Future<void> clearAll() async {
    _cache = null;
    _byCompany = null;
    _byUser = null;
    await _box.clear();
  }

  // ---------------------------- السحابة ----------------------------
  static Future<void> _pushToCloud(OperationLog op) async {
    final db = _db;
    if (db == null) return;
    try {
      await db.collection('operations').doc(op.id).set(
        {
          'id': op.id,
          'companyId': op.companyId,
          'userId': op.userId,
          'userName': op.userName,
          'action': op.action,
          'details': op.details,
          'createdAt': op.createdAt,
          'serverAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[OperationService] push fail: $e');
    }
  }

  static void logStatus() {
    if (kDebugMode) {
      debugPrint('[OperationService] total: ${_box.length}');
    }
  }
}
