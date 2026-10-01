// ============================================================================
// شاشة الصناديق
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../models/models.dart';
import '../../data/app_database.dart';
import '../../theme/app_theme.dart';

class CashboxesScreen extends StatelessWidget {
  const CashboxesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final curr = prov.currency;

    return Scaffold(
      appBar: AppBar(title: const Text('الصناديق')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet,
                      color: AppColors.success, size: 32),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('إجمالي الأرصدة',
                          style: TextStyle(color: Colors.grey)),
                      Text(
                        Fmt.money(prov.cashBalance, curr),
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final c in prov.cashboxes)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0x1A2E7D32),
                  child: Icon(Icons.savings, color: AppColors.success),
                ),
                title: Text(c.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(c.accountName,
                    style: const TextStyle(fontSize: 12)),
                trailing: Text(
                  Fmt.money(c.currentBalance, curr),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _addCashbox(context, prov),
              icon: const Icon(Icons.add),
              label: const Text('إضافة صندوق'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addCashbox(BuildContext context, ERPProvider prov) async {
    final nameCtrl = TextEditingController();
    final acc = AppDatabase.accountByCode('1-1-01-001');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('صندوق جديد'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'اسم الصندوق'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      await AppDatabase.saveCashbox(Cashbox(
        id: AppDatabase.newId(),
        name: nameCtrl.text.trim(),
        accountId: acc?.id ?? '',
        accountName: acc?.name ?? '',
      ));
      prov.reload();
    }
  }
}
