// ============================================================================
// قائمة المستندات التجارية (عروض أسعار / أوامر بيع / أوامر شراء)
// + التحويل إلى فاتورة بضغطة
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/export_button.dart';
import 'order_form.dart';

class OrdersListScreen extends StatefulWidget {
  final String initialDocType; // quotation | sales_order | purchase_order
  const OrdersListScreen({super.key, this.initialDocType = 'quotation'});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  late int _tab;
  String _search = '';

  final _tabs = const [
    ['عروض الأسعار', 'quotation'],
    ['أوامر البيع', 'sales_order'],
    ['أوامر الشراء', 'purchase_order'],
  ];

  @override
  void initState() {
    super.initState();
    _tab = _tabs.indexWhere((t) => t[1] == widget.initialDocType);
    if (_tab < 0) _tab = 0;
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final type = _tabs[_tab][1];
    final list = prov
        .ordersOfType(type)
        .where((o) =>
            _search.isEmpty ||
            o.contactName.contains(_search) ||
            o.docNumber.contains(_search))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('المستندات التجارية'),
        actions: [
          ExportButton(
            title: 'المستندات التجارية — ${_tabs[_tab][0]}',
            companyName: prov.companyName,
            filename: 'orders_$type',
            headers: const ['رقم المستند', 'التاريخ', 'الجهة', 'الحالة', 'الإجمالي'],
            rows: [
              for (final o in list)
                [
                  o.docNumber,
                  o.date,
                  o.contactName,
                  _statusLabel(o.status),
                  Fmt.num(o.total),
                ],
            ],
            totals: [
              'الإجمالي: ${Fmt.money(list.fold(0.0, (s, o) => s + o.total), prov.currency)}',
            ],
          ),
        ],
        bottom: TabBar(
          isScrollable: true,
          onTap: (i) => setState(() => _tab = i),
          tabs: [for (final t in _tabs) Tab(text: t[0])],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'بحث بالاسم أو رقم المستند...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? EmptyState(
                    message: 'لا توجد ${_tabs[_tab][0]}',
                    icon: Icons.description_outlined,
                  )
                : RefreshIndicator(
                    onRefresh: () async => prov.reload(),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _orderTile(context, list[i], prov),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => OrderForm(docType: type)),
          );
          if (ok == true) prov.reload();
        },
        icon: const Icon(Icons.add),
        label: Text('${_tabs[_tab][0]} جديد'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _orderTile(BuildContext context, OrderDoc o, ERPProvider prov) {
    final curr = prov.currency;
    final color = switch (o.docType) {
      'quotation' => AppColors.info,
      'sales_order' => AppColors.success,
      _ => AppColors.warning,
    };
    final canConvert = o.status != 'converted' && o.status != 'cancelled';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => _showActions(context, o, prov),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(
            switch (o.docType) {
              'quotation' => Icons.request_quote,
              'sales_order' => Icons.shopping_cart,
              _ => Icons.shopping_bag,
            },
            color: color,
          ),
        ),
        title: Text(
          o.contactName.isEmpty ? 'جهة نقدية' : o.contactName,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text('${o.docNumber} • ${o.date}',
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                Badge2(o.statusLabel, color: _statusColor(o.status)),
                const SizedBox(width: 6),
                Badge2('${o.lines.length} صنف', color: AppColors.info),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(Fmt.money(o.total, curr),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13)),
            if (canConvert)
              const Text('اضغط للتحويل',
                  style: TextStyle(fontSize: 9, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String s) => switch (s) {
        'draft' => Colors.grey,
        'confirmed' => AppColors.info,
        'converted' => AppColors.success,
        _ => AppColors.danger,
      };

  void _showActions(BuildContext context, OrderDoc o, ERPProvider prov) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text('${o.typeLabel} ${o.docNumber}'),
              subtitle: Text('${o.contactName} • ${Fmt.money(o.total, prov.currency)}'),
            ),
            const Divider(height: 1),
            if (o.status == 'draft')
              ListTile(
                leading: const Icon(Icons.check_circle, color: AppColors.info),
                title: const Text('تأكيد المستند'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await prov.updateOrderStatus(o.id, 'confirmed');
                },
              ),
            if (o.status != 'converted')
              ListTile(
                leading: const Icon(Icons.receipt_long,
                    color: AppColors.success),
                title: const Text('تحويل إلى فاتورة'),
                subtitle: const Text('إنشاء فاتورة من بنود هذا المستند'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _convert(o, prov);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: const Text('حذف'),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await confirmDialog(context,
                    title: 'حذف', message: 'حذف ${o.typeLabel} ${o.docNumber}؟');
                if (ok) await prov.deleteOrder(o.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _convert(OrderDoc o, ERPProvider prov) async {
    String paymentType = 'credit';
    String? cashboxId =
        prov.cashboxes.isNotEmpty ? prov.cashboxes.first.id : null;

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('تحويل إلى فاتورة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('سيتم إنشاء فاتورة من ${o.typeLabel} ${o.docNumber}'),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'cash', label: Text('نقدي')),
                  ButtonSegment(value: 'credit', label: Text('آجل')),
                ],
                selected: {paymentType},
                onSelectionChanged: (s) => setSt(() => paymentType = s.first),
              ),
              if (paymentType == 'cash' && prov.cashboxes.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: cashboxId,
                  decoration: const InputDecoration(labelText: 'الصندوق'),
                  items: prov.cashboxes
                      .map((c) =>
                          DropdownMenuItem(value: c.id, child: Text(c.name)))
                      .toList(),
                  onChanged: (v) => setSt(() => cashboxId = v),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تحويل'),
            ),
          ],
        ),
      ),
    );

    if (go != true) return;
    try {
      final inv = await prov.convertOrderToInvoice(
        o.id,
        paymentType: paymentType,
        cashboxId: paymentType == 'cash' ? cashboxId : null,
      );
      if (!mounted || inv == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إنشاء الفاتورة ${inv.invoiceNumber} بنجاح'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  String _statusLabel(String s) {
    return switch (s) {
      'draft' => 'مسودة',
      'confirmed' => 'مؤكد',
      'converted' => 'محوّل لفاتورة',
      'cancelled' => 'ملغي',
      _ => s,
    };
  }
}
