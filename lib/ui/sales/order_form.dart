// ============================================================================
// نموذج مستند تجاري (عرض سعر / أمر بيع / أمر شراء)
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/dropdown_safe.dart';
import '../widgets/item_picker_sheet.dart';

class OrderForm extends StatefulWidget {
  final String docType; // quotation | sales_order | purchase_order
  final OrderDoc? existing;

  const OrderForm({super.key, required this.docType, this.existing});

  @override
  State<OrderForm> createState() => _OrderFormState();
}

class _OrderFormState extends State<OrderForm> {
  final _lines = <InvoiceLine>[];
  String? _contactId;
  String _warehouseId = 'wh_main';
  String _date = DateTime.now().toIso8601String().substring(0, 10);
  String _validUntil = '';
  double _discountAmount = 0;
  double _shipping = 0;
  final _notes = TextEditingController();
  bool _saving = false;

  bool get isSale => widget.docType != 'purchase_order';

  String get title => switch (widget.docType) {
    'quotation' => 'عرض سعر',
    'sales_order' => 'أمر بيع',
    _ => 'أمر شراء',
  };

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _lines.addAll(e.lines);
      _contactId = e.contactId;
      _warehouseId = e.warehouseId;
      _date = e.date;
      _validUntil = e.validUntil;
      _discountAmount = e.discountAmount;
      _shipping = e.shipping;
      _notes.text = e.notes;
    }
    // تهيئة المخزن من القائمة الفعلية
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<ERPProvider>();
      if ((_warehouseId.isEmpty || !prov.warehouses.any((w) => w.id == _warehouseId)) &&
          prov.warehouses.isNotEmpty) {
        setState(() => _warehouseId = prov.warehouses.first.id);
      }
    });
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  double get _subtotal => _lines.fold(0.0, (s, l) => s + l.lineSubtotal);
  double get _taxTotal => _lines.fold(0.0, (s, l) => s + l.taxAmount);
  double get _total => _subtotal - _discountAmount + _taxTotal + _shipping;

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final curr = prov.currency;
    final contacts = prov.contacts
        .where((c) => isSale ? c.contactType != 'supplier' : c.contactType != 'customer')
        .toList();

    // قيم آمنة للقوائم المنسدلة
    final safeContact = safeValue(
        _contactId, contacts.map((c) => c.id).toSet());
    final safeWarehouse = safeValueOrFirst(
        _warehouseId, prov.warehouses.map((w) => w.id).toList());

    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'جديد: $title' : 'تعديل: $title')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: safeContact,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: isSale ? 'العميل' : 'المورد',
                      prefixIcon: const Icon(Icons.person),
                    ),
                    items: [
                      DropdownMenuItem(
                          value: null,
                          child: Text(isSale ? 'عميل نقدي' : 'مورد نقدي')),
                      ...contacts.map((c) =>
                          DropdownMenuItem(value: c.id, child: Text(c.name))),
                    ],
                    onChanged: (v) => setState(() => _contactId = v),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(false),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'التاريخ',
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(_date),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(true),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'صالحة حتى / التسليم',
                              prefixIcon: Icon(Icons.event),
                            ),
                            child: Text(_validUntil.isEmpty ? '—' : _validUntil),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: safeWarehouse,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'المخزن',
                      prefixIcon: Icon(Icons.warehouse),
                    ),
                    items: prov.warehouses
                        .map((w) =>
                            DropdownMenuItem(value: w.id, child: Text(w.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _warehouseId = v ?? 'wh_main'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SectionTitle(
            'الأصناف',
            icon: Icons.list_alt,
            trailing: TextButton.icon(
              onPressed: _addItemDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('إضافة صنف'),
            ),
          ),
          if (_lines.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('لم تُضف أصناف بعد — اضغط "إضافة صنف"',
                      style: TextStyle(color: Colors.grey)),
                ),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (int i = 0; i < _lines.length; i++)
                    ListTile(
                      title: Text(_lines[i].itemName,
                          style: const TextStyle(fontSize: 14)),
                      subtitle: Text(
                        '${Fmt.num(_lines[i].quantity)} × ${Fmt.money(_lines[i].unitPrice, curr)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(Fmt.money(_lines[i].lineTotal, curr),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          IconButton(
                            icon: const Icon(Icons.close,
                                size: 18, color: AppColors.danger),
                            onPressed: () =>
                                setState(() => _lines.removeAt(i)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _amtRow('المجموع الفرعي', _subtotal, curr),
                  _amtRow('الضريبة', _taxTotal, curr),
                  Row(
                    children: [
                      const Expanded(
                          child: Text('خصم إضافي', style: TextStyle(fontSize: 13))),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(isDense: true),
                          onChanged: (v) => setState(
                              () => _discountAmount = double.tryParse(v) ?? 0),
                        ),
                      ),
                    ],
                  ),
                  if (isSale)
                    Row(
                      children: [
                        const Expanded(
                            child: Text('الشحن', style: TextStyle(fontSize: 13))),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(isDense: true),
                            onChanged: (v) => setState(
                                () => _shipping = double.tryParse(v) ?? 0),
                          ),
                        ),
                      ],
                    ),
                  const Divider(),
                  Row(
                    children: [
                      const Text('الإجمالي',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const Spacer(),
                      Text(Fmt.money(_total, curr),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.primary)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'ملاحظات',
              prefixIcon: Icon(Icons.notes),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ $title'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _amtRow(String label, double val, String curr) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
            Text(Fmt.money(val, curr), style: const TextStyle(fontSize: 13)),
          ],
        ),
      );

  Future<void> _pickDate(bool validUntil) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      final s =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() => validUntil ? _validUntil = s : _date = s);
    }
  }

  Future<void> _addItemDialog() async {
    final prov = context.read<ERPProvider>();
    if (prov.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد أصناف — أضف صنفاً أولاً')),
      );
      return;
    }
    final result = await showModalBottomSheet<InvoiceLine>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ItemPickerSheet(
        isSale: isSale,
        defaultTaxRate: prov.taxRate,
      ),
    );
    if (result != null) setState(() => _lines.add(result));
  }

  Future<void> _save() async {
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف صنفاً واحداً على الأقل')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final prov = context.read<ERPProvider>();
      await prov.createOrder(
        docType: widget.docType,
        date: _date,
        contactId: _contactId,
        warehouseId: _warehouseId,
        lines: _lines,
        discountAmount: _discountAmount,
        taxAmount: _taxTotal,
        shipping: isSale ? _shipping : 0,
        validUntil: _validUntil,
        notes: _notes.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حفظ $title بنجاح'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.danger),
      );
    }
  }
}
