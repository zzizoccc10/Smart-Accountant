// ============================================================================
// خدمة المزامنة — SyncService
// ----------------------------------------------------------------------------
// تُزامن بيانات Hive المحلية مع Firestore السحابي (Offline-First):
//   • رفع التغييرات المحلية (push) إلى السحابة.
//   • جلب تغييرات السحابة (pull) إلى المحلي.
//   • حلّ التعارض: الأحدث يفوز (Last-Write-Wins) بناءً على updatedAt.
//   • كل مجموعة (collection) تُخزَّن في مسار: companies/{companyId}/{box}
// جميع العمليات محصّنة: إن لم تكن السحابة مُفعّلة => لا تفعل شيئاً بهدوء.
// ============================================================================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/app_database.dart';
import 'firebase_config.dart';

enum SyncStatus { idle, syncing, success, error, disabled }

class SyncResult {
  final SyncStatus status;
  final int pushed;
  final int pulled;
  final String? error;
  final DateTime at;
  const SyncResult({
    required this.status,
    this.pushed = 0,
    this.pulled = 0,
    this.error,
    required this.at,
  });
}

class SyncService {
  static FirebaseFirestore? get _db {
    if (!FirebaseConfig.isConfigured) return null;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  static bool get isCloudAvailable => _db != null;

  /// معرّف الشركة (مساحة العمل) — يُستخدم لفصل بيانات كل شركة/مستخدم
  static String get companyId {
    final cid = AppDatabase.getSetting('companyId', '');
    if (cid.isNotEmpty) return cid;
    return 'default_company';
  }

  /// المجموعات القابلة للمزامنة (Hive box => اسم مجموعة Firestore)
  static const Map<String, String> syncBoxes = {
    AppDatabase.boxAccounts: 'accounts',
    AppDatabase.boxContacts: 'contacts',
    AppDatabase.boxItems: 'items',
    AppDatabase.boxCategories: 'categories',
    AppDatabase.boxInvoices: 'invoices',
    AppDatabase.boxPayments: 'payments',
    AppDatabase.boxExpenses: 'expenses',
    AppDatabase.boxExpenseCats: 'expense_categories',
    AppDatabase.boxMovements: 'movements',
    AppDatabase.boxBalances: 'inv_balances',
    AppDatabase.boxCashboxes: 'cashboxes',
    AppDatabase.boxWarehouses: 'warehouses',
    AppDatabase.boxJournals: 'journals',
    AppDatabase.boxEmployees: 'employees',
    AppDatabase.boxAttendance: 'attendance',
    AppDatabase.boxPayroll: 'payroll',
    AppDatabase.boxCurrencies: 'currencies',
    AppDatabase.boxFixedAssets: 'fixed_assets',
    AppDatabase.boxAllocations: 'payment_allocations',
    AppDatabase.boxBranches: 'branches',
    AppDatabase.boxUnits: 'units',
    AppDatabase.boxCostCenters: 'cost_centers',
    AppDatabase.boxExchangeRates: 'exchange_rates',
    AppDatabase.boxOrders: 'orders',
  };

  static CollectionReference<Map<String, dynamic>> _col(String box) {
    return _db!
        .collection('companies')
        .doc(companyId)
        .collection(box);
  }

  /// آخر وقت مزامنة (يُخزَّن محلياً)
  static DateTime? get lastSync {
    final s = AppDatabase.getSetting('lastSyncAt', '');
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  /// مزامنة كاملة: رفع ثم جلب
  static Future<SyncResult> syncAll({
    void Function(String message)? onProgress,
  }) async {
    if (!isCloudAvailable) {
      return SyncResult(
        status: SyncStatus.disabled,
        error: 'السحابة غير مُفعّلة — ارفع إعدادات Firebase أولاً',
        at: DateTime.now(),
      );
    }

    int totalPushed = 0;
    int totalPulled = 0;
    try {
      for (final entry in syncBoxes.entries) {
        final boxName = entry.key;
        final colName = entry.value;
        onProgress?.call('مزامنة: $colName ...');
        final box = Hive.box(boxName);

        // 1) رفع المحلي غير المُزامَن
        final pushed = await _pushBox(box, colName);
        totalPushed += pushed;

        // 2) جلب السحابي الجديد/الأحدث
        final pulled = await _pullBox(box, colName);
        totalPulled += pulled;
      }

      await AppDatabase.setSetting(
        'lastSyncAt',
        DateTime.now().toIso8601String(),
      );

      return SyncResult(
        status: SyncStatus.success,
        pushed: totalPushed,
        pulled: totalPulled,
        at: DateTime.now(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[SyncService] error: $e');
      return SyncResult(
        status: SyncStatus.error,
        pushed: totalPushed,
        pulled: totalPulled,
        error: '$e',
        at: DateTime.now(),
      );
    }
  }

  /// رفع عناصر الصندوق غير المُزامَنة إلى السحابة
  static Future<int> _pushBox(Box box, String colName) async {
    int count = 0;
    final col = _col(colName);
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final needsSync = map['synced'] != true;
      if (!needsSync) continue;

      // تنظيف البيانات قبل الرفع
      map['_localKey'] = key.toString();
      map['_updatedAt'] = FieldValue.serverTimestamp();
      try {
        await col.doc(key.toString()).set(map, SetOptions(merge: true));
        // علّم محلياً بأنه تمّت مزامنته
        map['synced'] = true;
        map.remove('_updatedAt');
        await box.put(key, map);
        count++;
      } catch (e) {
        if (kDebugMode) debugPrint('[SyncService] push fail $colName/$key: $e');
      }
    }
    return count;
  }

  /// جلب عناصر السحابة إلى الصندوق المحلي
  static Future<int> _pullBox(Box box, String colName) async {
    int count = 0;
    final col = _col(colName);
    final snap = await col.get();
    for (final doc in snap.docs) {
      final remote = Map<String, dynamic>.from(doc.data());
      remote.remove('_updatedAt');
      remote['synced'] = true;
      final localKey = remote.remove('_localKey') ?? doc.id;

      final local = box.get(localKey);
      if (local is Map) {
        final localMap = Map<String, dynamic>.from(local);
        final localUpd = localMap['updatedAt']?.toString() ?? '';
        final remoteUpd = remote['updatedAt']?.toString() ?? '';
        // الأحدث يفوز
        if (localUpd.compareTo(remoteUpd) >= 0 && localMap['synced'] == true) {
          continue; // المحلي أحدث أو متساوٍ => تجاهل
        }
      }
      await box.put(localKey, remote);
      count++;
    }
    return count;
  }

  /// مسح آخر وقت مزامنة (لإجبار مزامنة كاملة)
  static Future<void> resetSyncMarker() =>
      AppDatabase.setSetting('lastSyncAt', '');

  static void logStatus() {
    if (kDebugMode) {
      debugPrint('[SyncService] cloud: $isCloudAvailable, company: $companyId');
    }
  }
}
