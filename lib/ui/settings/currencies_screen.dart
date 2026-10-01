// ============================================================================
// شاشة العملات — إدارة العملات وأسعار الصرف
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../models/models.dart';
import '../../data/app_database.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

class CurrenciesScreen extends StatelessWidget {
  const CurrenciesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final list = prov.currencies;

    return Scaffold(
      appBar: AppBar(title: const Text('العملات')),
      body: list.isEmpty
          ? const EmptyState(
              message: 'لا توجد عملات',
              icon: Icons.currency_exchange,
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final c = list[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () => _edit(context, prov, c),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      child: Text(
                        c.code,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(c.name, style: const TextStyle(fontSize: 14)),
                        if (c.isBase) ...[
                          const SizedBox(width: 6),
                          const Badge2('أساسية', color: AppColors.success),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      'الرمز: ${c.symbol} • السعر: ${Fmt.num(c.rate)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.danger),
                      onPressed: c.isBase
                          ? null
                          : () async {
                              final ok = await confirmDialog(
                                context,
                                title: 'حذف العملة',
                                message: 'حذف ${c.name}؟',
                              );
                              if (ok) await prov.deleteCurrency(c.id);
                            },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, prov, null),
        icon: const Icon(Icons.add),
        label: const Text('عملة جديدة'),
      ),
    );
  }

  void _edit(BuildContext context, ERPProvider prov, Currency? c) {
    final code = TextEditingController(text: c?.code ?? '');
    final name = TextEditingController(text: c?.name ?? '');
    final symbol = TextEditingController(text: c?.symbol ?? '');
    final rate = TextEditingController(text: c?.rate.toString() ?? '1');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(c == null ? 'عملة جديدة' : 'تعديل عملة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: code,
                decoration: const InputDecoration(labelText: 'الرمز (USD)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'الاسم'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: symbol,
                decoration: const InputDecoration(labelText: 'الرمز النصي'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: rate,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'سعر الصرف مقابل العملة الأساسية'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final cur = Currency(
                id: c?.id ?? AppDatabase.newId(),
                code: code.text.trim().toUpperCase(),
                name: name.text.trim(),
                symbol: symbol.text.trim(),
                rate: double.tryParse(rate.text) ?? 1,
                isBase: c?.isBase ?? false,
              );
              if (c == null) {
                await prov.addCurrency(cur);
              } else {
                await prov.updateCurrency(cur);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
