// ============================================================================
// очередь المزامنة — SyncQueue
// ----------------------------------------------------------------------------
// تحلّ متطلّبين أساسيين:
//   1) المزامنة الفورية (Real-time): كل عملية يحفظها أي مستخدم في أي جزء من
//      التطبيق تُدفع إلى السحابة فوراً (إن كان متصلاً)، فيراها بقية المستخدمين
//      مباشرة عبر قنوات RealtimeService.
//   2) المزامنة عند عودة الاتصال: إذا كان المستخدم غير متصل بالإنترنت، تُخزَّن
//      العملية في «قائمة انتظار» محلية دائمة، وتُزامَن تلقائياً بمجرّد عودة
//      الاتصال (دون أي تدخّل من المستخدم).
//
// التصميم:
//   • لا يعتمد على أي حزمة خارجية — يكشف الاتصال عبر نجاح/فشل عمليات Firestore.
//   • قائمة الانتظار مُخزّنة في Hive (تبقى بعد إغلاق التطبيق).
//   • مؤقّت دوري يعيد المحاولة حتى تنجح كل العمليات المعلّقة.
// ============================================================================
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'firebase_config.dart';
import 'sync_service.dart';

/// حالة عملية واحدة في قائمة الانتظار
class SyncOp {
  final String boxName; // اسم صندوق Hive
  final String key; // مفتاح العنصر
  final bool isDelete; // هل هي عملية حذف؟
  String enqueuedAt;
  int attempts;

  SyncOp({
    required this.boxName,
    required this.key,
    this.isDelete = false,
    String? enqueuedAt,
    this.attempts = 0,
  }) : enqueuedAt = enqueuedAt ?? DateTime.now().toIso8601String();

  /// مفتاح فريد داخل القائمة (صندوق + مفتاح) لمنع التكرار
  String get uid => '$boxName::$key';

  Map<String, dynamic> toMap() => {
    'boxName': boxName,
    'key': key,
    'isDelete': isDelete,
    'enqueuedAt': enqueuedAt,
    'attempts': attempts,
  };

  factory SyncOp.fromMap(Map<String, dynamic> m) => SyncOp(
    boxName: m['boxName'] as String? ?? '',
    key: m['key'] as String? ?? '',
    isDelete: m['isDelete'] as bool? ?? false,
    enqueuedAt: m['enqueuedAt'] as String?,
    attempts: (m['attempts'] as num?)?.toInt() ?? 0,
  );
}

class SyncQueue {
  static const String boxName = 'sync_queue';

  static Box? _box;
  static Timer? _timer;
  static bool _flushing = false;

  /// هل نعتبر الجهاز متصلاً؟ (آخر نتيجة دفع ناجحة/فاشلة)
  static bool _online = true;
  static bool get isOnline => _online;

  /// بوابة السحابة: تُعطَّل في وضع الزائر (محلي فقط).
  /// يضبطها SessionProvider عند الدخول/الخروج.
  static bool cloudEnabled = true;

