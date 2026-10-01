// ============================================================================
// تقرير المبيعات
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../models/models.dart';
import '../widgets/export_button.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

class SalesReportScreen extends StatelessWidget {
  const SalesReportScreen({super.key});

  List<List<String>> _rows(List<Invoice> sales) {
    final rows = <List<String>>[];
    for (final inv in sales) {
      rows.add([
        inv.invoiceNumber,
        inv.date,
        inv.contactName.isEmpty ? 'عميل نقدي' : inv.contactName,
        inv.paymentType == 'cash' ? 'نقدي' : 'آجل',
        Fmt.num(inv.total),
      ]);
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final curr = prov.currency;
    final sales = prov.invoices.where((i) => i.invoiceType == 'sale').toList();
    final returns =
        prov.invoices.where((i) => i.invoiceType == 'sale_return').toList();

    final grossSales = sales.fold(0.0, (s, i) => s + i.total);
    final totalReturns = returns.fold(0.0, (s, i) => s + i.total);
    final totalCost = sales.fold(0.0, (s, i) => s + i.totalCost);
    final netSales = grossSales - totalReturns;
    final profit = netSales - totalCost;

    // الأكثر مبيعاً
    final itemSales = <String, double>{};
    final itemQty = <String, double>{};
    for (final inv in sales) {
      for (final l in inv.lines) {
        itemSales[l.itemName] = (itemSales[l.itemName] ?? 0) + l.lineTotal;
        itemQty[l.itemName] = (itemQty[l.itemName] ?? 0) + l.quantity;
      }
    }
    final topItems = itemSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير المبيعات'),
        actions: [
          ExportButton(
            title: 'تقرير المبيعات',
            companyName: prov.companyName,
            filename: 'sales_report',
            headers: const ['الرقم', 'التاريخ', 'الجهة', 'النوع', 'الإجمالي'],
            rows: _rows(sales),
            totals: [
              'إجمالي المبيعات: ${Fmt.money(grossSales, curr)}',
              'المرتجعات: ${Fmt.money(totalReturns, curr)}',
              'صافي المبيعات: ${Fmt.money(netSales, curr)}',
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              StatCard(
                  title: 'إجمالي المبيعات',
                  value: Fmt.money(grossSales, curr),
                  icon: Icons.point_of_sale,
                  color: AppColors.success),
              StatCard(
                  title: 'المرتجعات',
                  value: Fmt.money(totalReturns, curr),
                  icon: Icons.assignment_return,
                  color: AppColors.danger),
              StatCard(
                  title: 'صافي المبيعات',
                  value: Fmt.money(netSales, curr),
                  icon: Icons.trending_up,
                  color: AppColors.primary),
              StatCard(
                  title: 'الربح التقديري',
                  value: Fmt.money(profit, curr),
                  icon: Icons.savings,
                  color: AppColors.teal),
            ],
          ),
          const SizedBox(height: 16),
          const SectionTitle('الأصناف الأكثر مبيعاً', icon: Icons.star),
          if (topItems.isEmpty)
            const EmptyState(message: 'لا توجد مبيعات', icon: Icons.point_of_sale)
          else
            Card(
              child: Column(
                children: [
                  for (int i = 0; i < topItems.length && i < 10; i++)
                    ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold)),
                      ),
                      title: Text(topItems[i].key,
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text('الكمية: ${Fmt.num(itemQty[topItems[i].key] ?? 0)}',
                          style: const TextStyle(fontSize: 11)),
                      trailing: Text(
                        Fmt.money(topItems[i].value, curr),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          const SectionTitle('الفواتير', icon: Icons.receipt_long),
          if (sales.isEmpty)
            const EmptyState(message: 'لا توجد فواتير')
          else
            Card(
              child: Column(
                children: [
                  for (final inv in sales.reversed.take(20))
                    ListTile(
                      dense: true,
                      title: Text(inv.contactName.isEmpty
                          ? 'عميل نقدي'
                          : inv.contactName,
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text('${inv.invoiceNumber} • ${inv.date}',
                          style: const TextStyle(fontSize: 11)),
                      trailing: Text(Fmt.money(inv.total, curr),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
