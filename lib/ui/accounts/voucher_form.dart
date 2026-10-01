// ============================================================================
// نموذج سند القبض/الصرف — مع تخصيص الدفعات على الفواتير الآجلة
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/erp_provider.dart';
import '../../theme/app_theme.dart';

class VoucherForm extends StatefulWidget {
  final String type; // receipt/payment
  final String? contactId;
  const VoucherForm({super.key, required this.type, this.contactId});

  @override
  State<VoucherForm> createState() => _VoucherFormState();
}

class _VoucherFormState extends State<VoucherForm> {
  String? _contactId;
  String? _cashboxId;
  late String _date;
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  bool _saving = false;

  // تخصيص الدفعات: invoiceId -> amount
  final Map<String, double> _allocs = {};
  final Map<String, TextEditingController> _allocCtrls = {};

  bool get isReceipt => widget.type == 'receipt';

  @override
  void initState() {
    super.initState();
    _contactId = widget.contactId;
    final n = DateTime.now();
    _date =
        '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<ERPProvider>();
      if (prov.cashboxes.isNotEmpty) {
        _cashboxId = prov.cashboxes.first.id;
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    for (final c in _allocCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _autoDistribute(List<Invoice> invoices) {
    double remaining = double.tryParse(_amount.text) ?? 0;
    setState(() {
      _allocs.clear();
      for (final inv in invoices) {
        if (remaining <= 0) break;
        final take = remaining >= inv.remaining ? inv.remaining : remaining;
        _allocs[inv.id] = take;
        _allocCtrls.putIfAbsent(inv.id, () => TextEditingController());
        _allocCtrls[inv.id]!.text = take.toStringAsFixed(2);
        remaining -= take;
      }
    });
  }

  double get _totalAllocated =>
      _allocs.values.fold(0.0, (s, v) => s + v);

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل مبلغاً صحيحاً')),
      );
      return;
    }
    if (_contactId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر الجهة')),
      );
      return;
    }
    if (_totalAllocated > amount + 0.001) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مجموع التخصيص أكبر من المبلغ')),
      );
      return;
    }
    setState(() => _saving = true);
    final prov = context.read<ERPProvider>();
    final allocations = _allocs.entries
        .where((e) => e.value > 0)
        .map((e) => {'invoiceId': e.key, 'amount': e.value})
        .toList();
    await prov.createPayment(
      paymentType: widget.type,
      date: _date,
      contactId: _contactId,
      cashboxId: _cashboxId,
      amount: amount,
      description: _desc.text,
      allocations: allocations,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isReceipt ? 'تم حفظ سند القبض' : 'تم حفظ سند الصرف'),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final curr = prov.currency;
    final contacts = prov.contacts
        .where((c) =>
            isReceipt ? c.contactType != 'supplier' : c.contactType != 'customer')
        .toList();
    final unpaid = _contactId == null
        ? <Invoice>[]
        : prov.unpaidInvoices(_contactId!, widget.type);

    return Scaffold(
      appBar: AppBar(title: Text(isReceipt ? 'سند قبض' : 'سند صرف')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _contactId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: isReceipt ? 'من العميل' : 'إلى المورد',
                      prefixIcon: const Icon(Icons.person),
                    ),
                    items: contacts
                        .map((c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _contactId = v;
                      _allocs.clear();
                      _allocCtrls.clear();
                    }),
                  ),
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
                                  '${c.name} (${Fmt.money(c.currentBalance, curr)})'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _cashboxId = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'المبلغ ($curr)',
                      prefixIcon: const Icon(Icons.payments),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _desc,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'البيان',
                      prefixIcon: Icon(Icons.notes),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // تخصيص الدفعات
          if (unpaid.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('تخصيص على الفواتير الآجلة',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _autoDistribute(unpaid),
                  icon: const Icon(Icons.auto_fix_high, size: 18),
                  label: const Text('توزيع تلقائي'),
                ),
              ],
            ),
            Card(
              child: Column(
                children: unpaid.map((inv) {
                  _allocCtrls.putIfAbsent(
                      inv.id, () => TextEditingController());
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(inv.invoiceNumber,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              Text(
                                'متبقي: ${Fmt.money(inv.remaining, curr)}',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _allocCtrls[inv.id],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              hintText: '0',
                              isDense: true,
                            ),
                            onChanged: (v) {
                              _allocs[inv.id] = double.tryParse(v) ?? 0;
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'المخصص: ${Fmt.money(_totalAllocated, curr)}',
                style: const TextStyle(fontSize: 12, color: AppColors.info),
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_saving ? 'جاري الحفظ...' : 'حفظ وترحيل'),
            ),
          ),
        ],
      ),
    );
  }
}
