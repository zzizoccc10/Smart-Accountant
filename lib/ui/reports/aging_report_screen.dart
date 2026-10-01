// ============================================================================
// تقرير أعمار الديون
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

class AgingReportScreen extends StatelessWidget {
  const AgingReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final curr = prov.currency;

    // أعمار الذمم من الفواتير الآجلة
    final now = DateTime.now();
    final buckets = <String, double>{
      '0-30 يوم': 0,
      '31-60 يوم': 0,
      '61-90 يوم': 0,
      'أكثر من 90 يوم': 0,
    };
    final customerRows = <Map<String, dynamic>>[];

    for (final c in prov.contacts.where((c) => c.contactType != 'supplier')) {
      final bal = prov.contactBalance(c.id);
      if (bal <= 0.01) continue;
      double overdue = 0;
      for (final inv in prov.invoices) {
        if (inv.contactId != c.id ||
            inv.invoiceType != 'sale' ||
            inv.paymentType != 'credit') {
          continue;
        }
        final days = now.difference(DateTime.parse(inv.date)).inDays;
        overdue += inv.remaining;
        if (days <= 30) {
          buckets['0-30 يوم'] = buckets['0-30 يوم']! + inv.remaining;
        } else if (days <= 60) {
          buckets['31-60 يوم'] = buckets['31-60 يوم']! + inv.remaining;
        } else if (days <= 90) {
          buckets['61-90 يوم'] = buckets['61-90 يوم']! + inv.remaining;
        } else {
          buckets['أكثر من 90 يوم'] =
              buckets['أكثر من 90 يوم']! + inv.remaining;
        }
      }
      customerRows.add({'name': c.name, 'balance': bal, 'overdue': overdue});
    }

    final colors = [
      AppColors.success,
      AppColors.info,
      AppColors.warning,
      AppColors.danger,
    ];
    final keys = buckets.keys.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('أعمار الديون')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const SectionTitle('توزيع الذمم حسب العمر', icon: Icons.hourglass_bottom),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (int i = 0; i < keys.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: colors[i],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(keys[i],
                                  style: const TextStyle(fontSize: 13))),
                          Text(
                            Fmt.money(buckets[keys[i]]!, curr),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('ذمم العملاء', icon: Icons.people),
          if (customerRows.isEmpty)
            const EmptyState(
                message: 'لا توجد ذمم مدينة', icon: Icons.people_outline)
          else
            Card(
              child: Column(
                children: [
                  for (final r in customerRows)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.person, color: AppColors.info),
                      title: Text(r['name'] as String,
                          style: const TextStyle(fontSize: 13)),
                      trailing: Text(
                        Fmt.money(r['balance'] as double, curr),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.danger,
                            fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
