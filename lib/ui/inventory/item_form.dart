// ============================================================================
// نموذج الصنف — إضافة/تعديل
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../models/models.dart';
import '../../data/app_database.dart';

class ItemForm extends StatefulWidget {
  final Item? item;
  const ItemForm({super.key, this.item});

  @override
  State<ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends State<ItemForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _barcode;
  late TextEditingController _purchase;
  late TextEditingController _sale;
  late TextEditingController _reorder;
  late TextEditingController _openingQty;
  String? _categoryId;
  String _costMethod = 'Average';

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    _name = TextEditingController(text: i?.name ?? '');
    _barcode = TextEditingController(text: i?.barcode ?? '');
    _purchase = TextEditingController(
      text: (i?.purchasePrice ?? 0) == 0 ? '' : i!.purchasePrice.toString(),
    );
    _sale = TextEditingController(
      text: (i?.salePrice ?? 0) == 0 ? '' : i!.salePrice.toString(),
    );
    _reorder = TextEditingController(
      text: (i?.reorderLevel ?? 0) == 0 ? '' : i!.reorderLevel.toString(),
    );
    _openingQty = TextEditingController(
      text: (i?.openingQty ?? 0) == 0 ? '' : i!.openingQty.toString(),
    );
    _categoryId = i?.categoryId;
    _costMethod = i?.costMethod ?? 'Average';
  }

  @override
  void dispose() {
    _name.dispose();
    _barcode.dispose();
    _purchase.dispose();
    _sale.dispose();
    _reorder.dispose();
    _openingQty.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final prov = context.read<ERPProvider>();
    final item = Item(
      id: widget.item?.id ?? AppDatabase.newId(),
      code: widget.item?.code ?? '',
      barcode: _barcode.text.trim(),
      name: _name.text.trim(),
      categoryId: _categoryId,
      costMethod: _costMethod,
      purchasePrice: double.tryParse(_purchase.text) ?? 0,
      salePrice: double.tryParse(_sale.text) ?? 0,
      reorderLevel: double.tryParse(_reorder.text) ?? 0,
      openingQty: double.tryParse(_openingQty.text) ?? 0,
    );

    if (widget.item == null) {
      await prov.addItem(item);
      // رصيد افتتاحي للمخزون (في المخزن الافتراضي إن وُجد)
      final qty = item.openingQty;
      if (qty > 0) {
        final whId = prov.warehouses.isNotEmpty
            ? prov.warehouses.first.id
            : 'wh_main';
        await AppDatabase.saveBalance(
          InventoryBalance(
            itemId: item.id,
            warehouseId: whId,
            quantity: qty,
            avgCost: item.purchasePrice,
          ),
        );
        await AppDatabase.saveMovement(
          InventoryMovement(
            id: AppDatabase.newId(),
            itemId: item.id,
            itemName: item.name,
            warehouseId: whId,
            date: DateTime.now().toIso8601String().split('T')[0],
            movementType: 'opening',
            quantityIn: qty,
            unitCost: item.purchasePrice,
            balanceAfter: qty,
          ),
        );
      }
      prov.reload();
    } else {
      await prov.updateItem(item);
    }
    if (mounted) Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item == null ? 'صنف جديد' : 'تعديل صنف'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'اسم الصنف',
                prefixIcon: Icon(Icons.inventory_2),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _barcode,
              decoration: const InputDecoration(
                labelText: 'الباركود',
                prefixIcon: Icon(Icons.qr_code),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _categoryId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'التصنيف',
                prefixIcon: Icon(Icons.category),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('بدون تصنيف')),
                ...prov.categories.map(
                  (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                ),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _purchase,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'سعر الشراء'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _sale,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'سعر البيع'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _reorder,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'حد الطلب'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _openingQty,
                    keyboardType: TextInputType.number,
                    enabled: widget.item == null,
                    decoration: const InputDecoration(
                      labelText: 'الكمية الافتتاحية',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _costMethod,
              decoration: const InputDecoration(
                labelText: 'طريقة التكلفة',
                prefixIcon: Icon(Icons.calculate),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Average',
                  child: Text('المتوسط المرجّح'),
                ),
                DropdownMenuItem(
                  value: 'FIFO',
                  child: Text('الوارد أولاً صادر أولاً (FIFO)'),
                ),
                DropdownMenuItem(
                  value: 'LIFO',
                  child: Text('الوارد أخيراً صادر أولاً (LIFO)'),
                ),
              ],
              onChanged: (v) => setState(() => _costMethod = v ?? 'Average'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('حفظ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
