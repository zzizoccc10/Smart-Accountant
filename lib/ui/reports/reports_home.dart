// ============================================================================
// وحدة التقارير المالية
// ============================================================================
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'trial_balance_screen.dart';
import 'income_statement_screen.dart';
import 'balance_sheet_screen.dart';
import 'sales_report_screen.dart';
import 'inventory_report_screen.dart';
import 'aging_report_screen.dart';

class ReportsHome extends StatelessWidget {
  const ReportsHome({super.key});

  @override
  Widget build(BuildContext context) {
    final reports = [
      _Report(Icons.balance, 'ميزان المراجعة', AppColors.primary,
          'أرصدة جميع الحسابات', () => const TrialBalanceScreen()),
      _Report(Icons.trending_up, 'الأرباح والخسائر', AppColors.success,
          'الإيرادات والمصروفات', () => const IncomeStatementScreen()),
      _Report(Icons.account_balance, 'المركز المالي', AppColors.info,
          'الميزانية العمومية', () => const BalanceSheetScreen()),
      _Report(Icons.point_of_sale, 'تقرير المبيعات', AppColors.teal,
          'ملخص المبيعات', () => const SalesReportScreen()),
      _Report(Icons.inventory, 'تقرير المخزون', AppColors.purple,
          'الأرصدة والقيمة', () => const InventoryReportScreen()),
      _Report(Icons.hourglass_bottom, 'أعمار الديون', AppColors.warning,
          'الذمم حسب العمر', () => const AgingReportScreen()),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final r in reports) ...[
          Card(
            child: ListTile(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => r.builder()),
              ),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: r.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(r.icon, color: r.color),
              ),
              title: Text(r.title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(r.subtitle,
                  style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_left),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _Report {
  final IconData icon;
  final String title;
  final Color color;
  final String subtitle;
  final Widget Function() builder;
  _Report(this.icon, this.title, this.color, this.subtitle, this.builder);
}
