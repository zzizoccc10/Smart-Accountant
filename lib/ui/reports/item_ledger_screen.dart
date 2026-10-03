// ============================================================================
// تقرير حركة الصنف (كارت الصنف) — Item Ledger
// يعرض كل حركات صنف مختار مع الرصيد التراكمي
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/export_button.dart';

class ItemLedgerScreen extends StatefulWidget {
  const ItemLedgerScreen({super.key});

  @override
  State<ItemLedgerScreen> createState() => _ItemLedgerScreenState();
}

class _ItemLedgerScreenState extends State<ItemLedgerScreen> {
  String? _itemId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<ERPProvider>();
      if (_itemId == null && prov.items.isNotEmpty) {
        setState(() => _itemId = prov.items.first.id);
      }
    });
  }

  String _movLabel(String t) => switch (t) {
        'purchase' => 'شراء',
        'sale' => 'بيع',
        'return_in' => 'مرتجع وارد',
        'return_out' => 'مرتجع صادر',
        'transfer_in' => 'تحويل وارد',
        'transfer_out' => 'تحويل صادر',
        'adjustment' => 'تسوية',
        'opening' => 'رصيد افتتاحي',
        _ => t,
      };

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final curr = prov.currency;
    final items = prov.items;

    final moves = _itemId == null
        ? <InventoryMovement>[]
        : prov.movements.where((m) => m.itemId == _itemId).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final totalIn = moves.fold(0.0, (s, m) => s + m.quantityIn);
    final totalOut = moves.fold(0.0, (s, m) => s + m.quantityOut);
    final currentQty = _itemId == null ? 0.0 : prov.stockQty(_itemId!);
    final avgCost = _itemId == null ? 0.0 : prov.itemAvgCost(_itemId!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('حركة الصنف (كارت الصنف)'),
        actions: [
          if (moves.isNotEmpty)
            ExportButton(
              title: 'كارت صنف - ${items.where((i) => i.id == _itemId).firstOrNull?.name ?? ''}',
              companyName: prov.companyName,
              filename: 'item_ledger',
              headers: const [
                'التاريخ',
                'الحركة',
                'وارد',
                'صادر',
                'الرصيد',
                'التكلفة',
              ],
              rows: [
                for (final m in moves)
                  [
                    m.date,
                    _movLabel(m.movementType),
                    m.quantityIn > 0 ? Fmt.num(m.quantityIn) : '',
                    m.quantityOut > 0 ? Fmt.num(m.quantityOut) : '',
                    Fmt.num(m.balanceAfter),
                    Fmt.num(m.unitCost),
                  ],
              ],
              totals: [
                'إجمالي الوارد: ${Fmt.num(totalIn)}',
                'إجمالي الصادر: ${Fmt.num(totalOut)}',
                'الرصيد الحالي: ${Fmt.num(currentQty)}',
                'قيمة المخزون: ${Fmt.money(currentQty * avgCost, curr)}',
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<String>(
              initialValue:
                  items.any((it) => it.id == _itemId) ? _itemId : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'اختر الصنف',
                prefixIcon: Icon(Icons.inventory_2),
              ),
              items: items
                  .map((it) => DropdownMenuItem(
                        value: it.id,
                        child: Text(it.name),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _itemId = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: _statCard('الرصيد الحالي', Fmt.num(currentQty),
                      Icons.warehouse, AppColors.primary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statCard('قيمة المخزون',
                      Fmt.money(currentQty * avgCost, curr),
                      Icons.attach_money, AppColors.success),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: moves.isEmpty
                ? const EmptyState(
                    message: 'لا توجد حركات لهذا الصنف',
                    icon: Icons.receipt_long_outlined,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: moves.length,
                    itemBuilder: (_, i) {
                      final m = moves[i];
                      final isIn = m.quantityIn > 0;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: (isIn
                                    ? AppColors.success
                                    : AppColors.danger)
                                .withValues(alpha: 0.12),
                            child: Icon(
                              isIn ? Icons.arrow_downward : Icons.arrow_upward,
                              size: 18,
                              color: isIn ? AppColors.success : AppColors.danger,
                            ),
                          ),
                          title: Text(_movLabel(m.movementType),
                              style: const TextStyle(fontSize: 13)),
                          subtitle: Text(m.date,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade600)),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${isIn ? '+' : '-'}${Fmt.num(isIn ? m.quantityIn : m.quantityOut)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color:
                                      isIn ? AppColors.success : AppColors.danger,
                                ),
                              ),
                              Text('رصيد: ${Fmt.num(m.balanceAfter)}',
                                  style: const TextStyle(fontSize: 10)),
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

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
