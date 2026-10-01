// ============================================================================
// كشف حساب جهة اتصال
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';
import '../contacts/contact_form.dart';
import 'voucher_form.dart';

class ContactStatementScreen extends StatelessWidget {
  final String contactId;
  const ContactStatementScreen({super.key, required this.contactId});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final curr = prov.currency;
    final contact =
        prov.contacts.where((c) => c.id == contactId).firstOrNull;
    if (contact == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('كشف حساب')),
        body: const EmptyState(message: 'غير موجود'),
      );
    }

    // بناء كشف الحساب
    final entries = <Map<String, dynamic>>[];
    for (final inv in prov.invoices) {
      if (inv.contactId != contactId) continue;
      double debit = 0, credit = 0;
      if (inv.invoiceType == 'sale') debit = inv.total;
      if (inv.invoiceType == 'sale_return') credit = inv.total;
      if (inv.invoiceType == 'purchase') credit = inv.total;
      if (inv.invoiceType == 'purchase_return') debit = inv.total;
      entries.add({
        'date': inv.date,
        'desc': '${_invLabel(inv.invoiceType)} ${inv.invoiceNumber}',
        'debit': debit,
        'credit': credit,
      });
    }
    for (final p in prov.payments) {
      if (p.contactId != contactId) continue;
      entries.add({
        'date': p.date,
        'desc': '${p.paymentType == 'receipt' ? 'سند قبض' : 'سند صرف'} ${p.paymentNumber}',
        'debit': p.paymentType == 'payment' ? p.amount : 0,
        'credit': p.paymentType == 'receipt' ? p.amount : 0,
      });
    }
    entries.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

    final totalDebit = entries.fold(0.0, (s, e) => s + (e['debit'] as double));
    final totalCredit = entries.fold(0.0, (s, e) => s + (e['credit'] as double));
    final balance = contact.openingBalance + totalDebit - totalCredit;

    return Scaffold(
      appBar: AppBar(
        title: Text(contact.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ContactForm(contact: contact)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text('الرصيد الحالي',
                          style: TextStyle(color: Colors.grey)),
                      const Spacer(),
                      Text(
                        Fmt.money(balance.abs(), curr),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: balance >= 0
                              ? AppColors.info
                              : AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Badge2(
                      balance >= 0 ? 'مدين لنا' : 'دائن علينا',
                      color: balance >= 0 ? AppColors.info : AppColors.danger,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  VoucherForm(type: 'receipt', contactId: contactId),
                            ),
                          ),
                          icon: const Icon(Icons.call_received, size: 18),
                          label: const Text('قبض'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  VoucherForm(type: 'payment', contactId: contactId),
                            ),
                          ),
                          icon: const Icon(Icons.call_made, size: 18),
                          label: const Text('صرف'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const SectionTitle('كشف الحساب', icon: Icons.receipt_long),
          if (entries.isEmpty)
            const EmptyState(message: 'لا توجد حركات', icon: Icons.receipt_long)
          else
            Card(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    color: AppColors.primary.withValues(alpha: 0.06),
                    child: const Row(
                      children: [
                        Expanded(
                            flex: 3,
                            child: Text('البيان',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(
                            child: Text('مدين',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(
                            child: Text('دائن',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                  for (final e in entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e['desc'] as String,
                                    style: const TextStyle(fontSize: 12)),
                                Text(e['date'] as String,
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Text(
                              (e['debit'] as double) > 0
                                  ? Fmt.num(e['debit'] as double)
                                  : '-',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              (e['credit'] as double) > 0
                                  ? Fmt.num(e['credit'] as double)
                                  : '-',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _invLabel(String t) {
    return switch (t) {
      'sale' => 'فاتورة بيع',
      'sale_return' => 'مرتجع بيع',
      'purchase' => 'فاتورة شراء',
      _ => 'مرتجع شراء',
    };
  }
}
