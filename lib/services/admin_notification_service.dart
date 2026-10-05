// ============================================================================
// خدمة إشعارات مالك النظام — AdminNotificationService
// ----------------------------------------------------------------------------
// تتيح لمالك النظام إرسال إشعارات إلى:
//   • الجميع (كل المستخدمين والمنشآت)   → audience = 'all'
//   • منشآت محدّدة                       → audience = 'companies'
//   • مستخدمين محدّدين                   → audience = 'users'
// تُخزَّن محلياً (Hive: 'admin_notifications') وتُزامَن سحابياً
// (Firestore: 'broadcasts') كي يستقبلها كل المستخدمين المتصلين فورياً.
// كل مستخدم يملك صندوق قراءة (read) خاصاً به لتتبّع غير المقروء.
// ============================================================================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'firebase_config.dart';

/// هدف الإشعار
enum NotifyAudience { all, companies, users }

extension NotifyAudienceX on NotifyAudience {
  String get key => name;
  String get labelAr {
    switch (this) {
      case NotifyAudience.all:
        return 'الجميع';
      case NotifyAudience.companies:
        return 'منشآت محدّدة';
      case NotifyAudience.users:
        return 'مستخدمون محدّدون';
    }
  }
}

/// إشعار إداري
class AdminNotification {
  final String id;
  String title;
  String body;
  String audience; // all | companies | users
  List<String> targetCompanies; // معرّفات المنشآت
  List<String> targetUsers; // معرّفات المستخدمين
  int importance; // 0 عادي، 1 مهم، 2 عاجل
  String createdAt;
  String senderName;
  bool synced;
  List<String> readBy; // معرّفات المستخدمين الذين قرأوه

  AdminNotification({
    required this.id,
    required this.title,
    required this.body,
    this.audience = 'all',
    List<String>? targetCompanies,
    List<String>? targetUsers,
    this.importance = 0,
    String? createdAt,
    this.senderName = 'إدارة النظام',
    this.synced = false,
    List<String>? readBy,
  }) : targetCompanies = targetCompanies ?? [],
       targetUsers = targetUsers ?? [],
       readBy = readBy ?? [],
       createdAt = createdAt ?? DateTime.now().toIso8601String();

  String get audienceLabelAr => NotifyAudience.values
      .firstWhere((a) => a.key == audience, orElse: () => NotifyAudience.all)
      .labelAr;

  String get importanceLabelAr {
    switch (importance) {
      case 2:
        return 'عاجل';
      case 1:
        return 'مهم';
      default:
        return 'عادي';
    }
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'body': body,
    'audience': audience,
    'targetCompanies': targetCompanies,
    'targetUsers': targetUsers,
    'importance': importance,
    'createdAt': createdAt,
    'senderName': senderName,
    'synced': synced,
    'readBy': readBy,
  };

