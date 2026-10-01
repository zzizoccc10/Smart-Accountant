// ============================================================================
// قائمة الفواتير (قابلة للفتح من لوحة التحكم)
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';
import 'invoice_form.dart';
import 'invoice_details_screen.dart';

class SalesListScreen extends StatefulWidget {
  final int initialTab;
  const SalesListScreen({super.key, this.initialTab = 0});

  @override
  State<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends State<SalesListScreen> {
  late int _tab;
  String _search = '';

  final _tabs = const [
    ['مبيعات', 'sale'],
    ['مرتجع بيع', 'sale_return'],
    ['مشتريات', 'purchase'],
    ['مرتجع شراء', 'purchase_return'],
  ];

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

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
      appBar: AppBar(title: const Text('الفواتير')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: List.generate(_tabs.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ChoiceChip(
                    label: Text(_tabs[i][0]),
                    selected: _tab == i,
                    onSelected: (_) => setState(() => _tab = i),
                  ),
                );
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'بحث...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? EmptyState(message: 'لا توجد ${_tabs[_tab][0]}')
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final inv = list[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  InvoiceDetailsScreen(invoiceId: inv.id),
                            ),
                          ),
                          leading: const CircleAvatar(
                            backgroundColor: Color(0x1A1565C0),
                            child: Icon(Icons.receipt, color: AppColors.primary),
                          ),
                          title: Text(inv.contactName.isEmpty
                              ? 'عميل نقدي'
                              : inv.contactName),
                          subtitle: Text('${inv.invoiceNumber} • ${inv.date}'),
                          trailing: Text(
                            Fmt.money(inv.total, prov.currency),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => InvoiceForm(invoiceType: type)),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
