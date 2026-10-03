// ============================================================================
// وحدة المخزون — الأصناف، الجرد، التحويل
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';
import 'item_form.dart';
import 'stock_count_screen.dart';
import 'stock_transfer_screen.dart';
import 'movements_screen.dart';
import 'barcode_screen.dart';
import '../../services/quick_export.dart';
import '../settings/import_screen.dart';

class InventoryHome extends StatefulWidget {
  const InventoryHome({super.key});

  @override
  State<InventoryHome> createState() => _InventoryHomeState();
}

class _InventoryHomeState extends State<InventoryHome> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final curr = prov.currency;
    final items = prov.items
        .where((i) =>
            _search.isEmpty ||
            i.name.contains(_search) ||
            i.barcode.contains(_search))
        .toList();

    return Scaffold(
      body: Column(
        children: [
          // إجراءات
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _actionBtn(
                  context,
                  Icons.add_box,
                  'صنف جديد',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ItemForm()),
                  ),
                ),
                _actionBtn(
                  context,
                  Icons.fact_check,
                  'الجرد',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StockCountScreen()),
                  ),
                ),
                _actionBtn(
                  context,
                  Icons.swap_horiz,
                  'تحويل',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const StockTransferScreen()),
                  ),
                ),
                _actionBtn(
                  context,
                  Icons.history,
                  'الحركات',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MovementsScreen()),
                  ),
                ),
                _actionBtn(
                  context,
                  Icons.qr_code_2,
                  'الباركود',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BarcodeScreen()),
                  ),
                ),
              ],
            ),
          ),
          // ملخص
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'قيمة المخزون',
                    value: Fmt.money(prov.inventoryValue, curr),
                    icon: Icons.inventory,
                    color: AppColors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: 'عدد الأصناف',
                    value: '${prov.items.length}',
                    icon: Icons.category,
                    color: AppColors.teal,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'بحث بالاسم أو الباركود...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.ios_share, color: AppColors.primary),
                  tooltip: 'استيراد / تصدير',
                  onSelected: (v) {
                    if (v == 'excel') {
                      exportEntityExcel(context, 'items');
                    } else if (v == 'center') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ImportScreen()),
                      );
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'excel',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.table_view, color: AppColors.success),
                        title: Text('تصدير الأصناف Excel'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'center',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.upload_file, color: AppColors.teal),
                        title: Text('مركز الاستيراد/التصدير'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: items.isEmpty
                ? EmptyState(
                    message: 'لا توجد أصناف — أضف صنفاً للبدء',
                    icon: Icons.inventory_2_outlined,
                    actionLabel: 'إضافة صنف',
                    onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ItemForm()),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final it = items[i];
                      final qty = prov.stockQty(it.id);
                      final low = it.reorderLevel > 0 && qty <= it.reorderLevel;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ItemForm(item: it)),
                          ),
                          leading: CircleAvatar(
                            backgroundColor: (low
                                    ? AppColors.danger
                                    : AppColors.primary)
                                .withValues(alpha: 0.12),
                            child: Icon(
                              Icons.inventory_2,
                              color: low ? AppColors.danger : AppColors.primary,
                            ),
                          ),
                          title: Text(it.name,
                              style: const TextStyle(fontSize: 14)),
                          subtitle: Text(
                            'بيع: ${Fmt.money(it.salePrice, curr)} • شراء: ${Fmt.money(it.purchasePrice, curr)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'متاح: ${Fmt.num(qty)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: low
                                      ? AppColors.danger
                                      : AppColors.success,
                                ),
                              ),
                              if (low)
                                const Text(
                                  '⚠ أقل من حد الطلب',
                                  style: TextStyle(
                                      fontSize: 10, color: AppColors.danger),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
