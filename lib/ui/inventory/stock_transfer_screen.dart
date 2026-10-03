// ============================================================================
// التحويل المخزني بين المخازن
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

class StockTransferScreen extends StatefulWidget {
  const StockTransferScreen({super.key});

  @override
  State<StockTransferScreen> createState() => _StockTransferScreenState();
}

class _StockTransferScreenState extends State<StockTransferScreen> {
  String _from = '';
  String _to = '';
  bool _init = false;
  final List<Map<String, dynamic>> _lines = [];
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    // تهيئة المخازن من القائمة الفعلية (آمنة ضد التغيير)
    if (!_init && prov.warehouses.length >= 2) {
      _init = true;
      _from = prov.warehouses[0].id;
      _to = prov.warehouses[1].id;
    }
    final whIds = prov.warehouses.map((w) => w.id).toList();
    final safeFrom = whIds.contains(_from) ? _from : null;
    final safeTo = whIds.contains(_to) ? _to : null;

    return Scaffold(
      appBar: AppBar(title: const Text('تحويل مخزني')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: safeFrom,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'من مخزن'),
                      items: prov.warehouses
                          .map((w) => DropdownMenuItem(
                              value: w.id, child: Text(w.name)))
                          .toList(),
                      onChanged: (v) => setState(() => _from = v ?? _from),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_back, color: AppColors.primary),
                  ),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: safeTo,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'إلى مخزن'),
                      items: prov.warehouses
                          .map((w) => DropdownMenuItem(
                              value: w.id, child: Text(w.name)))
                          .toList(),
                      onChanged: (v) => setState(() => _to = v ?? _to),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SectionTitle(
            'الأصناف',
            icon: Icons.list_alt,
            trailing: TextButton.icon(
              onPressed: _addLine,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('إضافة'),
            ),
          ),
          if (_lines.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('لم تُضف أصناف بعد',
                      style: TextStyle(color: Colors.grey)),
                ),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (int i = 0; i < _lines.length; i++)
                    ListTile(
                      title: Text(_lines[i]['name'] as String),
                      subtitle: Text('الكمية: ${Fmt.num(_lines[i]['qty'] as double)}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.close,
                            color: AppColors.danger, size: 18),
                        onPressed: () => setState(() => _lines.removeAt(i)),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('تنفيذ التحويل'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addLine() async {
    final prov = context.read<ERPProvider>();
    if (prov.items.isEmpty) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _TransferLineDialog(items: prov.items),
    );
    if (result != null) setState(() => _lines.add(result));
  }

  Future<void> _save() async {
    if (_lines.isEmpty) return;
    if (_from == _to) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر مخزنين مختلفين')),
      );
      return;
    }
    setState(() => _saving = true);
    final prov = context.read<ERPProvider>();
    final date = DateTime.now().toIso8601String().split('T')[0];
    try {
      await prov.createStockTransfer(
        fromWh: _from,
        toWh: _to,
        date: date,
        lines: _lines,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم التحويل المخزني'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذّر التحويل: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}

class _TransferLineDialog extends StatefulWidget {
  final List items;
  const _TransferLineDialog({required this.items});

  @override
  State<_TransferLineDialog> createState() => _TransferLineDialogState();
}

class _TransferLineDialogState extends State<_TransferLineDialog> {
  dynamic _item;
  final _qty = TextEditingController(text: '1');

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة صنف للتحويل'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<dynamic>(
            initialValue: _item,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'الصنف'),
            items: widget.items
                .map((it) => DropdownMenuItem(
                      value: it,
                      child: Text(it.name),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _item = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _qty,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'الكمية'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _item == null
              ? null
              : () => Navigator.pop(context, {
                    'itemId': _item.id,
                    'name': _item.name,
                    'qty': double.tryParse(_qty.text) ?? 1,
                  }),
          child: const Text('إضافة'),
        ),
      ],
    );
  }
}
