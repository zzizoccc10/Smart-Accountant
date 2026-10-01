// ============================================================================
// شاشة الباركود/QR — عرض وطباعة ملصق الصنف
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../../providers/erp_provider.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';

class BarcodeScreen extends StatefulWidget {
  final String? itemId;
  const BarcodeScreen({super.key, this.itemId});

  @override
  State<BarcodeScreen> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends State<BarcodeScreen> {
  Item? _selected;
  int _copies = 1;

  @override
  void initState() {
    super.initState();
    if (widget.itemId != null) {
      final prov = context.read<ERPProvider>();
      _selected = prov.items.where((i) => i.id == widget.itemId).firstOrNull;
    }
  }

  String _codeFor(Item i) {
    if (i.barcode.trim().isNotEmpty) return i.barcode.trim();
    // توليد كود من معرف الصنف
    return i.code.isNotEmpty ? i.code : i.id.substring(0, 8).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final items = prov.items;

    return Scaffold(
      appBar: AppBar(title: const Text('ملصق الباركود')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<Item>(
            initialValue: _selected,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'اختر الصنف',
              prefixIcon: Icon(Icons.inventory_2),
            ),
            items: items
                .map((i) => DropdownMenuItem(value: i, child: Text(i.name)))
                .toList(),
            onChanged: (v) => setState(() => _selected = v),
          ),
          const SizedBox(height: 16),
          if (_selected != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      _selected!.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Fmt.money(_selected!.salePrice, prov.currency),
                      style: const TextStyle(
                          color: AppColors.success, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    BarcodeWidget(
                      barcode: Barcode.code128(),
                      data: _codeFor(_selected!),
                      width: 250,
                      height: 90,
                      drawText: true,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'الكود: ${_codeFor(_selected!)}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('عدد النسخ: '),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _copies > 1
                      ? () => setState(() => _copies--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$_copies',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: () => setState(() => _copies++),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // معاينة الملصقات
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                _copies.clamp(1, 24),
                (_) => Container(
                  width: 160,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    children: [
                      Text(_selected!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10)),
                      Text(Fmt.money(_selected!.salePrice, prov.currency),
                          style: const TextStyle(fontSize: 9)),
                      BarcodeWidget(
                        barcode: Barcode.code128(),
                        data: _codeFor(_selected!),
                        height: 36,
                        drawText: true,
                        style: const TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('اختر صنفاً لعرض الباركود',
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
        ],
      ),
    );
  }
}