  factory AdminNotification.fromMap(Map<String, dynamic> m) =>
      AdminNotification(
        id: m['id'].toString(),
        title: m['title'] as String? ?? '',
        body: m['body'] as String? ?? '',
        audience: m['audience'] as String? ?? 'all',
        targetCompanies: ((m['targetCompanies'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        targetUsers: ((m['targetUsers'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        importance: (m['importance'] as num?)?.toInt() ?? 0,
        createdAt: m['createdAt'] as String?,
        senderName: m['senderName'] as String? ?? 'إدارة النظام',
        synced: m['synced'] as bool? ?? false,
        readBy: ((m['readBy'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );

  Map<String, dynamic> toCloud() => {
    'id': id,
    'title': title,
    'body': body,
    'audience': audience,
    'targetCompanies': targetCompanies,
    'targetUsers': targetUsers,
    'importance': importance,
    'createdAt': createdAt,
    'senderName': senderName,
    'serverAt': FieldValue.serverTimestamp(),
  };
}

class AdminNotificationService {
  static const boxName = 'admin_notifications';

  static Box get _box => Hive.box(boxName);

  static FirebaseFirestore? get _db {
    if (!FirebaseConfig.isConfigured) return null;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  static Future<void> initBox() async {
    if (!Hive.isBoxOpen(boxName)) await Hive.openBox(boxName);
  }

  // ---------------------------- القراءة ----------------------------
  static List<AdminNotification> all() {
    try {
      final list =
          _box.values
              .whereType<Map>()
              .map(
                (m) => AdminNotification.fromMap(Map<String, dynamic>.from(m)),
              )
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  static AdminNotification? byId(String id) {
    final m = _box.get(id);
    if (m is Map) {
      return AdminNotification.fromMap(Map<String, dynamic>.from(m));
    }
    return null;
  }

  /// هل يستهدف الإشعار هذا السياق (منشأة/مستخدم)؟
  static bool matches(
    AdminNotification n, {
    required String companyId,
    String userId = '',
  }) {
    switch (n.audience) {
      case 'all':
        return true;
      case 'companies':
        return companyId.isNotEmpty && n.targetCompanies.contains(companyId);
      case 'users':
        return userId.isNotEmpty && n.targetUsers.contains(userId);
      default:
        return true;
    }
  }

  /// إشعارات موجّهة للمستخدم/المنشأة الحالية (الأحدث أولاً)
  static List<AdminNotification> forCompany(
    String companyId, {
    String userId = '',
  }) {
    return all()
        .where((n) => matches(n, companyId: companyId, userId: userId))
        .toList();
  }

  static bool isRead(AdminNotification n, String readerId) =>
      readerId.isNotEmpty && n.readBy.contains(readerId);

  static int unreadCount(String companyId, {String userId = ''}) {
    final reader = userId.isNotEmpty ? userId : companyId;
    return forCompany(
      companyId,
      userId: userId,
    ).where((n) => !isRead(n, reader)).length;
  }

  // ---------------------------- الكتابة ----------------------------
  /// إنشاء/إرسال إشعار جديد
  static Future<AdminNotification> send({
    required String title,
    required String body,
    NotifyAudience audience = NotifyAudience.all,
    List<String> targetCompanies = const [],
    List<String> targetUsers = const [],
    int importance = 0,
    String senderName = 'إدارة النظام',
  }) async {
    final n = AdminNotification(
      id: 'an_${DateTime.now().microsecondsSinceEpoch}',
      title: title.trim(),
      body: body.trim(),
      audience: audience.key,
      targetCompanies: targetCompanies,
      targetUsers: targetUsers,
      importance: importance,
      senderName: senderName,
    );
    await _box.put(n.id, n.toMap());
    await _pushToCloud(n);
    return n;
  }

  static Future<void> delete(String id) async {
    await _box.delete(id);
    try {
      await _db?.collection('broadcasts').doc(id).delete();
    } catch (_) {}
  }

  /// تعليم إشعار كمقروء لمستخدم/منشأة
  static Future<void> markRead(String id, String readerId) async {
    final n = byId(id);
    if (n == null || readerId.isEmpty) return;
    if (n.readBy.contains(readerId)) return;
    n.readBy.add(readerId);
    n.synced = false;
    await _box.put(id, n.toMap());
  }

  static Future<void> markAllRead(
    String companyId, {
    String userId = '',
  }) async {
    final reader = userId.isNotEmpty ? userId : companyId;
    if (reader.isEmpty) return;
    for (final n in forCompany(companyId, userId: userId)) {
      if (!n.readBy.contains(reader)) {
        n.readBy.add(reader);
        await _box.put(n.id, n.toMap());
      }
    }
  }

  static Future<void> clearAll() => _box.clear();

  // ---------------------------- السحابة ----------------------------
  static Future<void> _pushToCloud(AdminNotification n) async {
    final db = _db;
    if (db == null) return;
    try {
      await db
          .collection('broadcasts')
          .doc(n.id)
          .set(n.toCloud(), SetOptions(merge: true));
      await _box.put(n.id, n.copyWithSynced().toMap());
    } catch (e) {
      if (kDebugMode) debugPrint('[AdminNotification] push fail: $e');
    }
  }

  /// جلب الإشعارات من السحابة (يُستدعى عند الدخول) + البث الفوري
  static Future<int> pullFromCloud() async {
    final db = _db;
    if (db == null) return 0;
    int count = 0;
    try {
      final snap = await db.collection('broadcasts').get();
      for (final doc in snap.docs) {
        final map = Map<String, dynamic>.from(doc.data());
        map.remove('serverAt');
        map['synced'] = true;
        map.putIfAbsent('id', () => doc.id);
        map.putIfAbsent('readBy', () => []);
        // نحافظ على قائمة القراءة المحلية (لا نستبدلها)
        final local = _box.get(map['id']);
        if (local is Map) {
          map['readBy'] = Map<String, dynamic>.from(local)['readBy'] ?? [];
        }
        await _box.put(map['id'], map);
        count++;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AdminNotification] pull fail: $e');
    }
    return count;
  }

  /// بث فوري (stream) لإشعارات السحابة — للمزامنة real-time
  static Stream<List<AdminNotification>> watchCloud() {
    final db = _db;
    if (db == null) return const Stream.empty();
    return db.collection('broadcasts').snapshots().map((snap) {
      final list = <AdminNotification>[];
      for (final doc in snap.docs) {
        final map = Map<String, dynamic>.from(doc.data());
        map.remove('serverAt');
        map['synced'] = true;
        map.putIfAbsent('id', () => doc.id);
        list.add(AdminNotification.fromMap(map));
      }
      return list;
    });
  }

  /// استقبال إشعارات البث: تُخزَّن محلياً (مع الحفاظ على حالة القراءة)
  static Future<void> applyCloudList(List<AdminNotification> remote) async {
    for (final n in remote) {
      final local = _box.get(n.id);
      final readBy = local is Map
          ? ((Map<String, dynamic>.from(local)['readBy'] as List?) ?? const [])
                .map((e) => e.toString())
                .toList()
          : <String>[];
      n.readBy = readBy;
      n.synced = true;
      await _box.put(n.id, n.toMap());
    }
  }

  static void logStatus() {
    if (kDebugMode) {
      debugPrint(
        '[AdminNotification] total: ${_box.length}, '
        'cloud: ${_db != null}',
      );
    }
  }
}

extension _AdminNotifCopy on AdminNotification {
  AdminNotification copyWithSynced() => AdminNotification(
    id: id,
    title: title,
    body: body,
    audience: audience,
    targetCompanies: targetCompanies,
    targetUsers: targetUsers,
    importance: importance,
    createdAt: createdAt,
    senderName: senderName,
    synced: true,
    readBy: readBy,
  );
}
