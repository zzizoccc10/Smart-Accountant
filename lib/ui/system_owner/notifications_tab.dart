// ============================================================================
// تبويب الإشعارات — NotificationsTab (لوحة مالك النظام)
// ----------------------------------------------------------------------------
// مالك النظام يرسل إشعارات إلى الجميع/منشآت/مستخدمين، ويستعرض ما أرسله.
// ============================================================================
import 'package:flutter/material.dart';

import '../../services/admin_notification_service.dart';
import '../../services/control_service.dart';
import '../../theme/app_theme.dart';
import 'broadcast_compose_sheet.dart';
import 'widgets.dart';

class NotificationsTab extends StatefulWidget {
  const NotificationsTab({super.key});

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    if (ControlService.isCloudAvailable) {
      AdminNotificationService.pullFromCloud().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  List<AdminNotification> get _filtered {
    final all = AdminNotificationService.all();
    if (_filter == 'ALL') return all;
    return all.where((n) => n.audience == _filter).toList();
  }

  Future<void> _compose() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const BroadcastComposeSheet(),
    );
    if (ok == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال الإشعار بنجاح'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    final total = AdminNotificationService.all().length;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _compose,
        backgroundColor: AppColors.purple,
        icon: const Icon(Icons.campaign),
        label: const Text('إشعار جديد'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Row(
              children: [
                BadgeChip(
                  '$total إشعار',
                  AppColors.purple,
                  icon: Icons.campaign,
                ),
                const Spacer(),
              ],
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _chip('الكل', 'ALL'),
                _chip('للجميع', 'all'),
                _chip('منشآت', 'companies'),
                _chip('مستخدمون', 'users'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(
                    Icons.campaign_outlined,
                    'لم تُرسل أي إشعارات بعد',
                    hint:
                        'استخدم زر «إشعار جديد» لإرسال تنبيه إلى كل '
                        'المستخدمين أو إلى منشآت/مستخدمين محدّدين.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 80),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _card(list[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    final on = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: on,
        selectedColor: AppColors.purple.withValues(alpha: 0.18),
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }

  Widget _card(AdminNotification n) {
    final (Color color, IconData icon) = switch (n.importance) {
      2 => (AppColors.danger, Icons.priority_high),
      1 => (AppColors.warning, Icons.campaign),
      _ => (AppColors.purple, Icons.campaign_outlined),
    };

    String targets;
    if (n.audience == 'companies') {
      final names = n.targetCompanies
          .map((id) => ControlService.companyById(id)?.companyName ?? id)
          .take(3)
          .join('، ');
      targets = '$names${n.targetCompanies.length > 3 ? "…" : ""}';
    } else if (n.audience == 'users') {
      targets = '${n.targetUsers.length} مستخدم';
    } else {
      targets = 'الجميع';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: color.withValues(alpha: 0.14),
                  child: Icon(icon, size: 17, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    n.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'حذف',
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 19,
                    color: AppColors.danger,
                  ),
                  onPressed: () async {
                    await AdminNotificationService.delete(n.id);
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(n.body, style: const TextStyle(fontSize: 12.5)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                BadgeChip(
                  'للـ ${n.audienceLabelAr}',
                  AppColors.indigo,
                  icon: Icons.group,
                ),
                BadgeChip(targets, AppColors.teal, icon: Icons.list_alt),
                BadgeChip(n.importanceLabelAr, color, icon: Icons.flag),
                BadgeChip(
                  'قرأه ${n.readBy.length}',
                  AppColors.info,
                  icon: Icons.check_circle_outline,
                ),
                BadgeChip(
                  timeAgo(n.createdAt),
                  Colors.blueGrey,
                  icon: Icons.schedule,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
