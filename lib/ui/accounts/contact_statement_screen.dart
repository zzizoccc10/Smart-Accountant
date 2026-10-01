// ============================================================================
// كشف حساب جهة اتصال — مع رصيد افتتاحي ورصيد تراكمي وتصدير PDF/Excel/CSV
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/export_button.dart';
import '../contacts/contact_form.dart';
import 'voucher_form.dart';

class ContactStatementScreen extends StatelessWidget {
  final String contactId;
  const ContactStatementScreen({super.key, required this.contactId});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final curr = prov.currency;
    final contact = prov.contacts.where((c) => c.id == contactId).firstOrNull;
    if (contact == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('كشف حساب')),
        body: const EmptyState(message: 'غير موجود'),
      );
    }

    // بناء كشف الحساب
    final raw = <Map<String, dynamic>>[];
    for (final inv in prov.invoices) {
      if (inv.contactId != contactId) continue;
      double debit = 0, credit = 0;
      if (inv.invoiceType == 'sale') debit = inv.total;
      if (inv.invoiceType == 'sale_return') credit = inv.total;
      if (inv.invoiceType == 'purchase') credit = inv.total;
      if (inv.invoiceType == 'purchase_return') debit = inv.total;
      raw.add({
        'date': inv.date,
        'desc': '${_invLabel(inv.invoiceType)} ${inv.invoiceNumber}',
        'debit': debit,
        'credit': credit,
      });
    }
    for (final p in prov.payments) {
      if (p.contactId != contactId) continue;
      raw.add({
        'date': p.date,
        'desc':
            '${p.paymentType == 'receipt' ? 'سند قبض' : 'سند صرف'} ${p.paymentNumber}',
        'debit': p.paymentType == 'payment' ? p.amount : 0,
        'credit': p.paymentType == 'receipt' ? p.amount : 0,
      });
    }
    raw.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

    // الرصيد الافتتاحي + الرصيد التراكمي
    final opening = contact.openingBalance;
    double running = opening;
    final entries = <Map<String, dynamic>>[];
    for (final e in raw) {
      running += (e['debit'] as double) - (e['credit'] as double);
      entries.add({...e, 'balance': running});
    }

    final totalDebit = raw.fold(0.0, (s, e) => s + (e['debit'] as double));
    final totalCredit = raw.fold(0.0, (s, e) => s + (e['credit'] as double));
    final balance = opening + totalDebit - totalCredit;

    // صفوف التصدير
    final exportRows = <List<String>>[
      [opening >= 0 ? 'رصيد افتتاحي' : 'رصيد افتتاحي (دائن)', '—', '—', Fmt.num(opening)],
      for (final e in entries)
        [
          e['desc'] as String,
          (e['debit'] as double) > 0 ? Fmt.num(e['debit'] as double) : '',
          (e['credit'] as double) > 0 ? Fmt.num(e['credit'] as double) : '',
          Fmt.num(e['balance'] as double),
        ],
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(contact.name),
        actions: [
          ExportButton(
            title: 'كشف حساب - ${contact.name}',
            companyName: prov.companyName,
            filename: 'statement_${contact.name}',
            headers: ['البيان', 'مدين', 'دائن', 'الرصيد ($curr)'],
            rows: exportRows,
            totals: [
              'إجمالي المدين: ${Fmt.money(totalDebit, curr)}',
              'إجمالي الدائن: ${Fmt.money(totalCredit, curr)}',
              'الرصيد: ${Fmt.money(balance.abs(), curr)} ${balance >= 0 ? '(مدين لنا)' : '(دائن علينا)'}',
            ],
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ContactForm(contact: contact)),
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
                              builder: (_) => VoucherForm(
                                  type: 'receipt', contactId: contactId),
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
                              builder: (_) => VoucherForm(
                                  type: 'payment', contactId: contactId),
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
                        Expanded(
                            child: Text('الرصيد',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                  // الرصيد الافتتاحي
                  Container(
                    color: Colors.grey.withValues(alpha: 0.06),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    child: Row(
                      children: [
                        const Expanded(
                          flex: 3,
                          child: Text('رصيد افتتاحي',
                              style: TextStyle(fontSize: 12)),
                        ),
                        const Expanded(
                            child: Text('-',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12))),
                        const Expanded(
                            child: Text('-',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12))),
                        Expanded(
                          child: Text(
                            Fmt.num(opening),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
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
                          Expanded(
                            child: Text(
                              Fmt.num(e['balance'] as double),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: (e['balance'] as double) >= 0
                                    ? AppColors.info
                                    : AppColors.danger,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // الإجماليات
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    color: AppColors.primary.withValues(alpha: 0.06),
                    child: Row(
                      children: [
                        const Expanded(
                          flex: 3,
                          child: Text('الإجمالي',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Expanded(
                          child: Text(
                            Fmt.num(totalDebit),
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            Fmt.num(totalCredit),
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            Fmt.num(balance),
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold),
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
