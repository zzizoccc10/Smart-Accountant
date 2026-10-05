// ============================================================================
// وحدة الأصول الثابتة والإهلاك
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';
import 'asset_form.dart';
import 'depreciation_screen.dart';

class AssetsHome extends StatefulWidget {
  const AssetsHome({super.key});

  @override
  State<AssetsHome> createState() => _AssetsHomeState();
}

class _AssetsHomeState extends State<AssetsHome> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final curr = prov.currency;
    final assets = prov.fixedAssets
        .where(
          (a) =>
              _search.isEmpty ||
              a.name.contains(_search) ||
              a.code.contains(_search),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('الأصول الثابتة')),
      body: Column(
        children: [
          // إجراءات
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _actionBtn(
                  context,
                  Icons.add_business,
                  'أصل جديد',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AssetForm()),
                  ),
                ),
                _actionBtn(
                  context,
                  Icons.trending_down,
                  'تشغيل الإهلاك',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DepreciationScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ملخص
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'إجمالي التكلفة',
                    value: Fmt.money(prov.totalAssetCost, curr),
                    icon: Icons.account_balance,
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: 'مجمع الإهلاك',
                    value: Fmt.money(prov.totalAccumulatedDepreciation, curr),
                    icon: Icons.trending_down,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: StatCard(
              title: 'صافي القيمة الدفترية',
              value: Fmt.money(prov.totalAssetBookValue, curr),
              icon: Icons.savings,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'بحث عن أصل...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: assets.isEmpty
                ? EmptyState(
                    message: 'لا توجد أصول ثابتة — أضف أصلاً للبدء',
                    icon: Icons.business_outlined,
                    actionLabel: 'إضافة أصل',
                    onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AssetForm()),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                    itemCount: assets.length,
                    itemBuilder: (_, i) {
                      final a = assets[i];
                      final disposed = a.status == 'disposed';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AssetForm(asset: a),
                            ),
                          ),
                          leading: CircleAvatar(
                            backgroundColor:
                                (disposed ? Colors.grey : AppColors.primary)
                                    .withValues(alpha: 0.12),
                            child: Icon(
                              _categoryIcon(a.category),
                              color: disposed ? Colors.grey : AppColors.primary,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            a.name,
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(
                            '${a.category} • ${Fmt.num(a.cost)} $curr',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                Fmt.money(a.bookValue, curr),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: disposed
                                      ? Colors.grey
                                      : AppColors.success,
                                ),
                              ),
                              Text(
                                disposed
                                    ? 'مُخرَّد'
                                    : 'القسط الشهري: ${Fmt.num(a.monthlyDepreciation)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: disposed
                                      ? AppColors.danger
                                      : Colors.grey.shade600,
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

  Widget _actionBtn(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'أراضي':
        return Icons.landscape;
      case 'مباني':
        return Icons.apartment;
      case 'سيارات':
        return Icons.directions_car;
      case 'أثاث':
        return Icons.chair;
      case 'أجهزة كمبيوتر':
        return Icons.computer;
      case 'آلات ومعدات':
        return Icons.precision_manufacturing;
      default:
        return Icons.category;
    }
  }
}
