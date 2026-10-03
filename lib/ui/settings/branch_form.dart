// ============================================================================
// واجهة إنشاء/تعديل فرع — تحديد مكوّنات الفرع (مخازن/صناديق/مستخدمون)
// مع الربط المحاسبي والمخزني للفرع.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/erp_provider.dart';
import '../../services/account_sync_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

class BranchForm extends StatefulWidget {
  final Branch? branch;
  const BranchForm({super.key, this.branch});

  @override
  State<BranchForm> createState() => _BranchFormState();
}

class _BranchFormState extends State<BranchForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  final _userCtrl = TextEditingController();

  final Set<String> _warehouseIds = {};
  final Set<String> _cashboxIds = {};
  final List<String> _userNames = [];

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.branch;
    _code = TextEditingController(text: b?.code ?? '');
    _name = TextEditingController(text: b?.name ?? '');
    _address = TextEditingController(text: b?.address ?? '');
    _phone = TextEditingController(text: b?.phone ?? '');
    _email = TextEditingController(text: b?.email ?? '');
    _warehouseIds.addAll(b?.warehouseIds ?? const []);
    _cashboxIds.addAll(b?.cashboxIds ?? const []);
    _userNames.addAll(b?.userNames ?? const []);
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _email.dispose();
    _userCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final prov = context.read<ERPProvider>();
    final br = Branch(
      id: widget.branch?.id ?? '',
      code: _code.text.trim(),
      name: _name.text.trim(),
      address: _address.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      isActive: widget.branch?.isActive ?? true,
      warehouseIds: _warehouseIds.toList(),
      cashboxIds: _cashboxIds.toList(),
      userNames: List<String>.from(_userNames),
    );

    if (widget.branch == null) {
      await prov.addBranch(br);
    } else {
      await prov.updateBranch(br);
    }

    // ضمان ربط المخازن والصناديق المختارة بدليل الحسابات
    for (final id in _warehouseIds) {
      final w = prov.warehouses.where((x) => x.id == id).firstOrNull;
      if (w != null) await AccountSyncService.ensureWarehouseAccount(w);
    }
    for (final id in _cashboxIds) {
      final cb = prov.cashboxes.where((x) => x.id == id).firstOrNull;
      if (cb != null) await AccountSyncService.ensureCashboxAccount(cb);
    }
    await prov.syncChartOfAccounts();

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حفظ الفرع ومكوّناته'),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final warehouses = prov.warehouses;
    final cashboxes = prov.cashboxes;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.branch == null ? 'فرع جديد' : 'تعديل الفرع'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // ---------------- البيانات الأساسية ----------------
            const SectionTitle('بيانات الفرع', icon: Icons.storefront),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'اسم الفرع',
                prefixIcon: Icon(Icons.storefront),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _code,
              decoration: const InputDecoration(
                labelText: 'كود الفرع (اختياري)',
                prefixIcon: Icon(Icons.qr_code),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(
                labelText: 'العنوان (اختياري)',
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'الهاتف (اختياري)',
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'البريد (اختياري)',
                prefixIcon: Icon(Icons.email),
              ),
            ),

            const SizedBox(height: 24),

            // ---------------- المخازن ----------------
            SectionTitle(
              'مخازن الفرع',
              icon: Icons.warehouse,
              trailing: Text(
                '${_warehouseIds.length} محدد',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.primary),
              ),
            ),
            if (warehouses.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('لا توجد مخازن — أضفها من شاشة المخازن',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              )
            else
              Card(
                child: Column(
                  children: [
                    for (final w in warehouses)
                      CheckboxListTile(
                        dense: true,
                        value: _warehouseIds.contains(w.id),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _warehouseIds.add(w.id);
                          } else {
                            _warehouseIds.remove(w.id);
                          }
                        }),
                        secondary: const Icon(Icons.warehouse,
                            color: AppColors.purple, size: 20),
                        title: Text(w.name,
                            style: const TextStyle(fontSize: 13)),
                        subtitle: w.location.isEmpty
                            ? null
                            : Text(w.location,
                                style: const TextStyle(fontSize: 11)),
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // ---------------- الصناديق ----------------
            SectionTitle(
              'صناديق الفرع',
              icon: Icons.account_balance_wallet,
              trailing: Text(
                '${_cashboxIds.length} محدد',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.primary),
              ),
            ),
            if (cashboxes.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('لا توجد صناديق — أضفها من شاشة الصناديق',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              )
            else
              Card(
                child: Column(
                  children: [
                    for (final cb in cashboxes)
                      CheckboxListTile(
                        dense: true,
                        value: _cashboxIds.contains(cb.id),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _cashboxIds.add(cb.id);
                          } else {
                            _cashboxIds.remove(cb.id);
                          }
                        }),
                        secondary: const Icon(
                            Icons.account_balance_wallet,
                            color: AppColors.teal, size: 20),
                        title: Text(cb.name,
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                            'الرصيد: ${Fmt.num(cb.currentBalance)}',
                            style: const TextStyle(fontSize: 11)),
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // ---------------- المستخدمون ----------------
            SectionTitle(
              'مستخدمو الفرع',
              icon: Icons.people_alt,
              trailing: Text(
                '${_userNames.length} مستخدم',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.primary),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _userCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم المستخدم',
                      hintText: 'مثال: أحمد محمد',
                      prefixIcon: Icon(Icons.person_add),
                    ),
                    onSubmitted: (_) => _addUser(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addUser,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_userNames.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('لم يُضف مستخدمون للفرع بعد',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              )
            else
              Card(
                child: Column(
                  children: [
                    for (int i = 0; i < _userNames.length; i++)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.person,
                            color: AppColors.indigo, size: 20),
                        title: Text(_userNames[i],
                            style: const TextStyle(fontSize: 13)),
                        trailing: IconButton(
                          icon: const Icon(Icons.close,
                              color: AppColors.danger, size: 18),
                          onPressed: () =>
                              setState(() => _userNames.removeAt(i)),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ الفرع'),
            ),
          ),
        ),
      ),
    );
  }

  void _addUser() {
    final name = _userCtrl.text.trim();
    if (name.isEmpty) return;
    if (_userNames.contains(name)) {
      _userCtrl.clear();
      return;
    }
    setState(() {
      _userNames.add(name);
      _userCtrl.clear();
    });
  }
}
