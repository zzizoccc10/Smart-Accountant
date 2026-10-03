// ============================================================================
// إدارة المخازن — إضافة/تعديل/حذف مع الربط التلقائي بدليل الحسابات
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/erp_provider.dart';
import '../../services/account_sync_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

class WarehousesScreen extends StatelessWidget {
  const WarehousesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final list = prov.warehouses;

    return Scaffold(
      appBar: AppBar(
        title: const Text('المخازن'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'مزامنة المخازن مع دليل الحسابات',
            onPressed: () async {
              final n = await prov.syncChartOfAccounts();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(n > 0
                        ? 'تمت المزامنة — تحديث $n عنصر'
                        : 'المخازن متزامنة بالفعل'),
                    backgroundColor:
                        n > 0 ? AppColors.success : AppColors.info,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: list.isEmpty
          ? EmptyState(
              message: 'لا توجد مخازن — أضف مخزناً للبدء',
              icon: Icons.warehouse_outlined,
              actionLabel: 'إضافة مخزن',
              onAction: () => _openForm(context, prov, null),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final w = list[i];
                final acc = prov.accounts
                    .where((a) => a.name == 'مخزون: ${w.name}')
                    .firstOrNull;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () => _openForm(context, prov, w),
                    leading: CircleAvatar(
                      backgroundColor:
                          AppColors.purple.withValues(alpha: 0.12),
                      child: const Icon(Icons.warehouse,
                          color: AppColors.purple, size: 20),
                    ),
                    title: Text(w.name,
                        style: const TextStyle(fontSize: 14)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (w.location.isNotEmpty)
                          Text('الموقع: ${w.location}',
                              style: const TextStyle(fontSize: 12)),
                        Text(
                          acc != null
                              ? 'الحساب: ${acc.code} — ${acc.name}'
                              : 'غير مرتبط بحساب (اضغط للمزامنة)',
                          style: TextStyle(
                            fontSize: 11,
                            color: acc != null
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Badge2(w.allowNegative ? 'سالب مسموح' : 'سالب ممنوع',
                            color: w.allowNegative
                                ? AppColors.warning
                                : AppColors.success),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppColors.danger, size: 20),
                          onPressed: () async {
                            final ok = await confirmDialog(
                              context,
                              title: 'حذف المخزن',
                              message:
                                  'سيتم حذف المخزن "${w.name}". هل أنت متأكد؟',
                            );
                            if (ok) await prov.deleteWarehouse(w.id);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context, prov, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _openForm(BuildContext context, ERPProvider prov, Warehouse? w) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WarehouseForm(warehouse: w)),
    );
  }
}

class WarehouseForm extends StatefulWidget {
  final Warehouse? warehouse;
  const WarehouseForm({super.key, this.warehouse});

  @override
  State<WarehouseForm> createState() => _WarehouseFormState();
}

class _WarehouseFormState extends State<WarehouseForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _location;
  bool _allowNegative = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final w = widget.warehouse;
    _name = TextEditingController(text: w?.name ?? '');
    _code = TextEditingController(text: w?.code ?? '');
    _location = TextEditingController(text: w?.location ?? '');
    _allowNegative = w?.allowNegative ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final prov = context.read<ERPProvider>();
    final w = Warehouse(
      id: widget.warehouse?.id ?? '',
      name: _name.text.trim(),
      code: _code.text.trim(),
      location: _location.text.trim(),
      allowNegative: _allowNegative,
      isActive: true,
    );
    await prov.saveWarehouse(w);
    // ربط تلقائي بدليل الحسابات
    await AccountSyncService.ensureWarehouseAccount(
      Warehouse(
        id: w.id.isEmpty ? 'tmp' : w.id,
        name: w.name,
        code: w.code,
        location: w.location,
        allowNegative: w.allowNegative,
      ),
    );
    prov.reload();
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حفظ المخزن وربطه بدليل الحسابات'),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.warehouse == null ? 'مخزن جديد' : 'تعديل المخزن'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'اسم المخزن',
                prefixIcon: Icon(Icons.warehouse),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _code,
              decoration: const InputDecoration(
                labelText: 'كود المخزن (اختياري)',
                prefixIcon: Icon(Icons.qr_code),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(
                labelText: 'الموقع (اختياري)',
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _allowNegative,
              onChanged: (v) => setState(() => _allowNegative = v),
              title: const Text('السماح بالرصيد السالب'),
              subtitle: const Text('السماح بالبيع دون رصيد كافٍ'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save),
                label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
