// ============================================================================
// نموذج الفاتورة الموحّد — Universal Invoice Form
// يخدم: بيع/شراء/مرتجع بيع/مرتجع شراء (حسب المواصفة 5.3)
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';
import '../contacts/contact_form.dart';
import '../inventory/item_form.dart';

class InvoiceForm extends StatefulWidget {
  final String invoiceType;
  const InvoiceForm({super.key, required this.invoiceType});

  @override
  State<InvoiceForm> createState() => _InvoiceFormState();
}

class _InvoiceFormState extends State<InvoiceForm> {
  String? _contactId;
  String _paymentType = 'cash';
  late String _date;
  String _warehouseId = 'wh_main';
  String? _cashboxId;
  final List<InvoiceLine> _lines = [];
  double _discountAmount = 0.0;
  double _shipping = 0.0;
  double _paidAmount = 0.0;
  final _notes = TextEditingController();
  bool _saving = false;
  String? _originalInvoiceId; // للمرتجعات: الفاتورة الأصلية

  bool get isSale =>
      widget.invoiceType == 'sale' || widget.invoiceType == 'sale_return';
  bool get isReturn => widget.invoiceType.contains('return');
  bool get isCredit => _paymentType == 'credit';

  String get title => switch (widget.invoiceType) {
    'sale' => 'فاتورة مبيعات',
    'sale_return' => 'مرتجع مبيعات',
    'purchase' => 'فاتورة مشتريات',
    _ => 'مرتجع مشتريات',
  };

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _date =
        '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<ERPProvider>();
      if (prov.warehouses.isNotEmpty) {
        _warehouseId = prov.warehouses.first.id;
      }
      if (prov.cashboxes.isNotEmpty) {
        _cashboxId = prov.cashboxes.first.id;
      }
      setState(() {});
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
    final customers = prov.contacts
        .where((c) =>
            isSale ? c.contactType != 'supplier' : c.contactType != 'customer')
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // العميل + التاريخ
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _contactId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: isSale ? 'العميل' : 'المورد',
                            prefixIcon: const Icon(Icons.person),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text(isSale ? 'عميل نقدي' : 'مورد نقدي'),
                            ),
                            ...customers.map((c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.name),
                                )),
                          ],
                          onChanged: (v) => setState(() => _contactId = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'إضافة سريعة',
                        icon: const Icon(Icons.person_add),
                        onPressed: () async {
                          final res = await Navigator.push<Contact>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ContactForm(
                                defaultType: isSale ? 'customer' : 'supplier',
                              ),
                            ),
                          );
                          if (res != null) {
                            setState(() => _contactId = res.id);
                          }
                        },
                      ),
                    ],
                  ),
                  if (isReturn) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _originalInvoiceId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'الفاتورة الأصلية (للتحقق من الكميات)',
                        prefixIcon: Icon(Icons.receipt_long),
                      ),
                      items: prov.invoices
                          .where((i) =>
                              i.invoiceType == (isSale ? 'sale' : 'purchase'))
                          .map((i) => DropdownMenuItem(
                                value: i.id,
                                child: Text(
                                    '${i.invoiceNumber} — ${i.contactName} — ${Fmt.money(i.total, curr)}'),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _originalInvoiceId = v),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
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
                        child: DropdownButtonFormField<String>(
                          initialValue: _warehouseId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'المخزن',
                            prefixIcon: Icon(Icons.warehouse),
                          ),
                          items: prov.warehouses
                              .map((w) => DropdownMenuItem(
                                    value: w.id,
                                    child: Text(w.name),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _warehouseId = v ?? 'wh_main'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // الأصناف
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
                  child: Text(
                    'لم تُضف أصناف بعد — اضغط "إضافة صنف"',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (int i = 0; i < _lines.length; i++)
                    _lineTile(i, _lines[i], curr),
                ],
              ),
            ),
          const SizedBox(height: 12),

          // المدفوع ونوع الدفع
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'cash', label: Text('نقدي')),
                            ButtonSegment(value: 'credit', label: Text('آجل')),
                          ],
                          selected: {_paymentType},
                          onSelectionChanged: (s) =>
                              setState(() => _paymentType = s.first),
                        ),
                      ),
                    ],
                  ),
                  if (!isCredit) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _cashboxId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'الصندوق',
                        prefixIcon: Icon(Icons.account_balance_wallet),
                      ),
                      items: prov.cashboxes
                          .map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(
                                  '${c.name} (${Fmt.money(c.currentBalance, curr)})',
                                ),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _cashboxId = v),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: _paidAmount.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'المبلغ المدفوع مقدماً',
                        prefixIcon: Icon(Icons.payments),
                      ),
                      onChanged: (v) =>
                          setState(() => _paidAmount = double.tryParse(v) ?? 0),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // المجاميع
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _sumRow('المجموع', Fmt.money(_subtotal, curr)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('الخصم: '),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: _discountAmount.toString(),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: '0',
                          ),
                          onChanged: (v) => setState(
                              () => _discountAmount = double.tryParse(v) ?? 0),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _sumRow('الضريبة', Fmt.money(_taxTotal, curr)),
                  if (isSale && !isReturn) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('التوصيل: '),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: _shipping.toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText: '0',
                            ),
                            onChanged: (v) => setState(
                                () => _shipping = double.tryParse(v) ?? 0),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Divider(height: 24),
                  Row(
                    children: [
                      const Text(
                        'الإجمالي',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        Fmt.money(_total, curr),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  if (isCredit) ...[
                    const SizedBox(height: 8),
                    _sumRow(
                      'المتبقي',
                      Fmt.money(_total - _paidAmount, curr),
                      color: AppColors.danger,
                    ),
                  ],
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'جاري الحفظ...' : 'حفظ وترحيل'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _sumRow(String label, String value, {Color? color}) {
    return Row(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _lineTile(int index, InvoiceLine line, String curr) {
    return ListTile(
      title: Text(line.itemName, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        '${Fmt.num(line.quantity)} × ${Fmt.money(line.unitPrice, curr)}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            Fmt.money(line.lineTotal, curr),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
            onPressed: () => setState(() => _lines.removeAt(index)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _date =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _addItemDialog() async {
    final prov = context.read<ERPProvider>();
    if (prov.items.isEmpty) {
      final add = await confirmDialog(
        context,
        title: 'لا توجد أصناف',
        message: 'لا توجد أصناف في النظام. هل تريد إضافة صنف جديد؟',
        confirmText: 'إضافة صنف',
        confirmColor: AppColors.primary,
      );
      if (add && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ItemForm()),
        );
      }
      return;
    }

    final result = await showModalBottomSheet<InvoiceLine>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ItemPickerSheet(
        isSale: isSale,
        defaultTaxRate: prov.taxRate,
      ),
    );
    if (result != null) {
      setState(() => _lines.add(result));
    }
  }

  Future<void> _save() async {
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف صنفاً واحداً على الأقل')),
      );
      return;
    }
    if (isCredit && _contactId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('البيع الآجل يتطلب اختيار عميل/مورد')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final prov = context.read<ERPProvider>();
      await prov.createInvoice(
        invoiceType: widget.invoiceType,
        paymentType: _paymentType,
        date: _date,
        contactId: _contactId,
        warehouseId: _warehouseId,
        cashboxId: isCredit ? null : _cashboxId,
        lines: _lines,
        discountAmount: _discountAmount,
        shipping: isSale && !isReturn ? _shipping : 0,
        notes: _notes.text,
        paidAmount: _paidAmount,
        originalInvoiceId: _originalInvoiceId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حفظ $title بنجاح وترحيل القيد'),
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

/// نافذة اختيار الصنف
class _ItemPickerSheet extends StatefulWidget {
  final bool isSale;
  final double defaultTaxRate;

  const _ItemPickerSheet({
    required this.isSale,
    required this.defaultTaxRate,
  });

  @override
  State<_ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends State<_ItemPickerSheet> {
  Item? _item;
  final _qty = TextEditingController(text: '1');
  final _price = TextEditingController();
  final _discount = TextEditingController(text: '0');
  double _taxRate = 0;

  @override
  void initState() {
    super.initState();
    _taxRate = widget.defaultTaxRate;
  }

  @override
  void dispose() {
    _qty.dispose();
    _price.dispose();
    _discount.dispose();
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
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'ضريبة %'),
                  controller: TextEditingController(
                    text: _taxRate.toStringAsFixed(0),
                  ),
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