  /// عدد العمليات المعلّقة (غير المُزامَنة)
  static int get pendingCount {
    try {
      return _box?.length ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// تنبيهات تغيّر طول القائمة (لعرض العدّاد في الواجهة)
  static final StreamController<int> _pendingCtl =
      StreamController<int>.broadcast();
  static Stream<int> get pendingStream => _pendingCtl.stream;
  static void _emitPending() {
    if (!_pendingCtl.isClosed) _pendingCtl.add(pendingCount);
  }

  static FirebaseFirestore? get _db {
    if (!FirebaseConfig.isConfigured) return null;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  /// تهيئة الصندوق (تُستدعى من main)
  static Future<void> initBox() async {
    if (!Hive.isBoxOpen(boxName)) {
      _box = await Hive.openBox(boxName);
    } else {
      _box = Hive.box(boxName);
    }
    _emitPending();
  }

  // --------------------------------------------------------------------------
  /// إضافة عملية إلى قائمة الانتظار (تُستدعى تلقائياً عند كل حفظ/حذف).
  static Future<void> enqueue(
    String box,
    String key, {
    bool isDelete = false,
  }) async {
    if (_box == null) return;
    // في وضع الزائر (محلي فقط) لا نُدرِج شيئاً في قائمة المزامنة.
    if (!cloudEnabled) return;
    try {
      final op = SyncOp(boxName: box, key: key, isDelete: isDelete);
      await _box!.put(op.uid, op.toMap());
      _emitPending();
      // حاول الدفع فوراً (real-time) دون انتظار
      unawaited(flush());
    } catch (e) {
      if (kDebugMode) debugPrint('[SyncQueue] enqueue fail: $e');
    }
  }

  /// كل العمليات المعلّقة
  static List<SyncOp> get pending {
    if (_box == null) return const [];
    try {
      return _box!.values
          .whereType<Map>()
          .map((m) => SyncOp.fromMap(Map<String, dynamic>.from(m)))
          .toList()
        ..sort((a, b) => a.enqueuedAt.compareTo(b.enqueuedAt));
    } catch (_) {
      return const [];
    }
  }

  static bool get hasPending => pendingCount > 0;

  // --------------------------------------------------------------------------
  /// دفع كل العمليات المعلّقة إلى السحابة.
  /// - ينجح → يحذفها من القائمة ويعلّم الجهاز متصلاً.
  /// - يفشل (غير متصل) → يتركها وتُعاد المحاولة لاحقاً.
  static Future<SyncResult> flush() async {
    final db = _db;
    if (db == null || _box == null || !cloudEnabled) {
      return SyncResult(status: SyncStatus.disabled, at: DateTime.now());
    }
    if (_flushing) {
      return SyncResult(status: SyncStatus.syncing, at: DateTime.now());
    }
    final ops = pending;
    if (ops.isEmpty) {
      _online = true;
      return SyncResult(status: SyncStatus.success, at: DateTime.now());
    }

    _flushing = true;
    int pushed = 0;
    String? lastError;
    try {
      final companyId = SyncService.companyId;
      final base = db.collection('companies').doc(companyId);

      for (final op in ops) {
        final colName = SyncService.syncBoxes[op.boxName];
        if (colName == null) {
          // صندوق غير قابل للمزامنة → أزِله من القائمة
          await _box!.delete(op.uid);
          continue;
        }
        try {
          if (op.isDelete) {
            await base.collection(colName).doc(op.key).delete();
          } else {
            final raw = Hive.isBoxOpen(op.boxName)
                ? Hive.box(op.boxName).get(op.key)
                : null;
            if (raw is! Map) {
              // العنصر اختفى محلياً → اعتبره محذوفاً
              await base.collection(colName).doc(op.key).delete();
            } else {
              final map = Map<String, dynamic>.from(raw);
              map['_localKey'] = op.key;
              map['_updatedAt'] = FieldValue.serverTimestamp();
              map['synced'] = true;
              await base
                  .collection(colName)
                  .doc(op.key)
                  .set(map, SetOptions(merge: true));
              // علّم محلياً بأنه تمّت مزامنته
              final clean = Map<String, dynamic>.from(map);
              clean.remove('_updatedAt');
              clean.remove('_localKey');
              await Hive.box(op.boxName).put(op.key, clean);
            }
          }
          await _box!.delete(op.uid);
          pushed++;
        } catch (e) {
          lastError = '$e';
          // عدّ المحاولة وواصل البقية
          final attempts = op.attempts + 1;
          await _box!.put(
            op.uid,
            (SyncOp(
              boxName: op.boxName,
              key: op.key,
              isDelete: op.isDelete,
              enqueuedAt: op.enqueuedAt,
              attempts: attempts,
            )).toMap(),
          );
        }
      }

      _online = lastError == null;
      _emitPending();

      if (lastError != null) {
        return SyncResult(
          status: SyncStatus.error,
          pushed: pushed,
          error: lastError,
          at: DateTime.now(),
        );
      }
      return SyncResult(
        status: SyncStatus.success,
        pushed: pushed,
        at: DateTime.now(),
      );
    } finally {
      _flushing = false;
      _emitPending();
    }
  }

  /// إشعار بأن الجهاز صار متصلاً (يُستدعى عند وصول أي بيانات من السحابة).
  static void markOnline() {
    if (!_online) {
      _online = true;
      // عودة الاتصال → زامن كل المعلّق فوراً
      unawaited(flush());
    }
  }

  /// تشغيل المؤقّت الدوري: يعيد محاولة دفع المعلّق كل 20 ثانية.
  static void startAutoFlush() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (hasPending) unawaited(flush());
    });
    // محاولة أولية
    unawaited(flush());
  }

  static void stopAutoFlush() {
    _timer?.cancel();
    _timer = null;
  }

  static void logStatus() {
    debugPrint(
      '[SyncQueue] pending=$pendingCount, online=$_online, flushing=$_flushing',
    );
  }

  /// تفريغ قائمة الانتظار (إعادة ضبط كاملة)
  static Future<void> clear() async {
    await _box?.clear();
    _emitPending();
  }
}
