// ============================================================================
// سجل السندات (سندات القبض والصرف) — عرض + طباعة PDF + مشاركة
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../models/models.dart';
import '../../services/print_service.dart';
import '../../services/share_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

class VouchersScreen extends StatefulWidget {
  const VouchersScreen({super.key});

  @override
  State<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends State<VouchersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  List<Payment> _filter(List<Payment> src) {
    if (_q.isEmpty) return src;
    final q = _q.toLowerCase();
    return src
        .where((p) =>
            p.paymentNumber.toLowerCase().contains(q) ||
            p.contactName.toLowerCase().contains(q) ||
            p.description.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final all = prov.payments;
    final receipts = _filter(all.where((p) => p.paymentType == 'receipt').toList());
    final payments = _filter(all.where((p) => p.paymentType == 'payment').toList());

    return Scaffold(
      appBar: AppBar(
        title: const Text('السندات'),
        bottom: TabBar(
          controller: _tab,
          tabs: [
            Tab(text: 'الكل (${_filter(all).length})'),
            Tab(text: 'قبض (${receipts.length})'),
            Tab(text: 'صرف (${payments.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'بحث برقم السند أو الجهة...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _q = v.trim()),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _list(context, prov, _filter(all)),
                _list(context, prov, receipts),
                _list(context, prov, payments),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(BuildContext context, ERPProvider prov, List<Payment> items) {
    if (items.isEmpty) {
      return const EmptyState(
        message: 'لا توجد سندات',
        icon: Icons.receipt_long_outlined,
      );
    }
    final sorted = [...items]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: sorted.length,
      itemBuilder: (_, i) => _tile(context, prov, sorted[i]),
    );
  }

  Widget _tile(BuildContext context, ERPProvider prov, Payment p) {
    final isReceipt = p.paymentType == 'receipt';
    final color = isReceipt ? AppColors.success : AppColors.warning;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.14),
          child: Icon(isReceipt ? Icons.call_received : Icons.call_made,
              color: color, size: 20),
        ),
        title: Text('${isReceipt ? 'سند قبض' : 'سند صرف'} • ${p.paymentNumber}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${p.contactName.isEmpty ? '—' : p.contactName} • ${p.date}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(Fmt.money(p.amount, prov.currency),
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold, color: color)),
            const Icon(Icons.more_horiz, size: 16),
          ],
        ),
        onTap: () => _showActions(context, prov, p),
      ),
    );
  }

  void _showActions(BuildContext context, ERPProvider prov, Payment p) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.print),
              title: const Text('طباعة السند (PDF)'),
              onTap: () {
                Navigator.pop(ctx);
                _print(context, prov, p, false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('مشاركة ملف PDF'),
              onTap: () {
                Navigator.pop(ctx);
                _print(context, prov, p, true);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.chat, color: Color(0xFF25D366)),
              title: const Text('إرسال عبر واتساب'),
              onTap: () {
                Navigator.pop(ctx);
                _shareText(context, prov, p, 'whatsapp');
              },
            ),
            ListTile(
              leading: const Icon(Icons.sms),
              title: const Text('إرسال رسالة SMS'),
              onTap: () {
                Navigator.pop(ctx);
                _shareText(context, prov, p, 'sms');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _print(
      BuildContext context, ERPProvider prov, Payment p, bool share) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('جارٍ تجهيز PDF...')),
      );
      final cashbox = prov.cashboxes
          .where((c) => c.id == p.cashboxId)
          .map((c) => c.name)
          .firstOrNull ??
          '';
      if (share) {
        await PrintService.shareVoucher(
          v: p,
          companyName: prov.companyName,
          currency: prov.currency,
          companyPhone: prov.companyPhone,
          companyAddress: prov.companyAddress,
          taxNumber: prov.companyTaxNumber,
          crNumber: prov.companyCrNumber,
          cashboxName: cashbox,
          footer: prov.invoiceFooter,
          logoBytes: prov.companyLogoBytes,
        );
      } else {
        await PrintService.printVoucher(
          v: p,
          companyName: prov.companyName,
          currency: prov.currency,
          companyPhone: prov.companyPhone,
          companyAddress: prov.companyAddress,
          taxNumber: prov.companyTaxNumber,
          crNumber: prov.companyCrNumber,
          cashboxName: cashbox,
          footer: prov.invoiceFooter,
          logoBytes: prov.companyLogoBytes,
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

  Future<void> _shareText(
      BuildContext context, ERPProvider prov, Payment p, String via) async {
    final contact = prov.contacts
        .where((c) => c.id == p.contactId)
        .firstOrNull;
    final phone = contact?.phone ?? '';
    final isReceipt = p.paymentType == 'receipt';
    final b = StringBuffer();
    b.writeln('*${prov.companyName}*');
    b.writeln(isReceipt ? 'سند قبض' : 'سند صرف');
    b.writeln('--------------------');
    b.writeln('رقم: ${p.paymentNumber}');
    b.writeln('التاريخ: ${p.date}');
    b.writeln(isReceipt ? 'من: ${p.contactName}' : 'إلى: ${p.contactName}');
    b.writeln('المبلغ: ${Fmt.money(p.amount, prov.currency)}');
    if (p.description.isNotEmpty) b.writeln('البيان: ${p.description}');
    final text = b.toString();

    bool ok;
    if (via == 'whatsapp') {
      ok = await ShareService.whatsapp(text, phone: phone);
    } else {
      ok = await ShareService.sms(text, phone: phone);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'تم فتح التطبيق' : 'تعذّر فتح التطبيق'),
          backgroundColor: ok ? AppColors.success : AppColors.danger,
        ),
      );
    }
  }
}
