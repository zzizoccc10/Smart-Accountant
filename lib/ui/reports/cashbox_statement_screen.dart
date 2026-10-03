// ============================================================================
// تقرير حركة الصندوق — Cashbox Statement
// يجمع كل المقبوضات والمدفوعات النقدية مع الرصيد التراكمي
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/export_button.dart';

class CashboxStatementScreen extends StatefulWidget {
  const CashboxStatementScreen({super.key});

  @override
  State<CashboxStatementScreen> createState() =>
      _CashboxStatementScreenState();
}

class _CashboxStatementScreenState extends State<CashboxStatementScreen> {
  String? _cashboxId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<ERPProvider>();
      if (_cashboxId == null && prov.cashboxes.isNotEmpty) {
        setState(() => _cashboxId = prov.cashboxes.first.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final curr = prov.currency;

    final box = prov.cashboxes.where((c) => c.id == _cashboxId).firstOrNull;
    final opening = box?.openingBalance ?? 0.0;

    // جمع الحركات النقدية
    final raw = <Map<String, dynamic>>[];
    for (final inv in prov.invoices) {
      if (inv.cashboxId != _cashboxId || inv.status == 'cancelled') continue;
      final isSale = inv.invoiceType == 'sale';
      final isReturn = inv.isReturn;
      double inAmt = 0, outAmt = 0;
      if (isSale && !isReturn) inAmt = inv.total;
      if (isSale && isReturn) outAmt = inv.total;
      if (!isSale && !isReturn) outAmt = inv.total;
      if (!isSale && isReturn) inAmt = inv.total;
      raw.add({
        'date': inv.date,
        'desc': '${inv.invoiceNumber} — ${inv.contactName.isEmpty ? 'عميل نقدي' : inv.contactName}',
        'in': inAmt,
        'out': outAmt,
      });
    }
    for (final p in prov.payments) {
      if (p.cashboxId != _cashboxId || p.isDeleted) continue;
      raw.add({
        'date': p.date,
        'desc': '${p.paymentType == 'receipt' ? 'سند قبض' : 'سند صرف'} ${p.paymentNumber}',
        'in': p.paymentType == 'receipt' ? p.amount : 0,
        'out': p.paymentType == 'payment' ? p.amount : 0,
      });
    }
    for (final e in prov.expenses) {
      if (e.cashboxId != _cashboxId || e.isDeleted) continue;
      raw.add({
        'date': e.date,
        'desc': 'مصروف: ${e.categoryName}',
        'in': 0.0,
        'out': e.total,
      });
    }
    raw.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

    double running = opening;
    final entries = <Map<String, dynamic>>[];
    for (final e in raw) {
      running += (e['in'] as double) - (e['out'] as double);
      entries.add({...e, 'balance': running});
    }
    final totalIn = raw.fold(0.0, (s, e) => s + (e['in'] as double));
    final totalOut = raw.fold(0.0, (s, e) => s + (e['out'] as double));

    return Scaffold(
      appBar: AppBar(
        title: const Text('حركة الصندوق'),
        actions: [
          if (entries.isNotEmpty)
            ExportButton(
              title: 'حركة الصندوق - ${box?.name ?? ''}',
              companyName: prov.companyName,
              filename: 'cashbox_statement',
              headers: const ['التاريخ', 'البيان', 'وارد', 'صادر', 'الرصيد'],
              rows: [
                ['—', 'رصيد افتتاحي', '', '', Fmt.num(opening)],
                for (final e in entries)
                  [
                    e['date'] as String,
                    e['desc'] as String,
                    (e['in'] as double) > 0 ? Fmt.num(e['in'] as double) : '',
                    (e['out'] as double) > 0
                        ? Fmt.num(e['out'] as double)
                        : '',
                    Fmt.num(e['balance'] as double),
                  ],
              ],
              totals: [
                'إجمالي الوارد: ${Fmt.money(totalIn, curr)}',
                'إجمالي الصادر: ${Fmt.money(totalOut, curr)}',
                'الرصيد: ${Fmt.money(running, curr)}',
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<String>(
              initialValue: prov.cashboxes.any((c) => c.id == _cashboxId)
                  ? _cashboxId
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'اختر الصندوق',
                prefixIcon: Icon(Icons.savings),
              ),
              items: prov.cashboxes
                  .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                  .toList(),
              onChanged: (v) => setState(() => _cashboxId = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: _stat('الرصيد الافتتاحي', Fmt.money(opening, curr),
                      Icons.flag, AppColors.info),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _stat('الرصيد الحالي', Fmt.money(running, curr),
                      Icons.account_balance_wallet, AppColors.success),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: entries.isEmpty
                ? const EmptyState(
                    message: 'لا توجد حركات على هذا الصندوق',
                    icon: Icons.receipt_long_outlined,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: entries.length,
                    itemBuilder: (_, i) {
                      final e = entries[i];
                      final isIn = (e['in'] as double) > 0;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: (isIn
                                    ? AppColors.success
                                    : AppColors.danger)
                                .withValues(alpha: 0.12),
                            child: Icon(
                              isIn ? Icons.south_west : Icons.north_east,
                              size: 18,
                              color: isIn
                                  ? AppColors.success
                                  : AppColors.danger,
                            ),
                          ),
                          title: Text(e['desc'] as String,
                              style: const TextStyle(fontSize: 13)),
                          subtitle: Text(e['date'] as String,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade600)),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                isIn
                                    ? '+ ${Fmt.num(e['in'] as double)}'
                                    : '- ${Fmt.num(e['out'] as double)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isIn
                                      ? AppColors.success
                                      : AppColors.danger,
                                ),
                              ),
                              Text('رصيد: ${Fmt.num(e['balance'] as double)}',
                                  style: const TextStyle(fontSize: 10)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
