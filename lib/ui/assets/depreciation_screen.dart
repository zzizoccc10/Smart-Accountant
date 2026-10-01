// ============================================================================
// شاشة تشغيل الإهلاك — شهري لأصل واحد أو لكل الأصول
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

class DepreciationScreen extends StatefulWidget {
  const DepreciationScreen({super.key});

  @override
  State<DepreciationScreen> createState() => _DepreciationScreenState();
}

class _DepreciationScreenState extends State<DepreciationScreen> {
  bool _running = false;
  String? _selectedAssetId; // null = كل الأصول

  Future<void> _run(int months) async {
    setState(() => _running = true);
    final prov = context.read<ERPProvider>();
    final count = await prov.runMonthlyDepreciation(
      assetId: _selectedAssetId,
      months: months,
    );
    if (!mounted) return;
    setState(() => _running = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(count == 0
            ? 'لا توجد أصول تحتاج إهلاكاً'
            : 'تم إهلاك $count أصل/أصول لمدة $months شهر'),
        backgroundColor: count == 0 ? AppColors.warning : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final curr = prov.currency;
    final assets = prov.fixedAssets.where((a) => a.status == 'active').toList();

    return Scaffold(
      appBar: AppBar(title: const Text('تشغيل الإهلاك')),
      body: Column(
        children: [
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _btn('شهر', () => _run(1)),
                _btn('ربع سنة', () => _run(3)),
                _btn('نصف سنة', () => _run(6)),
                _btn('سنة', () => _run(12)),
              ],
            ),
          ),
          if (_running) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<String?>(
              initialValue: _selectedAssetId,
              decoration: const InputDecoration(labelText: 'الأصل المطلوب إهلاكه'),
              items: [
                const DropdownMenuItem(value: null, child: Text('كل الأصول')),
                ...assets.map(
                  (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                ),
              ],
              onChanged: (v) => setState(() => _selectedAssetId = v),
            ),
          ),
          Expanded(
            child: assets.isEmpty
                ? const EmptyState(
                    message: 'لا توجد أصول نشطة للإهلاك',
                    icon: Icons.trending_down,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                    itemCount: assets.length,
                    itemBuilder: (_, i) {
                      final a = assets[i];
                      final pct = a.depreciableAmount <= 0
                          ? 0.0
                          : (a.accumulatedDepreciation / a.depreciableAmount)
                              .clamp(0.0, 1.0);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(a.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14)),
                                  ),
                                  Badge2(
                                    a.isFullyDepreciated
                                        ? 'مُهلك بالكامل'
                                        : 'القسط: ${Fmt.num(a.monthlyDepreciation)}',
                                    color: a.isFullyDepreciated
                                        ? AppColors.success
                                        : AppColors.info,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 6,
                                  backgroundColor: Colors.grey.shade200,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'مُهلك: ${Fmt.money(a.accumulatedDepreciation, curr)}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  Text(
                                    'دفترية: ${Fmt.money(a.bookValue, curr)}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.success,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
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

  Widget _btn(String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: _running ? null : onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ),
      ),
    );
  }
}
