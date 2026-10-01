// ============================================================================
// لوحة التحكم الرئيسية — Dashboard
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/erp_provider.dart';
import '../theme/app_theme.dart';
import 'widgets/common.dart';
import 'sales/sales_list_screen.dart';
import 'sales/invoice_form.dart';
import 'inventory/inventory_home.dart';
import 'accounts/accounts_home.dart';
import 'reports/reports_home.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final curr = prov.currency;

    return RefreshIndicator(
      onRefresh: () async => prov.reload(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ترحيب
          Card(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'أهلاً بك 👋',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          prov.companyName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'رصيد الصندوق: ${Fmt.money(prov.cashBalance, curr)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 56,
                    color: Colors.white24,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // بطاقات الإحصاءات
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: [
              StatCard(
                title: 'مبيعات اليوم',
                value: Fmt.money(prov.todaySales, curr),
                icon: Icons.trending_up_rounded,
                color: AppColors.success,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SalesListScreen(initialTab: 0),
                  ),
                ),
              ),
              StatCard(
                title: 'مشتريات اليوم',
                value: Fmt.money(prov.todayPurchases, curr),
                icon: Icons.trending_down_rounded,
                color: AppColors.warning,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SalesListScreen(initialTab: 2),
                  ),
                ),
              ),
              StatCard(
                title: 'الذمم المدينة',
                value: Fmt.money(prov.totalReceivables, curr),
                icon: Icons.call_received_rounded,
                color: AppColors.info,
              ),
              StatCard(
                title: 'الذمم الدائنة',
                value: Fmt.money(prov.totalPayables, curr),
                icon: Icons.call_made_rounded,
                color: AppColors.danger,
              ),
              StatCard(
                title: 'قيمة المخزون',
                value: Fmt.money(prov.inventoryValue, curr),
                icon: Icons.inventory_2_rounded,
                color: AppColors.purple,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InventoryHome()),
                ),
              ),
              StatCard(
                title: 'عدد الأصناف',
                value: '${prov.items.length}',
                icon: Icons.category_rounded,
                color: AppColors.teal,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // رسم بياني للمبيعات
          const SectionTitle('مبيعات آخر 7 أيام', icon: Icons.show_chart),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 20, 16, 12),
              child: SizedBox(
                height: 180,
                child: _SalesChart(data: prov.weeklySales),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // إجراءات سريعة
          const SectionTitle('إجراءات سريعة', icon: Icons.flash_on),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.95,
            children: [
              _quickAction(
                context,
                Icons.point_of_sale,
                'بيع جديد',
                AppColors.success,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const InvoiceForm(invoiceType: 'sale'),
                  ),
                ),
              ),
              _quickAction(
                context,
                Icons.shopping_cart,
                'شراء جديد',
                AppColors.warning,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const InvoiceForm(invoiceType: 'purchase'),
                  ),
                ),
              ),
              _quickAction(
                context,
                Icons.assignment_return,
                'المرتجعات',
                AppColors.danger,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SalesListScreen(initialTab: 1),
                  ),
                ),
              ),
              _quickAction(
                context,
                Icons.inventory_2,
                'المخزون',
                AppColors.purple,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InventoryHome()),
                ),
              ),
              _quickAction(
                context,
                Icons.account_balance,
                'الحسابات',
                AppColors.primary,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AccountsHome()),
                ),
              ),
              _quickAction(
                context,
                Icons.bar_chart,
                'التقارير',
                AppColors.teal,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReportsHome()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // آخر الفواتير
          SectionTitle(
            'آخر الفواتير',
            icon: Icons.receipt_long,
            trailing: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SalesListScreen(initialTab: 0),
                ),
              ),
              child: const Text('عرض الكل'),
            ),
          ),
          if (prov.invoices.isEmpty)
            const EmptyState(
              message: 'لا توجد فواتير بعد',
              icon: Icons.receipt_long_outlined,
            )
          else
            ...prov.invoices.reversed.take(5).map((inv) {
              final isSale = inv.invoiceType.contains('sale');
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        (isSale ? AppColors.success : AppColors.warning)
                            .withValues(alpha: 0.12),
                    child: Icon(
                      isSale ? Icons.arrow_upward : Icons.arrow_downward,
                      color: isSale ? AppColors.success : AppColors.warning,
                    ),
                  ),
                  title: Text(
                    '${inv.contactName} — ${inv.invoiceNumber}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    '${inv.date} • ${inv.invoiceType.contains('return') ? 'مرتجع' : ''}${inv.paymentType == 'cash' ? 'نقدي' : 'آجل'}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Text(
                    Fmt.money(inv.total, curr),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _quickAction(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const _SalesChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxVal = data.fold<double>(
      0,
      (m, e) => (e['total'] as double) > m ? (e['total'] as double) : m,
    );
    final maxY = maxVal == 0 ? 100.0 : maxVal * 1.2;

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: Colors.grey.shade200, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= data.length) return const SizedBox();
                final d = data[i]['day'] as DateTime;
                const days = [
                  'اثن',
                  'ثلا',
                  'أرب',
                  'خمي',
                  'جمع',
                  'سبت',
                  'أحد',
                ];
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    days[d.weekday - 1],
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(data.length, (i) {
          final total = data[i]['total'] as double;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: total,
                color: AppColors.primary,
                width: 16,
                borderRadius: BorderRadius.circular(6),
              ),
            ],
          );
        }),
      ),
    );
  }
}
