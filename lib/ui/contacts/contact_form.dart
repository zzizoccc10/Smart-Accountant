// ============================================================================
// نموذج جهة الاتصال (عميل/مورد) — إضافة/تعديل
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../models/models.dart';
import '../../data/app_database.dart';

class ContactForm extends StatefulWidget {
  final Contact? contact;
  final String defaultType;
  const ContactForm({super.key, this.contact, this.defaultType = 'customer'});

  @override
  State<ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<ContactForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _phone;
  late TextEditingController _email;
  late TextEditingController _address;
  late TextEditingController _tax;
  late TextEditingController _creditLimit;
  late TextEditingController _opening;
  late String _type;

  @override
  void initState() {
    super.initState();
    final c = widget.contact;
    _name = TextEditingController(text: c?.name ?? '');
    _phone = TextEditingController(text: c?.phone ?? '');
    _email = TextEditingController(text: c?.email ?? '');
    _address = TextEditingController(text: c?.address ?? '');
    _tax = TextEditingController(text: c?.taxNumber ?? '');
    _creditLimit = TextEditingController(
        text: (c?.creditLimit ?? 0) == 0 ? '' : c!.creditLimit.toString());
    _opening = TextEditingController(
        text: (c?.openingBalance ?? 0) == 0 ? '' : c!.openingBalance.toString());
    _type = c?.contactType ?? widget.defaultType;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _tax.dispose();
    _creditLimit.dispose();
    _opening.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final prov = context.read<ERPProvider>();
    final contact = Contact(
      id: widget.contact?.id ?? AppDatabase.newId(),
      code: widget.contact?.code ?? '',
      name: _name.text.trim(),
      contactType: _type,
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      address: _address.text.trim(),
      taxNumber: _tax.text.trim(),
      creditLimit: double.tryParse(_creditLimit.text) ?? 0,
      openingBalance: double.tryParse(_opening.text) ?? 0,
    );
    if (widget.contact == null) {
      final saved = await prov.addContact(contact);
      if (mounted) Navigator.pop(context, saved);
    } else {
      await prov.updateContact(contact);
      if (mounted) Navigator.pop(context, contact);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contact == null ? 'جهة اتصال جديدة' : 'تعديل جهة الاتصال'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'customer', label: Text('عميل')),
                ButtonSegment(value: 'supplier', label: Text('مورد')),
                ButtonSegment(value: 'both', label: Text('كلاهما')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'الاسم',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'الهاتف',
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني',
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(
                labelText: 'العنوان',
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tax,
              decoration: const InputDecoration(
                labelText: 'الرقم الضريبي',
                prefixIcon: Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _creditLimit,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'حد الائتمان',
                      prefixIcon: Icon(Icons.credit_card),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _opening,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'الرصيد الافتتاحي',
                      prefixIcon: Icon(Icons.account_balance_wallet),
                    ),
                  ),
                ),
              ],
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
