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
import 'sales/orders_list_screen.dart';
import 'inventory/inventory_home.dart';
import 'reports/reports_home.dart';
import 'accounts/accounts_home.dart';
import 'hr/hr_home.dart';
import 'assets/assets_home.dart';
import 'alerts_screen.dart';
import 'settings/notifications_screen.dart';
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
  void initState() {
    super.initState();
    // توليد التنبيهات (نقص مخزون/فواتير مستحقة/حد ائتمان) ودفع إشعارات النظام
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ERPProvider>().generateAlerts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    // تصميم متجاوب: الشاشات العريضة (تابلت) تستخدم NavigationRail جانبي
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    final appBar = AppBar(
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
      actions: _appActions(context, prov),
    );

    if (isWide) {
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _idx,
              onDestinationSelected: (i) => setState(() => _idx = i),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: const Icon(Icons.account_balance_wallet_rounded,
                      color: AppColors.primary),
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                    icon: Icon(Icons.dashboard_rounded), label: Text('الرئيسية')),
                NavigationRailDestination(
                    icon: Icon(Icons.point_of_sale_rounded),
                    label: Text('البيع والشراء')),
                NavigationRailDestination(
                    icon: Icon(Icons.inventory_2_rounded),
                    label: Text('المخزون')),
                NavigationRailDestination(
                    icon: Icon(Icons.account_balance_rounded),
                    label: Text('الحسابات')),
                NavigationRailDestination(
                    icon: Icon(Icons.bar_chart_rounded), label: Text('التقارير')),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: IndexedStack(index: _idx, children: _pages),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
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


  List<Widget> _appActions(BuildContext context, ERPProvider prov) {
    return [
            Builder(
              builder: (ctx) {
                final count = prov.unreadNotifications;
                return Stack(
                  children: [
                    IconButton(
                      tooltip: 'الإشعارات',
                      icon: const Icon(Icons.notifications_none),
                      onPressed: () => _showNotificationsMenu(context, prov),
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
                            count > 99 ? '99+' : '$count',
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
    ];
  }

  /// قائمة الإشعارات: التنبيهات السريعة + مركز الإشعارات
  void _showNotificationsMenu(BuildContext context, ERPProvider prov) {
    final unread = prov.unreadNotifications;
    final alerts = prov.lowStockItems.length + prov.overdueInvoices.length;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0x1AC62828),
                child: Icon(Icons.notifications, color: AppColors.danger, size: 20),
              ),
              title: const Text('مركز الإشعارات'),
              subtitle: Text('$unread إشعار غير مقروء',
                  style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_left),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NotificationsScreen()),
                );
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0x1AF57C00),
                child: Icon(Icons.warning_amber_rounded,
                    color: AppColors.warning, size: 20),
              ),
              title: const Text('التنبيهات السريعة'),
              subtitle: Text('$alerts تنبيه حالي',
                  style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_left),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AlertsScreen()),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
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
          ListTile(
            leading: const Icon(Icons.description_outlined,
                color: AppColors.info),
            title: const Text('عروض الأسعار والأوامر'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const OrdersListScreen()),
              );
            },
          ),
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
            leading: const Icon(Icons.business, color: AppColors.warning),
            title: const Text('الأصول الثابتة والإهلاك'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AssetsHome()),
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
