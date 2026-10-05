// ============================================================================
// الهيكل الرئيسي — Bottom Navigation + NavigationRail + Drawer
// ----------------------------------------------------------------------------
// • يُصفّي التبويبات والوجهات حسب صلاحيات المستخدم (ModuleRegistry).
// • الزائر (بدون حساب) يرى كل شيء ويعمل محلياً بالكامل.
// • شارة «وضع الزائر (محلي)» تظهر دائماً عند الدخول بدون حساب.
// • إشعارات مالك النظام تظهر ضمن مركز الإشعارات.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/module_registry.dart';
import '../models/user_models.dart';
import '../providers/erp_provider.dart';
import '../providers/session_provider.dart';
import '../services/admin_notification_service.dart';
import '../theme/app_theme.dart';
import 'accounts/accounts_home.dart';
import 'alerts_screen.dart';
import 'assets/assets_home.dart';
import 'auth/login_screen.dart';
import 'dashboard_screen.dart';
import 'hr/hr_home.dart';
import 'inventory/inventory_home.dart';
import 'reports/reports_home.dart';
import 'sales/orders_list_screen.dart';
import 'sales/sales_home.dart';
import 'settings/notifications_screen.dart';
import 'settings/backup_location_screen.dart';
import 'settings/sync_screen.dart';
import 'settings_screen.dart';
import 'system_owner/system_owner_dashboard.dart';
import 'users/sub_users_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _idx = 0;

  @override
  void initState() {
    super.initState();
    // توليد التنبيهات (نقص مخزون/فواتير مستحقة/حد ائتمان) ودفع إشعارات النظام
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ERPProvider>().generateAlerts();
    });
  }

  // --------------------------------------------------------------------------
  // خريطة route → الودجة
  // --------------------------------------------------------------------------
  Widget _widgetFor(AppModule m) {
    switch (m.route) {
      case 'dashboard':
        return const DashboardScreen();
      case 'sales':
        return const SalesHome();
      case 'inventory':
        return const InventoryHome();
      case 'accounts':
        return const AccountsHome();
      case 'reports':
        return const ReportsHome();
      default:
        return const DashboardScreen();
    }
  }

  IconData _iconFor(AppModule m) {
    switch (m.key) {
      case 'dashboard':
        return Icons.dashboard_rounded;
      case 'sales':
        return Icons.point_of_sale_rounded;
      case 'inventory':
        return Icons.inventory_2_rounded;
      case 'accounts':
        return Icons.account_balance_rounded;
      case 'reports':
        return Icons.bar_chart_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  /// الوجهات الإضافية في الدرج (رابط الشاشة)
  Widget? _drawerExtraScreen(AppModule m) {
    switch (m.route) {
      case 'orders':
        return const OrdersListScreen();
      case 'subUsers':
        return const SubUsersScreen();
      case 'hr':
        return const HrHome();
      case 'assets':
        return const AssetsHome();
      case 'expenses':
        return const AlertsScreen();
      case 'settings':
        return const SettingsScreen();
      case 'sync':
        return const SyncScreen();
      case 'backup':
        return const BackupLocationScreen();
      default:
        return null;
    }
  }

  IconData _extraIcon(AppModule m) {
    switch (m.key) {
      case 'orders':
        return Icons.description_outlined;
      case 'subUsers':
        return Icons.people_alt;
      case 'hr':
        return Icons.groups;
      case 'assets':
        return Icons.business;
      case 'expenses':
        return Icons.receipt_long;
      case 'settings':
        return Icons.settings;
      case 'sync':
        return Icons.cloud_sync;
      case 'backup':
        return Icons.backup;
      default:
        return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final session = context.watch<SessionProvider>();

    // التبويبات المسموحة حسب الصلاحيات
    final tabs = ModuleRegistry.allowedTabs(
      isGuest: session.isGuest,
      isSystemOwner: session.isSystemOwner,
      perms: session.permissions,
    );
    final safeTabs = tabs.isEmpty ? [ModuleRegistry.dashboard] : tabs;
    if (_idx >= safeTabs.length) _idx = 0;

    final isWide = MediaQuery.sizeOf(context).width >= 900;

    final appBar = AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(prov.companyName),
          Text(
            session.isGuest ? 'وضع الزائر — محلي فقط' : 'المحاسب السهل',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
      actions: _appActions(context, prov, session),
    );

    final body = Column(
      children: [
        if (session.isGuest) _guestBanner(),
        Expanded(
          child: IndexedStack(
            index: _idx,
            children: safeTabs.map(_widgetFor).toList(),
          ),
        ),
      ],
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
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: AppColors.primary,
                  ),
                ),
              ),
              destinations: safeTabs
                  .map(
                    (m) => NavigationRailDestination(
                      icon: Icon(_iconFor(m)),
                      label: Text(m.labelAr),
                    ),
                  )
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      drawer: _buildDrawer(context, session),
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
        items: safeTabs
            .map(
              (m) => BottomNavigationBarItem(
                icon: Icon(_iconFor(m)),
                label: m.labelAr,
              ),
            )
            .toList(),
      ),
    );
  }

  /// شارة الوضع المحلي للزائر
  Widget _guestBanner() {
    return Material(
      color: AppColors.warning.withValues(alpha: 0.14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: [
            const Icon(Icons.explore, size: 16, color: AppColors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'تستعرض النظام كزائر — كل العمليات تُحفَظ محلياً على جهازك فقط',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.brown.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _goToLogin(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 30),
              ),
              child: const Text(
                'إنشاء حساب',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  List<Widget> _appActions(
    BuildContext context,
    ERPProvider prov,
    SessionProvider session,
  ) {
    return [
      Builder(
        builder: (ctx) {
          final adminCount = AdminNotificationService.unreadCount(
            session.currentCompanyId,
          );
          final count = prov.unreadNotifications + adminCount;
          return Stack(
            children: [
              IconButton(
                tooltip: 'الإشعارات',
                icon: const Icon(Icons.notifications_none),
                onPressed: () => _showNotificationsMenu(context, prov, session),
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
                      minWidth: 16,
                      minHeight: 16,
                    ),
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

  /// قائمة الإشعارات: إشعارات مالك النظام + التنبيهات + مركز الإشعارات
  void _showNotificationsMenu(
    BuildContext context,
    ERPProvider prov,
    SessionProvider session,
  ) {
    final adminItems = AdminNotificationService.forCompany(
      session.currentCompanyId,
    );
    final unreadAdmin = AdminNotificationService.unreadCount(
      session.currentCompanyId,
    );
    final unread = prov.unreadNotifications;
    final alerts = prov.lowStockItems.length + prov.overdueInvoices.length;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
            if (adminItems.isNotEmpty) ...[
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0x1A6A1B9A),
                  child: Icon(
                    Icons.campaign,
                    color: AppColors.purple,
                    size: 20,
                  ),
                ),
                title: const Text('إشعارات إدارة النظام'),
                subtitle: Text(
                  '$unreadAdmin غير مقروء • ${adminItems.length} إشعار',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_left),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
            ],
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0x1AC62828),
                child: Icon(
                  Icons.notifications,
                  color: AppColors.danger,
                  size: 20,
                ),
              ),
              title: const Text('مركز الإشعارات'),
              subtitle: Text(
                '$unread إشعار غير مقروء',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_left),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0x1AF57C00),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  size: 20,
                ),
              ),
              title: const Text('التنبيهات السريعة'),
              subtitle: Text(
                '$alerts تنبيه حالي',
                style: const TextStyle(fontSize: 12),
              ),
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

  // --------------------------------------------------------------------------
  Widget _buildDrawer(BuildContext context, SessionProvider session) {
    final prov = context.read<ERPProvider>();
    final user = session.currentUser;
    final company = session.activeCompany;
    final extras = ModuleRegistry.allowedDrawerExtras(
      isGuest: session.isGuest,
      isSystemOwner: session.isSystemOwner,
      perms: session.permissions,
    );

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(gradient: AppGradients.brand),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      child: Text(
                        user?.initials ?? '؟',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? 'زائر',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            user != null
                                ? '${user.role.labelAr}${company != null ? ' • ${company.companyName}' : (session.isGuest ? ' • محلي' : '')}'
                                : 'المحاسب السهل — ERP',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  prov.companyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  session.modeLabelAr,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // لوحة تحكم مالك النظام (تظهر فقط في وضع مالك النظام)
          if (session.isSystemOwner) ...[
            ListTile(
              leading: const Icon(
                Icons.admin_panel_settings,
                color: AppColors.purple,
              ),
              title: const Text('لوحة تحكم مالك النظام'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SystemOwnerDashboard(),
                  ),
                );
              },
            ),
            const Divider(),
          ],

          // التبويبات الرئيسية المسموحة
          ...ModuleRegistry.allowedTabs(
            isGuest: session.isGuest,
            isSystemOwner: session.isSystemOwner,
            perms: session.permissions,
          ).map((m) {
            final i = ModuleRegistry.allowedTabs(
              isGuest: session.isGuest,
              isSystemOwner: session.isSystemOwner,
              perms: session.permissions,
            ).indexWhere((x) => x.key == m.key);
            return _tile(context, _iconFor(m), m.labelAr, i);
          }),

          const Divider(),

          // الوجهات الإضافية المسموحة
          ...extras.map((m) {
            final screen = _drawerExtraScreen(m);
            return ListTile(
              leading: Icon(_extraIcon(m), color: AppColors.teal),
              title: Text(m.labelAr),
              onTap: screen == null
                  ? null
                  : () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => screen),
                      );
                    },
            );
          }),

          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.danger),
            title: const Text('تسجيل الخروج'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (dlgCtx) => AlertDialog(
                  title: const Text('تسجيل الخروج'),
                  content: const Text(
                    'هل تريد تسجيل الخروج والعودة لشاشة الدخول؟',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dlgCtx, false),
                      child: const Text('إلغاء'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(dlgCtx, true),
                      child: const Text('خروج'),
                    ),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await context.read<SessionProvider>().signOut();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _goToLogin(BuildContext context) {
    context.read<SessionProvider>().signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
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
