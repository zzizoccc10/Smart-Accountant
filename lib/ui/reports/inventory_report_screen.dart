// ============================================================================
// تقرير المخزون
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../services/print_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

class InventoryReportScreen extends StatelessWidget {
  const InventoryReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final curr = prov.currency;

    double totalValue = 0;
    final rows = <Map<String, dynamic>>[];
    for (final it in prov.items) {
      final qty = prov.stockQty(it.id);
      final cost = prov.itemAvgCost(it.id);
      final value = qty * cost;
      totalValue += value;
      rows.add({
        'name': it.name,
        'qty': qty,
        'cost': cost,
        'value': value,
        'reorder': it.reorderLevel,
      });
    }
    rows.sort((a, b) => (b['value'] as double).compareTo(a['value'] as double));

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير المخزون'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'تصدير PDF',
            onPressed: () => PrintService.printTable(
              title: 'تقرير المخزون',
              companyName: prov.companyName,
              headers: ['الصنف', 'الكمية', 'متوسط التكلفة', 'القيمة'],
              rows: [
                for (final r in rows)
                  [
                    r['name'] as String,
                    Fmt.num(r['qty'] as double),
                    Fmt.num(r['cost'] as double),
                    Fmt.num(r['value'] as double),
                  ],
              ],
              totals: ['إجمالي قيمة المخزون: ${Fmt.money(totalValue, curr)}'],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          StatCard(
            title: 'إجمالي قيمة المخزون',
            value: Fmt.money(totalValue, curr),
            icon: Icons.inventory,
            color: AppColors.purple,
          ),
          const SizedBox(height: 16),
          const SectionTitle('الأرصدة', icon: Icons.list_alt),
          if (rows.isEmpty)
            const EmptyState(message: 'لا توجد أصناف', icon: Icons.inventory_2)
          else
            Card(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    color: AppColors.primary.withValues(alpha: 0.06),
                    child: const Row(
                      children: [
                        Expanded(
                            flex: 3,
                            child: Text('الصنف',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(
                            child: Text('الكمية',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(
                            flex: 2,
                            child: Text('القيمة',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                  for (final r in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(r['name'] as String,
                                      style: const TextStyle(fontSize: 12)),
                                ),
                                if ((r['reorder'] as double) > 0 &&
                                    (r['qty'] as double) <= (r['reorder'] as double))
                                  const Icon(Icons.warning,
                                      color: AppColors.danger, size: 14),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Text(
                              Fmt.num(r['qty'] as double),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              Fmt.money(r['value'] as double, curr),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
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
