// ============================================================================
// الهيكل الرئيسي — Bottom Navigation (5 تبويبات) + Drawer
// شجرة التنقل حسب المواصفة (الجزء الخامس)
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/erp_provider.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'sales/sales_home.dart';
import 'inventory/inventory_home.dart';
import 'reports/reports_home.dart';
import 'accounts/accounts_home.dart';
import 'hr/hr_home.dart';
import 'alerts_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _idx = 0;

  final _pages = const [
    DashboardScreen(),
    SalesHome(),
    InventoryHome(),
    AccountsHome(),
    ReportsHome(),
  ];

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(prov.companyName),
            Text(
              'المحاسب السهل',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (ctx) {
              final count = prov.lowStockItems.length +
                  prov.overdueInvoices.length;
              return Stack(
                children: [
                  IconButton(
                    tooltip: 'التنبيهات',
                    icon: const Icon(Icons.notifications_none),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AlertsScreen()),
                    ),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                            minWidth: 16, minHeight: 16),
                        child: Text(
                          '$count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            tooltip: 'الإعدادات',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: IndexedStack(index: _idx, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale_rounded),
            label: 'البيع والشراء',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_rounded),
            label: 'المخزون',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_rounded),
            label: 'الحسابات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'التقارير',
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final prov = context.read<ERPProvider>();
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 44,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                Text(
                  prov.companyName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'المحاسب السهل — ERP',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _tile(context, Icons.dashboard_rounded, 'الرئيسية', 0),
          _tile(context, Icons.point_of_sale_rounded, 'البيع والشراء', 1),
          _tile(context, Icons.inventory_2_rounded, 'المخزون', 2),
          _tile(context, Icons.account_balance_rounded, 'الحسابات', 3),
          _tile(context, Icons.bar_chart_rounded, 'التقارير', 4),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.groups, color: AppColors.teal),
            title: const Text('الموارد البشرية'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HrHome()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings, color: AppColors.primary),
            title: const Text('الإعدادات'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, int index) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        setState(() => _idx = index);
      },
    );
  }
}
