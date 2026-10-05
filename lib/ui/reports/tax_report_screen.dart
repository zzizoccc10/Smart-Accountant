// ============================================================================
// تقرير الضرائب — ضريبة القيمة المضافة (Input / Output VAT)
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/export_button.dart';

class TaxReportScreen extends StatelessWidget {
  const TaxReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final curr = prov.currency;

    final sales = prov.invoices.where((i) => i.invoiceType == 'sale').toList();
    final saleReturns = prov.invoices
        .where((i) => i.invoiceType == 'sale_return')
        .toList();
    final purchases = prov.invoices
        .where((i) => i.invoiceType == 'purchase')
        .toList();
    final purchaseReturns = prov.invoices
        .where((i) => i.invoiceType == 'purchase_return')
        .toList();

    double sumTax(List list) {
      double t = 0;
      for (final inv in list) {
        t += inv.taxAmount;
      }
      return t;
    }

    double sumNet(List list) {
      double t = 0;
      for (final inv in list) {
        t += inv.subtotal - inv.discountAmount;
      }
      return t;
    }

    // ضريبة القيمة المضافة على المخرجات (المبيعات) — Output VAT
    final outputVat = sumTax(sales) - sumTax(saleReturns);
    // ضريبة القيمة المضافة على المدخلات (المشتريات) — Input VAT
    final inputVat = sumTax(purchases) - sumTax(purchaseReturns);
    // الصافي المستحق
    final netVat = outputVat - inputVat;

    final salesBase = sumNet(sales) - sumNet(saleReturns);
    final purchaseBase = sumNet(purchases) - sumNet(purchaseReturns);

    final rows = <List<String>>[
      ['الوعاء الضريبي للمبيعات', Fmt.num(salesBase)],
      ['ض.ق.م على المبيعات (مخرجات)', Fmt.num(outputVat)],
      ['الوعاء الضريبي للمشتريات', Fmt.num(purchaseBase)],
      ['ض.ق.م على المشتريات (مدخلات)', Fmt.num(inputVat)],
      ['صافي الضريبة المستحقة', Fmt.num(netVat)],
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير الضرائب'),
        actions: [
          ExportButton(
            title: 'تقرير ضريبة القيمة المضافة',
            companyName: prov.companyName,
            filename: 'vat_report',
            headers: const ['البيان', 'المبلغ'],
            rows: rows,
            totals: [
              'ض.ق.م على المبيعات: ${Fmt.money(outputVat, curr)}',
              'الصافي المستحق: ${Fmt.money(netVat, curr)}',
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
                title: 'ض.ق.م المبيعات (مخرجات)',
                value: Fmt.money(outputVat, curr),
                icon: Icons.arrow_upward,
                color: AppColors.success,
              ),
              StatCard(
                title: 'ض.ق.م المشتريات (مدخلات)',
                value: Fmt.money(inputVat, curr),
                icon: Icons.arrow_downward,
                color: AppColors.info,
              ),
              StatCard(
                title: netVat >= 0 ? 'صافي مستحق للهيئة' : 'رصيد دائن لك',
                value: Fmt.money(netVat.abs(), curr),
                icon: Icons.account_balance,
                color: netVat >= 0 ? AppColors.danger : AppColors.teal,
              ),
              StatCard(
                title: 'نسبة الضريبة',
                value: '${Fmt.num(prov.taxRate)}%',
                icon: Icons.percent,
                color: AppColors.purple,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const SectionTitle('تفاصيل الوعاء الضريبي', icon: Icons.receipt_long),
          Card(
            child: Column(
              children: [
                _row(
                  'الوعاء الضريبي للمبيعات (بعد المرتجعات)',
                  Fmt.money(salesBase, curr),
                ),
                const Divider(height: 1),
                _row(
                  'ض.ق.م على المبيعات',
                  Fmt.money(outputVat, curr),
                  color: AppColors.success,
                ),
                const Divider(height: 1),
                _row(
                  'الوعاء الضريبي للمشتريات (بعد المرتجعات)',
                  Fmt.money(purchaseBase, curr),
                ),
                const Divider(height: 1),
                _row(
                  'ض.ق.م على المشتريات',
                  Fmt.money(inputVat, curr),
                  color: AppColors.info,
                ),
                const Divider(height: 1),
                _row(
                  'صافي الضريبة المستحقة',
                  Fmt.money(netVat, curr),
                  bold: true,
                  color: netVat >= 0 ? AppColors.danger : AppColors.teal,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: AppColors.primary.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      netVat >= 0
                          ? 'يوجد صافي ضريبة مستحقة على المنشأة بمبلغ ${Fmt.money(netVat, curr)}.'
                          : 'ضريبة المشتريات أكبر من المبيعات — يوجد رصيد ضريبي دائن بمبلغ ${Fmt.money(netVat.abs(), curr)}.',
                      style: const TextStyle(fontSize: 12),
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

  Widget _row(String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
