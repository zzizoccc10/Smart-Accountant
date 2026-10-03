// ============================================================================
// المركز المالي (الميزانية العمومية)
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../widgets/export_button.dart';
import '../../theme/app_theme.dart';

class BalanceSheetScreen extends StatelessWidget {
  const BalanceSheetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final curr = prov.currency;
    final bals = prov.accountBalances();

    final assets = <Map<String, dynamic>>[];
    final liabilities = <Map<String, dynamic>>[];
    final equity = <Map<String, dynamic>>[];
    double totalAssets = 0, totalLiab = 0, totalEquity = 0;
    double revenueTotal = 0, expenseTotal = 0;

    for (final a in prov.accounts.where((a) => a.isLeaf)) {
      final b = bals[a.id];
      if (b == null) continue;
      final d = b['debit'] ?? 0;
      final c = b['credit'] ?? 0;
      final net = d - c;

      if (a.accountType == 'asset') {
        final amt = a.accountNature == 'debit' ? net : -net;
        if (amt.abs() < 0.001) continue;
        assets.add({'name': a.name, 'amount': amt});
        totalAssets += amt;
      } else if (a.accountType == 'liability') {
        final amt = a.accountNature == 'credit' ? -net : net;
        if (amt.abs() < 0.001) continue;
        liabilities.add({'name': a.name, 'amount': amt});
        totalLiab += amt;
      } else if (a.accountType == 'equity') {
        final amt = a.accountNature == 'credit' ? -net : net;
        if (amt.abs() < 0.001) continue;
        equity.add({'name': a.name, 'amount': amt});
        totalEquity += amt;
      } else if (a.accountType == 'revenue') {
        // الإيرادات دائنة؛ المردودات/الخصم (مدين) تُطرح
        revenueTotal += a.accountNature == 'credit' ? (c - d) : -(d - c);
      } else if (a.accountType == 'expense') {
        expenseTotal += (d - c);
      }
    }

    final netProfit = revenueTotal - expenseTotal;
    totalEquity += netProfit;

    return Scaffold(
      appBar: AppBar(
        title: const Text('المركز المالي'),
        actions: [
          ExportButton(
            title: 'المركز المالي',
            companyName: prov.companyName,
            filename: 'balance_sheet',
            headers: ['البند', 'المبلغ ($curr)'],
            rows: [
              ['— الأصول —', ''],
              for (final a in assets)
                [a['name'] as String, Fmt.num(a['amount'] as double)],
              ['إجمالي الأصول', Fmt.num(totalAssets)],
              ['— الخصوم —', ''],
              for (final l in liabilities)
                [l['name'] as String, Fmt.num(l['amount'] as double)],
              ['إجمالي الخصوم', Fmt.num(totalLiab)],
              ['— حقوق الملكية —', ''],
              for (final e in equity)
                [e['name'] as String, Fmt.num(e['amount'] as double)],
              ['إجمالي حقوق الملكية', Fmt.num(totalEquity)],
            ],
            totals: [
              'إجمالي الأصول: ${Fmt.money(totalAssets, curr)}',
              'إجمالي الخصوم + حقوق الملكية: ${Fmt.money(totalLiab + totalEquity, curr)}',
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // الأصول
          _section('الأصول', AppColors.primary, assets, totalAssets, curr),
          const SizedBox(height: 12),
          // الخصوم
          _section('الخصوم', AppColors.danger, liabilities, totalLiab, curr),
          const SizedBox(height: 12),
          // حقوق الملكية
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _header('حقوق الملكية', AppColors.purple),
                  for (final e in equity)
                    _row(e['name'] as String, e['amount'] as double, curr),
                  if (netProfit != 0)
                    _row(
                      netProfit >= 0 ? 'صافي ربح الفترة' : 'صافي خسارة الفترة',
                      netProfit,
                      curr,
                    ),
                  const Divider(),
                  _row('إجمالي حقوق الملكية', totalEquity, curr, bold: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _row('إجمالي الأصول', totalAssets, curr, bold: true),
                  const SizedBox(height: 6),
                  _row('إجمالي الخصوم + حقوق الملكية',
                      totalLiab + totalEquity, curr, bold: true),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (totalAssets - (totalLiab + totalEquity)).abs() < 0.5
                          ? AppColors.success.withValues(alpha: 0.1)
                          : AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          (totalAssets - (totalLiab + totalEquity)).abs() < 0.5
                              ? Icons.check_circle
                              : Icons.info,
                          color: (totalAssets - (totalLiab + totalEquity)).abs() <
                                  0.5
                              ? AppColors.success
                              : AppColors.warning,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            (totalAssets - (totalLiab + totalEquity)).abs() < 0.5
                                ? 'الميزانية متوازنة ✓'
                                : 'فرق: ${Fmt.money((totalAssets - (totalLiab + totalEquity)).abs(), curr)}',
                            style: const TextStyle(fontSize: 13),
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

  Widget _section(String title, Color color, List<Map<String, dynamic>> rows,
      double total, String curr) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _header(title, color),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('لا توجد أرصدة', style: TextStyle(color: Colors.grey)),
              ),
            for (final r in rows)
              _row(r['name'] as String, r['amount'] as double, curr),
            const Divider(),
            _row('إجمالي $title', total, curr, bold: true),
          ],
        ),
      ),
    );
  }

  Widget _header(String title, Color color) {
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

  Widget _row(String label, double amount, String curr, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          ),
          Text(
            Fmt.money(amount, curr),
            style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
