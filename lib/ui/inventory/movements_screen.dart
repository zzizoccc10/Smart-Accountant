// ============================================================================
// سجل حركات المخزون
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

class MovementsScreen extends StatelessWidget {
  const MovementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final movements = prov.movements.reversed.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('حركات المخزون')),
      body: movements.isEmpty
          ? const EmptyState(
              message: 'لا توجد حركات مخزون بعد',
              icon: Icons.history,
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: movements.length,
              itemBuilder: (_, i) {
                final m = movements[i];
                final isIn = m.quantityIn > 0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: (isIn
                              ? AppColors.success
                              : AppColors.danger)
                          .withValues(alpha: 0.12),
                      child: Icon(
                        isIn ? Icons.add : Icons.remove,
                        color: isIn ? AppColors.success : AppColors.danger,
                        size: 18,
                      ),
                    ),
                    title: Text(m.itemName,
                        style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                      '${_typeLabel(m.movementType)} • ${m.date}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Text(
                      '${isIn ? '+' : '-'}${Fmt.num(isIn ? m.quantityIn : m.quantityOut)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isIn ? AppColors.success : AppColors.danger,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _typeLabel(String t) {
    return switch (t) {
      'sale' => 'بيع',
      'purchase' => 'شراء',
      'sale_return' => 'مرتجع بيع',
      'purchase_return' => 'مرتجع شراء',
      'transfer_in' => 'تحويل وارد',
      'transfer_out' => 'تحويل صادر',
      'adjustment_in' => 'تسوية زيادة',
      'adjustment_out' => 'تسوية نقص',
      'opening' => 'رصيد افتتاحي',
      _ => t,
    };
  }
}
