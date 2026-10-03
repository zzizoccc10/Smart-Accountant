// ============================================================================
// شاشة المزامنة — SyncScreen
// ----------------------------------------------------------------------------
// • عرض حالة الاتصال السحابي (Firebase).
// • زر "مزامنة الآن" يدوي + عرض آخر مزامنة والنتائج.
// • تشخيص سريع: هل الإعدادات مرفوعة؟ هل المصادقة متاحة؟
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/session_provider.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_config.dart';
import '../../services/push_notifications.dart';
import '../../services/sync_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';

class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final cloud = FirebaseConfig.isConfigured;

    return Scaffold(
      appBar: AppBar(
        title: const Text('المزامنة السحابية'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // بطاقة الحالة
          Card(
            color: cloud ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        cloud ? Icons.cloud_done : Icons.cloud_off,
                        color: cloud ? Colors.green : Colors.orange,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cloud
                                  ? 'السحابة مُفعّلة'
                                  : 'السحابة غير مُفعّلة',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              cloud
                                  ? 'مشروع: ${FirebaseConfig.projectId}'
                                  : 'ارفع google-services.json لتفعيل المزامنة',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // زر المزامنة
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: cloud && session.syncStatus != SyncStatus.syncing
                  ? () => session.syncNow()
                  : null,
              icon: session.syncStatus == SyncStatus.syncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.sync),
              label: Text(
                session.syncStatus == SyncStatus.syncing
                    ? 'جارٍ المزامنة...'
                    : 'مزامنة الآن',
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // معلومات آخر مزامنة
          _infoCard(context, session),

          const SizedBox(height: 16),
          const Text('تشخيص الاتصال',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          _diagRow('إعدادات Firebase', cloud),
          _diagRow('مصادقة Firebase', AuthService.isCloudAvailable),
          _diagRow('Firestore', SyncService.isCloudAvailable),
          _diagRow('الإشعارات (FCM)', PushNotifications.isAvailable),
          _diagRow('مستخدمون محليون', UserService.hasUsers),
          const SizedBox(height: 16),

          // شرح
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('كيف تُفعّل المزامنة؟',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  SizedBox(height: 8),
                  Text(
                    '1. أنشئ مشروع Firebase وأضف تطبيق أندرويد بمعرّف:\n'
                    '   com.easyaccountant.erp\n'
                    '2. نزّل ملف google-services.json.\n'
                    '3. ارفعه إلى المنصة — سيُفعّل الربط تلقائياً.\n'
                    '4. فعّل Authentication (Email/Password) و Firestore.',
                    style: TextStyle(fontSize: 13, height: 1.6),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(BuildContext context, SessionProvider session) {
    final last = session.lastSync;
    final res = session.lastSyncResult;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, size: 20),
                const SizedBox(width: 8),
                Text(
                  'آخر مزامنة: ${last == null ? "لم تتم بعد" : _fmt(last)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (res != null) ...[
              const SizedBox(height: 8),
              Text(
                'الحالة: ${_statusLabel(res.status)}',
                style: const TextStyle(fontSize: 13),
              ),
              Text(
                'تم رفع: ${res.pushed} • تم جلب: ${res.pulled}',
                style: const TextStyle(fontSize: 13),
              ),
              if (res.error != null)
                Text(
                  'ملاحظة: ${res.error}',
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _diagRow(String label, bool ok) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.cancel,
              size: 18, color: ok ? Colors.green : Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(ok ? 'متاح' : 'غير متاح',
              style: TextStyle(
                  fontSize: 12, color: ok ? Colors.green : Colors.red)),
        ],
      ),
    );
  }

  String _statusLabel(SyncStatus s) {
    switch (s) {
      case SyncStatus.idle:
        return 'خامل';
      case SyncStatus.syncing:
        return 'جارٍ...';
      case SyncStatus.success:
        return 'نجحت ✓';
      case SyncStatus.error:
        return 'خطأ';
      case SyncStatus.disabled:
        return 'غير مُفعّلة';
    }
  }

  String _fmt(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/'
      '${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}
