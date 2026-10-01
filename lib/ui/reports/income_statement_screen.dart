// ============================================================================
// قائمة الأرباح والخسائر
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../widgets/export_button.dart';
import '../../theme/app_theme.dart';

class IncomeStatementScreen extends StatelessWidget {
  const IncomeStatementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final curr = prov.currency;
    final bals = prov.accountBalances();

    double revenueTotal = 0, expenseTotal = 0, cogsTotal = 0;
    final revenues = <Map<String, dynamic>>[];
    final expenses = <Map<String, dynamic>>[];

    for (final a in prov.accounts.where((a) => a.isLeaf)) {
      final b = bals[a.id];
      if (b == null) continue;
      final d = b['debit'] ?? 0;
      final c = b['credit'] ?? 0;

      if (a.accountType == 'revenue') {
        // الإيرادات طبيعتها دائن، والمردودات مدين
        final amount = a.accountNature == 'credit' ? (c - d) : (d - c);
        if (amount.abs() < 0.001) continue;
        revenues.add({'name': a.name, 'amount': amount});
        revenueTotal += amount;
      } else if (a.accountType == 'expense') {
        final amount = d - c;
        if (amount.abs() < 0.001) continue;
        if (a.code == '5-1') {
          cogsTotal += amount;
        } else {
          expenses.add({'name': a.name, 'amount': amount});
        }
        expenseTotal += amount;
      }
    }

    final grossProfit = revenueTotal - cogsTotal;
    final netProfit = revenueTotal - expenseTotal;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الأرباح والخسائر'),
        actions: [
          ExportButton(
            title: 'قائمة الأرباح والخسائر',
            companyName: prov.companyName,
            filename: 'income_statement',
            headers: ['البند', 'المبلغ ($curr)'],
            rows: [
              for (final r in revenues)
                [r['name'] as String, Fmt.num(r['amount'] as double)],
              ['إجمالي الإيرادات', Fmt.num(revenueTotal)],
              ['تكلفة المبيعات (COGS)', Fmt.num(cogsTotal)],
              ['إجمالي الربح', Fmt.num(grossProfit)],
              for (final e in expenses)
                [e['name'] as String, Fmt.num(e['amount'] as double)],
              ['إجمالي المصروفات', Fmt.num(expenseTotal)],
            ],
            totals: [
              netProfit >= 0
                  ? 'صافي الربح: ${Fmt.money(netProfit, curr)}'
                  : 'صافي الخسارة: ${Fmt.money(netProfit.abs(), curr)}',
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // الإيرادات
                  const _Header('الإيرادات', AppColors.success),
                  for (final r in revenues)
                    _row(r['name'] as String, r['amount'] as double, curr),
                  _row('إجمالي الإيرادات', revenueTotal, curr, bold: true),
                  const Divider(height: 24),
                  // تكلفة المبيعات
                  const _Header('تكلفة المبيعات', AppColors.warning),
                  _row('تكلفة المبيعات (COGS)', cogsTotal, curr),
                  _row('إجمالي الربح', grossProfit, curr, bold: true),
                  const Divider(height: 24),
                  // المصروفات
                  const _Header('المصروفات العمومية', AppColors.danger),
                  for (final e in expenses)
                    _row(e['name'] as String, e['amount'] as double, curr),
                  _row('إجمالي المصروفات', expenseTotal, curr, bold: true),
                  const Divider(height: 24),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: (netProfit >= 0 ? AppColors.success : AppColors.danger)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(
                          netProfit >= 0 ? 'صافي الربح' : 'صافي الخسارة',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(
                          Fmt.money(netProfit.abs(), curr),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: netProfit >= 0
                                ? AppColors.success
                                : AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, double amount, String curr, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            Fmt.money(amount, curr),
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final Color color;
  const _Header(this.title, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
