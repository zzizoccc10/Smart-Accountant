// ============================================================================
// مركز الإشعارات — عرض كل التنبيهات الداخلية مع القراءة والفلترة والمسح
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../providers/session_provider.dart';
import '../../models/models.dart';
import '../../services/admin_notification_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _filter = 'all';
  bool _unreadOnly = false;

  static const _types = {
    'all': 'الكل',
    'admin': 'من الإدارة',
    'low_stock': 'نقص مخزون',
    'invoice_due': 'فواتير مستحقة',
    'credit_limit': 'حد ائتمان',
    'payment_due': 'دفعات مستحقة',
    'backup': 'نسخ احتياطي',
  };

  @override
  void initState() {
    super.initState();
    // توليد التنبيهات عند فتح الشاشة (بدون دفع إشعارات نظام)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ERPProvider>().generateAlerts(push: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final session = context.watch<SessionProvider>();
    final companyId = session.currentCompanyId;
    final userId = session.currentUser?.id ?? '';
    final adminItems = AdminNotificationService.forCompany(companyId,
        userId: userId);
    var list = prov.notifications;
    if (_filter != 'all') {
      list = list.where((n) => n.type == _filter).toList();
    }
    if (_unreadOnly) {
      list = list.where((n) => !n.isRead).toList();
    }

    final unread = prov.unreadNotifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مركز الإشعارات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'تحديد الكل كمقروء',
            onPressed: unread == 0
                ? null
                : () async => prov.markAllNotificationsRead(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'مسح كل الإشعارات',
            onPressed: () async {
              final ok = await confirmDialog(
                context,
                title: 'مسح الإشعارات',
                message: 'سيتم حذف كل الإشعارات نهائياً. متابعة؟',
              );
              if (ok) await prov.clearNotifications();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ملخص
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.primary.withValues(alpha: 0.06),
            child: Row(
              children: [
                const Icon(Icons.notifications_active,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'لديك $unread إشعار غير مقروء من إجمالي ${prov.notifications.length}',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                FilterChip(
                  label: const Text('غير المقروء فقط', style: TextStyle(fontSize: 11)),
                  selected: _unreadOnly,
                  onSelected: (v) => setState(() => _unreadOnly = v),
                ),
              ],
            ),
          ),
          // الفلاتر
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                for (final e in _types.entries)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      label: Text(e.value, style: const TextStyle(fontSize: 12)),
                      selected: _filter == e.key,
                      onSelected: (_) => setState(() => _filter = e.key),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: (_filter == 'admin')
                ? (adminItems.isEmpty
                    ? const EmptyState(
                        message: 'لا توجد إشعارات من إدارة النظام',
                        icon: Icons.campaign_outlined)
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: adminItems.length,
                        itemBuilder: (_, i) =>
                            _adminTile(adminItems[i], userId, companyId),
                      ))
                : (list.isEmpty
                    ? const EmptyState(
                        message: 'لا توجد إشعارات',
                        icon: Icons.notifications_off)
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _tile(prov, list[i]),
                      )),
          ),
        ],
      ),
    );
  }

  /// بطاقة إشعار إداري من مالك النظام
  Widget _adminTile(
      AdminNotification n, String userId, String companyId) {
    final reader = userId.isNotEmpty ? userId : companyId;
    final read = AdminNotificationService.isRead(n, reader);
    final (Color color, IconData icon) = switch (n.importance) {
      2 => (AppColors.danger, Icons.priority_high),
      1 => (AppColors.warning, Icons.campaign),
      _ => (AppColors.purple, Icons.campaign_outlined),
    };
    final dt = n.createdAt.replaceAll('T', ' ').split('.').first;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: read ? null : color.withValues(alpha: 0.06),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.14),
          child: Icon(icon, size: 18, color: color),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                n.title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: read ? FontWeight.normal : FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(n.importanceLabelAr,
                  style: TextStyle(fontSize: 9.5, color: color)),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(n.body, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 3),
            Text('$dt • ${n.senderName} • ${n.audienceLabelAr}',
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
          ],
        ),
        isThreeLine: true,
        trailing: read
            ? const Icon(Icons.done_all, size: 18, color: AppColors.success)
            : IconButton(
                icon: const Icon(Icons.check_circle_outline, size: 20),
                tooltip: 'تعليم كمقروء',
                onPressed: () async {
                  await AdminNotificationService.markRead(n.id, reader);
                  setState(() {});
                },
              ),
      ),
    );
  }

  Widget _tile(ERPProvider prov, AppNotification n) {
    final (IconData icon, Color color) = switch (n.type) {
      'low_stock' => (Icons.inventory_2, AppColors.warning),
      'invoice_due' => (Icons.receipt_long, AppColors.danger),
      'credit_limit' => (Icons.credit_card, AppColors.primary),
      'payment_due' => (Icons.payments, AppColors.info),
      'backup' => (Icons.backup, AppColors.success),
      _ => (Icons.notifications, Colors.grey),
    };
    final dt = n.createdAt.replaceAll('T', ' ').split('.').first;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: n.isRead ? null : color.withValues(alpha: 0.05),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.14),
          child: Icon(icon, size: 18, color: color),
        ),
        title: Text(
          n.title,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(n.body, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 3),
            Text('$dt • ${n.typeLabel}',
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
          ],
        ),
        isThreeLine: true,
        trailing: n.isRead
            ? null
            : IconButton(
                icon: const Icon(Icons.check_circle_outline, size: 20),
                tooltip: 'تعليم كمقروء',
                onPressed: () async => prov.markNotificationRead(n.id),
              ),
      ),
    );
  }
}
