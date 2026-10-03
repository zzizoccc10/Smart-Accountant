// ============================================================================
// شاشة الجرد الفعلي — حسب المواصفة 5.4
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../data/app_database.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

class StockCountScreen extends StatefulWidget {
  const StockCountScreen({super.key});

  @override
  State<StockCountScreen> createState() => _StockCountScreenState();
}

class _StockCountScreenState extends State<StockCountScreen> {
  String _warehouseId = '';
  final Map<String, TextEditingController> _controllers = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<ERPProvider>();
      if (prov.warehouses.isNotEmpty) {
        setState(() => _warehouseId = prov.warehouses.first.id);
      }
    });
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final items = prov.items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الجرد الفعلي'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text('تثبيت', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<String>(
              initialValue: prov.warehouses.any((w) => w.id == _warehouseId)
                  ? _warehouseId
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'المخزن',
                prefixIcon: Icon(Icons.warehouse),
              ),
              items: prov.warehouses
                  .map((w) =>
                      DropdownMenuItem(value: w.id, child: Text(w.name)))
                  .toList(),
              onChanged: (v) => setState(() => _warehouseId = v ?? 'wh_main'),
            ),
          ),
          if (items.isEmpty)
            const Expanded(
              child: EmptyState(message: 'لا توجد أصناف للجرد'),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final it = items[i];
                  final bookQty =
                      AppDatabase.balanceOf(it.id, _warehouseId).quantity;
                  final ctrl = _controllers.putIfAbsent(
                    it.id,
                    () => TextEditingController(text: bookQty.toStringAsFixed(0)),
                  );
                  final actual = double.tryParse(ctrl.text) ?? bookQty;
                  final diff = actual - bookQty;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(it.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text(
                                  'دفترية: ${Fmt.num(bookQty)}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: TextField(
                              controller: ctrl,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                labelText: 'فعلية',
                                isDense: true,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 56,
                            child: Text(
                              diff == 0
                                  ? '0'
                                  : (diff > 0 ? '+${Fmt.num(diff)}' : Fmt.num(diff)),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: diff == 0
                                    ? AppColors.success
                                    : (diff > 0
                                        ? AppColors.info
                                        : AppColors.danger),
                              ),
                            ),
                          ),
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

  Future<void> _save() async {
    final prov = context.read<ERPProvider>();
    final lines = <Map<String, dynamic>>[];
    for (final it in prov.items) {
      final ctrl = _controllers[it.id];
      if (ctrl == null) continue;
      final actual = double.tryParse(ctrl.text);
      if (actual == null) continue;
      lines.add({'itemId': it.id, 'actualQty': actual});
    }
    if (lines.isEmpty) return;

    setState(() => _saving = true);
    final date = DateTime.now().toIso8601String().split('T')[0];
    await prov.createStockAdjustment(
      warehouseId: _warehouseId,
      date: date,
      lines: lines,
      notes: 'جرد فعلي',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تثبيت الجرد وترحيل القيد'),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.pop(context);
  }
}
