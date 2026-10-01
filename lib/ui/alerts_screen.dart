// ============================================================================
// شاشة التنبيهات — المخزون المنخفض والمستحقات المتأخرة
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/erp_provider.dart';
import '../theme/app_theme.dart';
import 'widgets/common.dart';
import 'inventory/item_form.dart';
import 'sales/invoice_details_screen.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final curr = prov.currency;
    final lowStock = prov.lowStockItems;
    final overdue = prov.overdueInvoices;
    final empty = lowStock.isEmpty && overdue.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('التنبيهات')),
      body: empty
          ? const EmptyState(
              message: 'لا توجد تنبيهات — كل شيء على ما يرام ✅',
              icon: Icons.notifications_none,
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (lowStock.isNotEmpty) ...[
                  SectionTitle(
                    'أصناف وصلت حد الطلب (${lowStock.length})',
                    icon: Icons.warning_amber_rounded,
                  ),
                  Card(
                    child: Column(
                      children: [
                        for (final it in lowStock)
                          ListTile(
                            dense: true,
                            leading: const CircleAvatar(
                              backgroundColor: Color(0x1AC62828),
                              child: Icon(Icons.inventory_2,
                                  color: AppColors.danger, size: 20),
                            ),
                            title: Text(it.name,
                                style: const TextStyle(fontSize: 13)),
                            subtitle: Text(
                              'المتاح: ${Fmt.num(prov.stockQty(it.id))} • حد الطلب: ${Fmt.num(it.reorderLevel)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: const Icon(Icons.chevron_left, size: 18),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => ItemForm(item: it)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (overdue.isNotEmpty) ...[
                  SectionTitle(
                    'فواتير متأخرة السداد (${overdue.length})',
                    icon: Icons.schedule,
                  ),
                  Card(
                    child: Column(
                      children: [
                        for (final inv in overdue)
                          ListTile(
                            dense: true,
                            leading: const CircleAvatar(
                              backgroundColor: Color(0x1AF57C00),
                              child: Icon(Icons.receipt_long,
                                  color: AppColors.warning, size: 20),
                            ),
                            title: Text(
                              inv.contactName.isEmpty
                                  ? 'عميل نقدي'
                                  : inv.contactName,
                              style: const TextStyle(fontSize: 13),
                            ),
                            subtitle: Text(
                              '${inv.invoiceNumber} • استحقاق: ${inv.dueDate}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: Text(
                              Fmt.money(inv.remaining, curr),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: AppColors.danger,
                              ),
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      InvoiceDetailsScreen(invoiceId: inv.id)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
    );
  }
}
