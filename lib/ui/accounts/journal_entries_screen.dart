// ============================================================================
// شاشة قيود اليومية
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../models/models.dart';
import '../../data/app_database.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/export_button.dart';

class JournalEntriesScreen extends StatelessWidget {
  const JournalEntriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final curr = prov.currency;
    final list = prov.journals.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('قيود اليومية'),
        actions: [
          ExportButton(
            title: 'دفتر اليومية',
            companyName: prov.companyName,
            filename: 'journal_entries',
            headers: const [
              'رقم القيد',
              'التاريخ',
              'البيان',
              'الحساب',
              'مدين',
              'دائن'
            ],
            rows: [
              for (final j in list)
                for (final l in j.lines)
                  [
                    j.entryNumber,
                    j.date,
                    j.description,
                    l.accountName,
                    Fmt.num(l.debit),
                    Fmt.num(l.credit),
                  ],
            ],
          ),
        ],
      ),
      body: list.isEmpty
          ? const EmptyState(
              message: 'لا توجد قيود بعد',
              icon: Icons.book_outlined,
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final j = list[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ExpansionTile(
                    leading: const Icon(Icons.book, color: AppColors.purple),
                    title: Text(j.description,
                        style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                      '${j.entryNumber} • ${j.date}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Text(
                      Fmt.money(j.totalDebit, curr),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          children: [
                            const Divider(),
                            const Row(
                              children: [
                                Expanded(
                                    flex: 3,
                                    child: Text('الحساب',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12))),
                                Expanded(
                                    child: Text('مدين',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12))),
                                Expanded(
                                    child: Text('دائن',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12))),
                              ],
                            ),
                            for (final l in j.lines)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                        flex: 3,
                                        child: Text(l.accountName,
                                            style: const TextStyle(
                                                fontSize: 12))),
                                    Expanded(
                                        child: Text(
                                            l.debit > 0
                                                ? Fmt.num(l.debit)
                                                : '-',
                                            textAlign: TextAlign.center,
                                            style:
                                                const TextStyle(fontSize: 12))),
                                    Expanded(
                                        child: Text(
                                            l.credit > 0
                                                ? Fmt.num(l.credit)
                                                : '-',
                                            textAlign: TextAlign.center,
                                            style:
                                                const TextStyle(fontSize: 12))),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const _ManualJournalForm()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('قيد يدوي'),
      ),
    );
  }
}

/// نموذج قيد يدوي بسيط (طرفان)
class _ManualJournalForm extends StatefulWidget {
  const _ManualJournalForm();

  @override
  State<_ManualJournalForm> createState() => _ManualJournalFormState();
}

class _ManualJournalFormState extends State<_ManualJournalForm> {
  Account? _debitAcc;
  Account? _creditAcc;
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text) ?? 0;
    if (amount <= 0 || _debitAcc == null || _creditAcc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أكمل البيانات')),
      );
      return;
    }
    setState(() => _saving = true);
    final date = DateTime.now().toIso8601String().split('T')[0];
    await AppDatabase.saveJournal(JournalEntry(
      id: AppDatabase.newId(),
      entryNumber: await AppDatabase.nextNumber('journal', prefix: 'JV-'),
      date: date,
      description: _desc.text.isEmpty ? 'قيد يدوي' : _desc.text,
      sourceType: 'manual',
      lines: [
        JournalLine(
          accountId: _debitAcc!.id,
          accountName: _debitAcc!.name,
          debit: amount,
        ),
        JournalLine(
          accountId: _creditAcc!.id,
          accountName: _creditAcc!.name,
          credit: amount,
        ),
      ],
    ));
    if (!mounted) return;
    context.read<ERPProvider>().reload();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حفظ القيد'),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final leaves = prov.accounts.where((a) => a.isLeaf).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('قيد يدوي')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<Account>(
            initialValue: leaves.contains(_debitAcc) ? _debitAcc : null,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'الحساب المدين',
              prefixIcon: Icon(Icons.add),
            ),
            items: leaves
                .map((a) => DropdownMenuItem(
                      value: a,
                      child: Text('${a.code} — ${a.name}'),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _debitAcc = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Account>(
            initialValue: leaves.contains(_creditAcc) ? _creditAcc : null,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'الحساب الدائن',
              prefixIcon: Icon(Icons.remove),
            ),
            items: leaves
                .map((a) => DropdownMenuItem(
                      value: a,
                      child: Text('${a.code} — ${a.name}'),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _creditAcc = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'المبلغ',
              prefixIcon: Icon(Icons.payments),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            decoration: const InputDecoration(
              labelText: 'البيان',
              prefixIcon: Icon(Icons.notes),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: const Text('حفظ القيد'),
            ),
          ),
        ],
      ),
    );
  }
}
