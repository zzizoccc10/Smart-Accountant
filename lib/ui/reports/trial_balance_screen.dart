// ============================================================================
// ميزان المراجعة
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../services/print_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

class TrialBalanceScreen extends StatelessWidget {
  const TrialBalanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final bals = prov.accountBalances();

    // الحسابات الفرعية التي لها حركة
    final rows = <Map<String, dynamic>>[];
    double totalDebit = 0, totalCredit = 0;
    for (final a in prov.accounts.where((a) => a.isLeaf)) {
      final b = bals[a.id];
      if (b == null) continue;
      final d = b['debit'] ?? 0;
      final c = b['credit'] ?? 0;
      if (d == 0 && c == 0) continue;
      final net = d - c;
      rows.add({
        'code': a.code,
        'name': a.name,
        'debit': net > 0 ? net : 0.0,
        'credit': net < 0 ? -net : 0.0,
      });
      if (net > 0) totalDebit += net;
      if (net < 0) totalCredit += -net;
    }
    rows.sort((a, b) => (a['code'] as String).compareTo(b['code'] as String));

    return Scaffold(
      appBar: AppBar(
        title: const Text('ميزان المراجعة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'تصدير PDF',
            onPressed: () => PrintService.printTable(
              title: 'ميزان المراجعة',
              companyName: prov.companyName,
              headers: ['الرمز', 'الحساب', 'مدين', 'دائن'],
              rows: [
                for (final r in rows)
                  [
                    r['code'] as String,
                    r['name'] as String,
                    (r['debit'] as double) > 0
                        ? Fmt.num(r['debit'] as double)
                        : '-',
                    (r['credit'] as double) > 0
                        ? Fmt.num(r['credit'] as double)
                        : '-',
                  ],
              ],
              totals: [
                'إجمالي المدين: ${Fmt.num(totalDebit)}',
                'إجمالي الدائن: ${Fmt.num(totalCredit)}',
              ],
            ),
          ),
        ],
      ),
      body: rows.isEmpty
          ? const EmptyState(
              message: 'لا توجد حركات لعرض الميزان',
              icon: Icons.balance,
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: AppColors.primary.withValues(alpha: 0.06),
                        child: const Row(
                          children: [
                            Expanded(
                                flex: 3,
                                child: Text('الحساب',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            Expanded(
                                child: Text('مدين',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            Expanded(
                                child: Text('دائن',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ),
                      for (final r in rows)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text('${r['code']} — ${r['name']}',
                                    style: const TextStyle(fontSize: 12)),
                              ),
                              Expanded(
                                child: Text(
                                  (r['debit'] as double) > 0
                                      ? Fmt.num(r['debit'] as double)
                                      : '-',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  (r['credit'] as double) > 0
                                      ? Fmt.num(r['credit'] as double)
                                      : '-',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Expanded(
                                flex: 3,
                                child: Text('الإجمالي',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            Expanded(
                              child: Text(
                                Fmt.num(totalDebit),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                Fmt.num(totalCredit),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary),
                              ),
                            ),
                          ],
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
