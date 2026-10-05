// ============================================================================
// خدمة المزامنة الفورية — RealtimeService
// ----------------------------------------------------------------------------
// تفتح قنوات Firestore الفورية (snapshots) لكل مجموعات المنشأة النشطة، وتطبّق
// أي تغيير قادم من أي مستخدم متصل بالإنترنت إلى التخزين المحلي فوراً، ثم
// تُنبّه الواجهات لإعادة التحميل (100% real-time، بلا انتظار مزامنة يدوية).
//
//   • تبدأ عند الدخول كمنشأة (وتتوقف عند الخروج).
//   • تستمع أيضاً لمجموعة 'broadcasts' الخاصة بإشعارات مالك النظام.
//   • محصّنة بالكامل: أي خطأ لا يُسقط التطبيق.
// ============================================================================
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/control_models.dart';
import 'admin_notification_service.dart';
import 'control_service.dart';
import 'firebase_config.dart';
import 'sync_queue.dart';
import 'sync_service.dart';

class RealtimeService {
  static final StreamController<void> _changes =
      StreamController<void>.broadcast();

  /// تيّار يُطلق عند وصول أي تغيير من السحابة (لإعادة تحميل الواجهات)
  static Stream<void> get changes => _changes.stream;

  static final List<StreamSubscription> _subs = [];
  static String? _companyId;
  static bool _running = false;

  static bool get isRunning => _running;

  static FirebaseFirestore? get _db {
    if (!FirebaseConfig.isConfigured) return null;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  static bool get isAvailable => _db != null;

  // --------------------------------------------------------------------------
  /// بدء المراقبة الفورية لمنشأة معيّنة
  static Future<void> start(String companyId) async {
    final db = _db;
    if (db == null || companyId.isEmpty) return;
    if (_running && _companyId == companyId) return;

    await stop();
    _companyId = companyId;
    _running = true;

    // 1) كل مجموعات بيانات المنشأة
    for (final entry in SyncService.syncBoxes.entries) {
      final boxKey = entry.key;
      final colName = entry.value;
      try {
        final sub = db
            .collection('companies')
            .doc(companyId)
            .collection(colName)
            .snapshots()
            .listen(
              (snap) => _applySnapshot(boxKey, snap),
              onError: (e) =>
                  debugPrint('[Realtime] $colName stream error: $e'),
              cancelOnError: false,
            );
        _subs.add(sub);
      } catch (e) {
        debugPrint('[Realtime] $colName subscribe fail: $e');
      }
    }

    // 2) إشعارات مالك النظام (بث إداري)
    try {
      final sub = db
          .collection('broadcasts')
          .snapshots()
          .listen(
            (snap) async {
              final list = <AdminNotification>[];
              for (final doc in snap.docs) {
                final map = Map<String, dynamic>.from(doc.data());
                map.remove('serverAt');
                map['synced'] = true;
                map.putIfAbsent('id', () => doc.id);
                list.add(AdminNotification.fromMap(map));
              }
              await AdminNotificationService.applyCloudList(list);
              _emit();
            },
            onError: (e) => debugPrint('[Realtime] broadcasts error: $e'),
            cancelOnError: false,
          );
      _subs.add(sub);
    } catch (e) {
      debugPrint('[Realtime] broadcasts subscribe fail: $e');
    }

    // 3) سجل المستخدمين (للمزامنة الفورية للمستخدمين بين الأجهزة)
    try {
      final sub = db
          .collection('companies')
          .doc(companyId)
          .collection('users')
          .snapshots()
          .listen(
            (snap) => _applySnapshot('users', snap),
            onError: (e) => debugPrint('[Realtime] users error: $e'),
            cancelOnError: false,
          );
      _subs.add(sub);
    } catch (_) {}

    // 4) إعدادات الوصول إلى لوحة المالك (توجيه موحّد لكل الأجهزة)
    try {
      final sub = db
          .collection('app_admin')
          .doc('owner_config')
          .snapshots()
          .listen(
            (doc) {
              final data = doc.data();
              if (data == null) return;
              final map = Map<String, dynamic>.from(data);
              map.remove('updatedAt');
              ControlService.applyCloudOwnerConfig(OwnerConfig.fromMap(map));
              _emit();
            },
            onError: (e) => debugPrint('[Realtime] owner_config error: $e'),
            cancelOnError: false,
          );
      _subs.add(sub);
    } catch (e) {
      debugPrint('[Realtime] owner_config subscribe fail: $e');
    }

    debugPrint('[Realtime] started for $companyId (${_subs.length} channels)');
  }

  /// مراقبة إعدادات المالك فقط (لمالك النظام — بلا منشأة).
  static Future<void> startOwnerConfigWatch() async {
    final db = _db;
    if (db == null) return;
    if (_subs.isNotEmpty) return;
    _running = true;
    try {
      final sub = db
          .collection('app_admin')
          .doc('owner_config')
          .snapshots()
          .listen(
            (doc) {
              final data = doc.data();
              if (data == null) return;
              final map = Map<String, dynamic>.from(data);
              map.remove('updatedAt');
              ControlService.applyCloudOwnerConfig(OwnerConfig.fromMap(map));
              _emit();
            },
            onError: (e) => debugPrint('[Realtime] owner_config error: $e'),
            cancelOnError: false,
          );
      _subs.add(sub);
    } catch (_) {}
  }

  /// إيقاف كل القنوات
  static Future<void> stop() async {
    for (final s in _subs) {
      try {
        await s.cancel();
      } catch (_) {}
    }
    _subs.clear();
    _running = false;
    _companyId = null;
  }

  // --------------------------------------------------------------------------
  /// تطبيق لقطة Firestore على صندوق Hive المحلي (الأحدث يفوز)
  static Future<void> _applySnapshot(
    String boxKey,
    QuerySnapshot<Map<String, dynamic>> snap,
  ) async {
    try {
      // وصول بيانات من السحابة ⇒ الجهاز متصل ⇒ أفرِغ قائمة المزامنة المعلّقة.
      SyncQueue.markOnline();
      if (!Hive.isBoxOpen(boxKey)) return;
      final box = Hive.box(boxKey);
      var changed = false;

      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.removed) {
          final localKey = change.doc.id;
          if (box.containsKey(localKey)) {
            await box.delete(localKey);
            changed = true;
          }
          continue;
        }
        final remote = Map<String, dynamic>.from(
          change.doc.data() ?? <String, dynamic>{},
        );
        remote.remove('_updatedAt');
        remote['synced'] = true;
        final localKey = remote.remove('_localKey') ?? change.doc.id;

        final local = box.get(localKey);
        if (local is Map) {
          final localMap = Map<String, dynamic>.from(local);
          final localUpd = localMap['updatedAt']?.toString() ?? '';
          final remoteUpd = remote['updatedAt']?.toString() ?? '';
          // لا تدهس تعديلاً محلياً أحدث
          if (localUpd.isNotEmpty &&
              remoteUpd.isNotEmpty &&
              localUpd.compareTo(remoteUpd) > 0) {
            continue;
          }
        }
        await box.put(localKey, remote);
        changed = true;
      }

      if (changed) _emit();
    } catch (e) {
      debugPrint('[Realtime] apply $boxKey fail: $e');
    }
  }

  static void _emit() {
    if (!_changes.isClosed) _changes.add(null);
  }

  static void logStatus() {
    debugPrint(
      '[Realtime] running=$_running, company=$_companyId, '
      'channels=${_subs.length}',
    );
  }
}
