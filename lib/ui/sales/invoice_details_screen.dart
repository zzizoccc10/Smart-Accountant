// ============================================================================
// تفاصيل الفاتورة
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../models/models.dart';
import '../../services/print_service.dart';
import '../../services/share_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

class InvoiceDetailsScreen extends StatelessWidget {
  final String invoiceId;
  const InvoiceDetailsScreen({super.key, required this.invoiceId});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final inv = prov.invoices.where((i) => i.id == invoiceId).firstOrNull;
    final curr = prov.currency;

    if (inv == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الفاتورة')),
        body: const EmptyState(message: 'الفاتورة غير موجودة'),
      );
    }

    final isSale = inv.invoiceType.contains('sale');
    final isReturn = inv.invoiceType.contains('return');
    final color = isReturn
        ? AppColors.danger
        : (isSale ? AppColors.success : AppColors.warning);

    return Scaffold(
      appBar: AppBar(
        title: Text(inv.invoiceNumber),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'طباعة',
            onPressed: () => _print(context, prov, inv, false),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'مشاركة PDF',
            onPressed: () => _print(context, prov, inv, true),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'إرسال',
            onSelected: (v) => _send(context, prov, inv, v),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'whatsapp',
                child: ListTile(
                  leading: Icon(Icons.chat, color: Color(0xFF25D366)),
                  title: Text('واتساب'),
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'sms',
                child: ListTile(
                  leading: Icon(Icons.sms),
                  title: Text('رسالة SMS'),
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'email',
                child: ListTile(
                  leading: Icon(Icons.email),
                  title: Text('بريد إلكتروني'),
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'call',
                child: ListTile(
                  leading: Icon(Icons.call),
                  title: Text('اتصال بالعميل'),
                  dense: true,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await confirmDialog(
                context,
                title: 'حذف الفاتورة',
                message:
                    'سيتم حذف الفاتورة فقط (القيود المحاسبية تبقى للسجل). هل أنت متأكد؟',
              );
              if (ok && context.mounted) {
                await prov.deleteInvoice(inv.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.12),
                        child: Icon(
                          isReturn ? Icons.assignment_return : Icons.receipt,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              inv.contactName.isEmpty
                                  ? 'عميل نقدي'
                                  : inv.contactName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${inv.date} • ${inv.paymentType == 'cash' ? 'نقدي' : 'آجل'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Badge2(
                        inv.status == 'posted' ? 'مُرحّلة' : inv.status,
                        color: AppColors.success,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const SectionTitle('الأصناف', icon: Icons.list_alt),
          Card(
            child: Column(
              children: [
                for (final l in inv.lines)
                  ListTile(
                    dense: true,
                    title: Text(l.itemName, style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                      '${Fmt.num(l.quantity)} × ${Fmt.money(l.unitPrice, curr)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Text(
                      Fmt.money(l.lineTotal, curr),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _row('المجموع', Fmt.money(inv.subtotal, curr)),
                  if (inv.discountAmount > 0)
                    _row('الخصم', '- ${Fmt.money(inv.discountAmount, curr)}',
                        color: AppColors.danger),
                  _row('الضريبة', Fmt.money(inv.taxAmount, curr)),
                  if (inv.shipping > 0)
                    _row('التوصيل', Fmt.money(inv.shipping, curr)),
                  const Divider(),
                  _row('الإجمالي', Fmt.money(inv.total, curr), bold: true),
                  if (inv.paymentType == 'credit') ...[
                    _row('المدفوع', Fmt.money(inv.paidAmount, curr)),
                    _row('المتبقي', Fmt.money(inv.remaining, curr),
                        color: AppColors.danger),
                  ],
                ],
              ),
            ),
          ),
          if (inv.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.notes),
                title: const Text('ملاحظات'),
                subtitle: Text(inv.notes),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              fontSize: bold ? 16 : 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// إرسال ملخّص الفاتورة عبر واتساب/SMS/بريد/اتصال
Future<void> _send(
  BuildContext context,
  ERPProvider prov,
  Invoice inv,
  String channel,
) async {
  final phone = _contactPhone(prov, inv.contactId);
  final text = _invoiceText(prov, inv);
  bool ok = false;
  switch (channel) {
    case 'whatsapp':
      ok = await ShareService.whatsapp(text, phone: phone);
      break;
    case 'sms':
      ok = await ShareService.sms(text, phone: phone);
      break;
    case 'email':
      ok = await ShareService.email('فاتورة ${inv.invoiceNumber}', text);
      break;
    case 'call':
      if (phone == null || phone.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا يوجد رقم هاتف لهذه الجهة')),
          );
        }
        return;
      }
      ok = await ShareService.call(phone);
      break;
  }
  if (context.mounted && !ok && channel != 'call') {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذّر فتح التطبيق المطلوب')),
    );
  }
}

String? _contactPhone(ERPProvider prov, String? contactId) {
  if (contactId == null) return null;
  final c = prov.contacts.where((x) => x.id == contactId).firstOrNull;
  return c?.phone;
}

String _invoiceText(ERPProvider prov, Invoice inv) {
  final b = StringBuffer();
  b.writeln(prov.companyName);
  b.writeln('فاتورة رقم: ${inv.invoiceNumber}');
  b.writeln('التاريخ: ${inv.date}');
  b.writeln('الجهة: ${inv.contactName.isEmpty ? "عميل نقدي" : inv.contactName}');
  b.writeln('----------------------');
  for (final l in inv.lines) {
    b.writeln('${l.itemName} × ${l.quantity} = ${l.lineTotal.toStringAsFixed(2)}');
  }
  b.writeln('----------------------');
  b.writeln('الإجمالي: ${Fmt.money(inv.total, prov.currency)}');
  if (inv.remaining > 0) {
    b.writeln('المتبقي: ${Fmt.money(inv.remaining, prov.currency)}');
  }
  return b.toString();
}

/// طباعة أو مشاركة الفاتورة كـ PDF
Future<void> _print(
  BuildContext context,
  ERPProvider prov,
  Invoice inv,
  bool share,
) async {
  try {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('جارٍ تجهيز PDF...')),
    );
    if (share) {
      await PrintService.shareInvoice(
        inv: inv,
        companyName: prov.companyName,
        currency: prov.currency,
        companyPhone: prov.companyPhone,
        companyAddress: prov.companyAddress,
        taxNumber: prov.companyTaxNumber,
        crNumber: prov.companyCrNumber,
        footer: prov.invoiceFooter,
      );
    } else {
      await PrintService.printInvoice(
        inv: inv,
        companyName: prov.companyName,
        currency: prov.currency,
        companyPhone: prov.companyPhone,
        companyAddress: prov.companyAddress,
        taxNumber: prov.companyTaxNumber,
        crNumber: prov.companyCrNumber,
        footer: prov.invoiceFooter,
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذّر إنشاء PDF: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}
