// ============================================================================
// سجل الوحدات — ModuleRegistry
// ----------------------------------------------------------------------------
// يربط كل «وجهة/وحدة» في التطبيق بمفتاح الصلاحية المطلوب لعرضها.
// يُستخدم في:
//   • تصفية التبويبات السفلية (BottomNav) والدرج الجانبي (Drawer).
//   • حماية الشاشات من الفتح المباشر لمن لا يملك صلاحيتها.
// الزائر (بدون حساب) يرى كل شيء (وضع استكشاف كامل، محلياً).
// ============================================================================
import '../models/user_models.dart';

/// صلاحية إلزامية (كل الصلاحيات في [any] مطلوبة)
class PermReq {
  final List<String> any; // يكفي امتلاك أيٍّ منها (فارغة = متاح للجميع)
  final List<String> all; // يجب امتلاك كلّها

  const PermReq({this.any = const [], this.all = const []});

  bool get isOpen => any.isEmpty && all.isEmpty;
}

/// تعريف وحدة/وجهة في التطبيق
class AppModule {
  final String key; // معرّف فريد
  final String labelAr;
  final String route; // اسم المنطقي (يُستخدم للتنقل)
  final PermReq permission;

  const AppModule({
    required this.key,
    required this.labelAr,
    required this.route,
    this.permission = const PermReq(),
  });
}

class ModuleRegistry {
  // ---------------------------- التبويبات الرئيسية ----------------------------
  static const dashboard = AppModule(
    key: 'dashboard',
    labelAr: 'الرئيسية',
    route: 'dashboard',
  );

  static const sales = AppModule(
    key: 'sales',
    labelAr: 'البيع والشراء',
    route: 'sales',
    permission: PermReq(any: [
      Perm.salesView, Perm.salesCreate, Perm.purchasesView,
      Perm.purchasesCreate, Perm.contactsView, Perm.contactsManage,
    ]),
  );

  static const inventory = AppModule(
    key: 'inventory',
    labelAr: 'المخزون',
    route: 'inventory',
    permission: PermReq(any: [
      Perm.inventoryView, Perm.inventoryManage, Perm.inventoryTransfer,
      Perm.inventoryCount,
    ]),
  );

  static const accounts = AppModule(
    key: 'accounts',
    labelAr: 'الحسابات',
    route: 'accounts',
    permission: PermReq(any: [
      Perm.accountsView, Perm.accountsManage, Perm.journalView,
      Perm.journalCreate, Perm.cashView, Perm.cashManage,
    ]),
  );

  static const reports = AppModule(
    key: 'reports',
    labelAr: 'التقارير',
    route: 'reports',
    permission: PermReq(any: [Perm.reportsView, Perm.reportsExport]),
  );

  /// التبويبات الرئيسية في الشريط السفلي/الجانبي (بالترتيب)
  static const List<AppModule> rootTabs = [
    dashboard,
    sales,
    inventory,
    accounts,
    reports,
  ];

  // ---------------------------- الوجهات الإضافية (Drawer) ----------------------------
  static const subUsers = AppModule(
    key: 'subUsers',
    labelAr: 'مستخدمو المنشأة',
    route: 'subUsers',
    permission: PermReq(any: [Perm.usersView, Perm.usersManage]),
  );

  static const hr = AppModule(
    key: 'hr',
    labelAr: 'الموارد البشرية',
    route: 'hr',
    permission: PermReq(any: [Perm.hrView, Perm.hrManage]),
  );

  static const assets = AppModule(
    key: 'assets',
    labelAr: 'الأصول الثابتة والإهلاك',
    route: 'assets',
    permission: PermReq(any: [Perm.assetsView, Perm.assetsManage]),
  );

  static const orders = AppModule(
    key: 'orders',
    labelAr: 'عروض الأسعار والأوامر',
    route: 'orders',
    permission: PermReq(any: [Perm.salesView, Perm.salesCreate]),
  );

  static const expenses = AppModule(
    key: 'expenses',
    labelAr: 'المصروفات',
    route: 'expenses',
    permission: PermReq(any: [Perm.accountsView, Perm.accountsManage]),
  );

  static const settings = AppModule(
    key: 'settings',
    labelAr: 'الإعدادات',
    route: 'settings',
    permission: PermReq(any: [Perm.settingsView, Perm.settingsManage]),
  );

  static const sync = AppModule(
    key: 'sync',
    labelAr: 'المزامنة السحابية',
    route: 'sync',
    permission: PermReq(any: [Perm.syncManage]),
  );

  static const backup = AppModule(
    key: 'backup',
    labelAr: 'النسخ الاحتياطي',
    route: 'backup',
    permission: PermReq(any: [Perm.backupManage]),
  );

  /// الوجهات الإضافية في الدرج (بالترتيب)
  static const List<AppModule> drawerExtras = [
    orders,
    subUsers,
    hr,
    assets,
    expenses,
    settings,
    sync,
    backup,
  ];

  // ---------------------------- الفحص ----------------------------

  /// هل يملك المستخدم صلاحية الوصول للوحدة؟
  /// - [isGuest] = true → الوصول مفتوح بالكامل (وضع استكشاف محلي).
  /// - [isSystemOwner] = true → مالك النظام يرى كل شيء.
  /// - [perms] = null (مستخدم غير محدّد) → مفتوح.
  static bool canAccess({
    required AppModule module,
    required bool isGuest,
    required bool isSystemOwner,
    Set<String>? perms,
  }) {
    if (isGuest || isSystemOwner) return true;
    if (perms == null) return true;
    final req = module.permission;
    if (req.isOpen) return true;
    final anyOk = req.any.isEmpty || req.any.any(perms.contains);
    final allOk = req.all.isEmpty || req.all.every(perms.contains);
    return anyOk && allOk;
  }

  /// التبويبات المسموحة حسب الصلاحيات
  static List<AppModule> allowedTabs({
    required bool isGuest,
    required bool isSystemOwner,
    Set<String>? perms,
  }) =>
      rootTabs
          .where((m) => canAccess(
              module: m,
              isGuest: isGuest,
              isSystemOwner: isSystemOwner,
              perms: perms))
          .toList();

  /// الوجهات الإضافية المسموحة
  static List<AppModule> allowedDrawerExtras({
    required bool isGuest,
    required bool isSystemOwner,
    Set<String>? perms,
  }) =>
      drawerExtras
          .where((m) => canAccess(
              module: m,
              isGuest: isGuest,
              isSystemOwner: isSystemOwner,
              perms: perms))
          .toList();
}
