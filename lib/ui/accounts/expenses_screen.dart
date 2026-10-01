// ============================================================================
// شاشة المصروفات
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final curr = prov.currency;
    final list = prov.expenses.reversed.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('المصروفات')),
      body: list.isEmpty
          ? const EmptyState(
              message: 'لا توجد مصروفات',
              icon: Icons.money_off,
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final e = list[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0x1AC62828),
                      child: Icon(Icons.money_off, color: AppColors.danger),
                    ),
                    title: Text(e.categoryName,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${e.expenseNumber} • ${e.date}${e.description.isNotEmpty ? ' • ${e.description}' : ''}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Text(
                      Fmt.money(e.total, curr),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: AppColors.danger),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const _ExpenseForm()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('مصروف جديد'),
      ),
    );
  }
}

class _ExpenseForm extends StatefulWidget {
  const _ExpenseForm();

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  ExpenseCategory? _category;
  String? _cashboxId;
  late String _date;
  final _amount = TextEditingController();
  final _tax = TextEditingController();
  final _desc = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _date =
        '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<ERPProvider>();
      if (prov.expenseCategories.isNotEmpty) {
        _category = prov.expenseCategories.first;
      }
      if (prov.cashboxes.isNotEmpty) {
        _cashboxId = prov.cashboxes.first.id;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _tax.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text) ?? 0;
    if (amount <= 0 || _category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أكمل البيانات المطلوبة')),
      );
      return;
    }
    setState(() => _saving = true);
    final prov = context.read<ERPProvider>();
    await prov.createExpense(
      date: _date,
      category: _category!,
      amount: amount,
      taxAmount: double.tryParse(_tax.text) ?? 0,
      cashboxId: _cashboxId,
      description: _desc.text,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تسجيل المصروف وترحيل القيد'),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final curr = prov.currency;
    return Scaffold(
      appBar: AppBar(title: const Text('مصروف جديد')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<ExpenseCategory>(
                    initialValue: _category,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'التصنيف',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: prov.expenseCategories
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c.name),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _category = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _cashboxId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'الصندوق الدافع',
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
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _amount,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'المبلغ ($curr)',
                            prefixIcon: const Icon(Icons.payments),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _tax,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'ضريبة',
                            prefixIcon: Icon(Icons.percent),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _desc,
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
