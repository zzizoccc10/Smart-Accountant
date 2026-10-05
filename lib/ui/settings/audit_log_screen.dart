// ============================================================================
// سجل المراجعة — عرض كل العمليات الحساسة مع إمكانية الفلترة والتصدير
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/export_button.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  String _filterEntity = 'all';
  String _search = '';

  static const _entities = {
    'all': 'الكل',
    'invoice': 'الفواتير',
    'payment': 'السندات',
    'expense': 'المصروفات',
    'contact': 'الجهات',
    'item': 'الأصناف',
  };

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    var logs = prov.auditLogs;
    if (_filterEntity != 'all') {
      logs = logs.where((l) => l.entity == _filterEntity).toList();
    }
    if (_search.isNotEmpty) {
      logs = logs
          .where(
            (l) =>
                l.description.contains(_search) ||
                l.actionLabel.contains(_search),
          )
          .toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل المراجعة'),
        actions: [
          ExportButton(
            title: 'سجل المراجعة',
            companyName: prov.companyName,
            filename: 'audit_log',
            headers: const [
              'التاريخ',
              'الإجراء',
              'النوع',
              'التفاصيل',
              'المستخدم',
            ],
            rows: [
              for (final l in logs)
                [
                  l.date.replaceAll('T', ' ').split('.').first,
                  l.actionLabel,
                  l.entityLabel,
                  l.description,
                  l.userName,
                ],
            ],
            totals: ['عدد العمليات: ${logs.length}'],
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'مسح السجل',
            onPressed: () async {
              final ok = await confirmDialog(
                context,
                title: 'مسح السجل',
                message: 'سيتم حذف كل سجلات المراجعة نهائياً. متابعة؟',
              );
              if (ok) await prov.clearAuditLog();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // البحث
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'بحث في السجل...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          // الفلاتر
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final e in _entities.entries)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: _filterEntity == e.key,
                      onSelected: (_) => setState(() => _filterEntity = e.key),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: logs.isEmpty
                ? const EmptyState(
                    message: 'لا توجد سجلات',
                    icon: Icons.history,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: logs.length,
                    itemBuilder: (_, i) => _logTile(logs[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _logTile(AuditLog l) {
    final (IconData icon, Color color) = switch (l.action) {
      'create' => (Icons.add_circle, AppColors.success),
      'update' => (Icons.edit, AppColors.info),
      'delete' => (Icons.delete, AppColors.danger),
      'post' => (Icons.check_circle, AppColors.primary),
      _ => (Icons.info, Colors.grey),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, size: 18, color: color),
        ),
        title: Text(
          l.description.isEmpty ? l.entityLabel : l.description,
          style: const TextStyle(fontSize: 13),
        ),
        subtitle: Text(
          '${l.date.replaceAll('T', ' ').split('.').first} • ${l.actionLabel}',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        trailing: Badge2(l.entityLabel, color: color),
      ),
    );
  }
}
