// ============================================================================
// نموذج الحساب — إضافة/تعديل
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../models/models.dart';
import '../../data/app_database.dart';
import '../../services/account_sync_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

class AccountForm extends StatefulWidget {
  final Account? account;
  const AccountForm({super.key, this.account});

  @override
  State<AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<AccountForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _code;
  late TextEditingController _name;
  late TextEditingController _opening;
  String _type = 'asset';
  String _nature = 'debit';
  String? _parentId;
  bool _isLeaf = true;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _code = TextEditingController(text: a?.code ?? '');
    _name = TextEditingController(text: a?.name ?? '');
    _opening = TextEditingController(
        text: (a?.openingBalance ?? 0) == 0 ? '' : a!.openingBalance.toString());
    _type = a?.accountType ?? 'asset';
    _nature = a?.accountNature ?? 'debit';
    _parentId = a?.parentId;
    _isLeaf = a?.isLeaf ?? true;
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _opening.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final prov = context.read<ERPProvider>();
    final Account? parent = _parentId == null
        ? null
        : prov.accounts.where((a) => a.id == _parentId).firstOrNull;
    final acc = Account(
      id: widget.account?.id ?? AppDatabase.newId(),
      code: _code.text.trim(),
      name: _name.text.trim(),
      accountType: _type,
      accountNature: _nature,
      parentId: _parentId,
      level: parent == null ? 1 : parent.level + 1,
      isLeaf: _isLeaf,
      openingBalance: double.tryParse(_opening.text) ?? 0,
      isSystem: widget.account?.isSystem ?? false,
    );
    if (widget.account == null) {
      await prov.addAccount(acc);
      // الأب يصبح حساباً رئيسياً (غير قابل للقيود)
      if (parent != null && parent.isLeaf) {
        parent.isLeaf = false;
        await prov.updateAccount(parent);
      }
    } else {
      await prov.updateAccount(acc);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final parents =
        prov.accounts.where((a) => a.id != widget.account?.id).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account == null ? 'حساب جديد' : 'تعديل حساب'),
        actions: [
          if (widget.account != null && !(widget.account!.isSystem))
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'حذف الحساب',
                  message: 'هل أنت متأكد من حذف هذا الحساب؟',
                );
                if (ok && context.mounted) {
                  await prov.deleteAccount(widget.account!.id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _code,
              decoration: const InputDecoration(
                labelText: 'رمز الحساب (مثال: 1-1-01)',
                prefixIcon: Icon(Icons.tag),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'اسم الحساب',
                prefixIcon: Icon(Icons.label),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'نوع الحساب',
                prefixIcon: Icon(Icons.category),
              ),
              items: const [
                DropdownMenuItem(value: 'asset', child: Text('أصول')),
                DropdownMenuItem(value: 'liability', child: Text('خصوم')),
                DropdownMenuItem(value: 'equity', child: Text('حقوق ملكية')),
                DropdownMenuItem(value: 'revenue', child: Text('إيرادات')),
                DropdownMenuItem(value: 'expense', child: Text('مصروفات')),
              ],
              onChanged: (v) => setState(() => _type = v ?? 'asset'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _nature,
              decoration: const InputDecoration(
                labelText: 'طبيعة الرصيد',
                prefixIcon: Icon(Icons.compare_arrows),
              ),
              items: const [
                DropdownMenuItem(value: 'debit', child: Text('مدين')),
                DropdownMenuItem(value: 'credit', child: Text('دائن')),
              ],
              onChanged: (v) => setState(() => _nature = v ?? 'debit'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: parents.any((a) => a.id == _parentId)
                  ? _parentId
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'الحساب الأب',
                prefixIcon: Icon(Icons.account_tree),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('حساب رئيسي')),
                ...parents.map((a) => DropdownMenuItem(
                      value: a.id,
                      child: Text('${a.code} — ${a.name}'),
                    )),
              ],
              onChanged: (v) => setState(() {
                _parentId = v;
                // اقتراح كود فرعي تلقائي عند اختيار أب (للحسابات الجديدة)
                if (v != null && widget.account == null) {
                  final parent =
                      prov.accounts.where((a) => a.id == v).firstOrNull;
                  if (parent != null) {
                    _code.text = AccountSyncService.nextChildCode(
                        parent.code, prov.accounts);
                  }
                }
              }),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _isLeaf,
              onChanged: (v) => setState(() => _isLeaf = v),
              title: const Text('حساب فرعي (يقبل القيود)'),
              activeThumbColor: AppColors.primary,
            ),
            if (_isLeaf) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _opening,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'الرصيد الافتتاحي',
                  prefixIcon: Icon(Icons.account_balance_wallet),
                ),
              ),
            ],
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
