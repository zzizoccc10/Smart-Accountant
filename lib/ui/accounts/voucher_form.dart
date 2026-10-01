// ============================================================================
// نموذج سند القبض/الصرف
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    super.dispose();
  }

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
    setState(() => _saving = true);
    final prov = context.read<ERPProvider>();
    await prov.createPayment(
      paymentType: widget.type,
      date: _date,
      contactId: _contactId,
      cashboxId: _cashboxId,
      amount: amount,
      description: _desc.text,
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
        .where((c) => isReceipt ? c.contactType != 'supplier' : c.contactType != 'customer')
        .toList();

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
                    onChanged: (v) => setState(() => _contactId = v),
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
