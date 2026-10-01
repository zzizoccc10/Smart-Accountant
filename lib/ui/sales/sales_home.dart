// ============================================================================
// شاشة المبيعات/المشتريات الرئيسية — نموذج موحّد (حسب المواصفة 5.2)
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';
import 'invoice_form.dart';
import 'invoice_details_screen.dart';

class SalesHome extends StatefulWidget {
  const SalesHome({super.key});

  @override
  State<SalesHome> createState() => _SalesHomeState();
}

class _SalesHomeState extends State<SalesHome> {
  int _tab = 0; // 0=sales, 1=sale returns, 2=purchases, 3=purchase returns
  String _search = '';

  final _tabs = const [
    ['مبيعات', 'sale'],
    ['مرتجع بيع', 'sale_return'],
    ['مشتريات', 'purchase'],
    ['مرتجع شراء', 'purchase_return'],
  ];

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final type = _tabs[_tab][1];
    final list = prov.invoices
        .where((i) => i.invoiceType == type)
        .where((i) =>
            _search.isEmpty ||
            i.contactName.contains(_search) ||
            i.invoiceNumber.contains(_search))
        .toList()
        .reversed
        .toList();

    return Scaffold(
      body: Column(
        children: [
          // تبويبات
          Container(
            color: AppColors.primary,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: List.generate(_tabs.length, (i) {
                  final selected = _tab == i;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: Text(_tabs[i][0]),
                      selected: selected,
                      onSelected: (_) => setState(() => _tab = i),
                      selectedColor: Colors.white,
                      backgroundColor: Colors.white24,
                      labelStyle: TextStyle(
                        color: selected ? AppColors.primary : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      side: BorderSide.none,
                    ),
                  );
                }),
              ),
            ),
          ),
          // بحث
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'بحث بالاسم أو رقم الفاتورة...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          // قائمة
          Expanded(
            child: list.isEmpty
                ? EmptyState(
                    message: 'لا توجد ${_tabs[_tab][0]}',
                    icon: Icons.receipt_long_outlined,
                  )
                : RefreshIndicator(
                    onRefresh: () async => prov.reload(),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _invoiceTile(context, list[i], prov),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InvoiceForm(invoiceType: type),
          ),
        ),
        icon: const Icon(Icons.add),
        label: Text('${_tabs[_tab][0]} جديدة'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _invoiceTile(BuildContext context, inv, ERPProvider prov) {
    final isSale = inv.invoiceType.contains('sale');
    final isReturn = inv.invoiceType.contains('return');
    Color color = isSale ? AppColors.success : AppColors.warning;
    if (isReturn) color = AppColors.danger;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InvoiceDetailsScreen(invoiceId: inv.id),
          ),
        ),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(
            isReturn
                ? Icons.assignment_return
                : (isSale ? Icons.arrow_upward : Icons.arrow_downward),
            color: color,
          ),
        ),
        title: Text(
          inv.contactName.isEmpty ? 'عميل نقدي' : inv.contactName,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '${inv.invoiceNumber} • ${inv.date}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Badge2(
                  inv.paymentType == 'cash' ? 'نقدي' : 'آجل',
                  color: inv.paymentType == 'cash'
                      ? AppColors.success
                      : AppColors.warning,
                ),
                const SizedBox(width: 6),
                Badge2('${inv.lines.length} صنف', color: AppColors.info),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              Fmt.money(inv.total, prov.currency),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            if (inv.paymentType == 'credit' && inv.remaining > 0)
              Text(
                'متبقي ${Fmt.money(inv.remaining, prov.currency)}',
                style: const TextStyle(fontSize: 10, color: AppColors.danger),
              ),
          ],
        ),
      ),
    );
  }
}
