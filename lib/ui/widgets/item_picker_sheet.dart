// ============================================================================
// نافذة اختيار الصنف (قابلة لإعادة الاستخدام) — ItemPickerSheet
// تُستخدم في الفواتير وعروض الأسعار والأوامر
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';

class ItemPickerSheet extends StatefulWidget {
  final bool isSale;
  final double defaultTaxRate;

  const ItemPickerSheet({
    super.key,
    required this.isSale,
    required this.defaultTaxRate,
  });

  @override
  State<ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends State<ItemPickerSheet> {
  Item? _item;
  final _qty = TextEditingController(text: '1');
  final _price = TextEditingController();
  final _discount = TextEditingController(text: '0');
  final _taxCtrl = TextEditingController();
  double _taxRate = 0;

  @override
  void initState() {
    super.initState();
    _taxRate = widget.defaultTaxRate;
    _taxCtrl.text = _taxRate.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _qty.dispose();
    _price.dispose();
    _discount.dispose();
    _taxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final curr = prov.currency;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'اختيار صنف',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<Item>(
            initialValue: _item,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'الصنف',
              prefixIcon: Icon(Icons.inventory_2),
            ),
            items: prov.items
                .map((it) => DropdownMenuItem(
                      value: it,
                      child: Text(
                        '${it.name} (متاح: ${Fmt.num(prov.stockQty(it.id))})',
                      ),
                    ))
                .toList(),
            onChanged: (v) {
              setState(() {
                _item = v;
                _price.text = (widget.isSale
                        ? (v?.salePrice ?? 0)
                        : (v?.purchasePrice ?? 0))
                    .toString();
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qty,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'الكمية'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'السعر ($curr)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _discount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'خصم السطر'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _taxCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'ضريبة %'),
                  onChanged: (v) =>
                      setState(() => _taxRate = double.tryParse(v) ?? 0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _item == null
                  ? null
                  : () {
                      final qty = double.tryParse(_qty.text) ?? 1;
                      final price = double.tryParse(_price.text) ?? 0;
                      final disc = double.tryParse(_discount.text) ?? 0;
                      Navigator.pop(
                        context,
                        InvoiceLine(
                          itemId: _item!.id,
                          itemName: _item!.name,
                          quantity: qty,
                          unitPrice: price,
                          discount: disc,
                          taxRate: _taxRate,
                          costPrice: _item!.purchasePrice,
                        ),
                      );
                    },
              icon: const Icon(Icons.check),
              label: const Text('إضافة للسطور'),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
