// ============================================================================
// نماذج المستخدمين والأدوار والصلاحيات — المحاسب السهل
// ----------------------------------------------------------------------------
// نظام صلاحيات دقيق (Permission-Based) مبني على أدوار (Roles) قابلة للتخصيص.
// يعمل محلياً (Hive) ويُزامَن مع Firestore عند تفعيل السحابة.
// ============================================================================

/// الأدوار الافتراضية الجاهزة في النظام
enum UserRole {
  owner, // المالك — كل الصلاحيات
  admin, // مدير النظام
  accountant, // محاسب
  sales, // مندوب مبيعات
  warehouse, // أمين مخزن
  viewer, // مشاهد فقط (قراءة)
}

extension UserRoleX on UserRole {
  String get key => name;

  String get labelAr {
    switch (this) {
      case UserRole.owner:
        return 'المالك';
      case UserRole.admin:
        return 'مدير النظام';
      case UserRole.accountant:
        return 'محاسب';
      case UserRole.sales:
        return 'مبيعات';
      case UserRole.warehouse:
        return 'أمين مخزن';
      case UserRole.viewer:
        return 'مشاهد';
    }
  }

  static UserRole fromKey(String? k) {
    return UserRole.values.firstWhere(
      (r) => r.name == k,
      orElse: () => UserRole.viewer,
    );
  }
}

/// الصلاحيات الدقيقة في النظام (Permission Keys)
/// كل صلاحية تتحكم في جزء محدد من التطبيق.
class Perm {
  // ---- المبيعات ----
  static const salesView = 'sales.view';
  static const salesCreate = 'sales.create';
  static const salesEdit = 'sales.edit';
  static const salesDelete = 'sales.delete';

  // ---- المشتريات ----
  static const purchasesView = 'purchases.view';
  static const purchasesCreate = 'purchases.create';
  static const purchasesEdit = 'purchases.edit';
  static const purchasesDelete = 'purchases.delete';

  // ---- المخزون ----
  static const inventoryView = 'inventory.view';
  static const inventoryManage = 'inventory.manage'; // إضافة/تعديل أصناف
  static const inventoryTransfer = 'inventory.transfer';
  static const inventoryCount = 'inventory.count';

  // ---- جهات الاتصال ----
  static const contactsView = 'contacts.view';
  static const contactsManage = 'contacts.manage';

  // ---- الحسابات والقيود ----
  static const accountsView = 'accounts.view';
  static const accountsManage = 'accounts.manage';
  static const journalView = 'journal.view';
  static const journalCreate = 'journal.create';
  static const journalDelete = 'journal.delete';

  // ---- الخزينة والبنوك ----
  static const cashView = 'cash.view';
  static const cashManage = 'cash.manage';

  // ---- التقارير ----
  static const reportsView = 'reports.view';
  static const reportsExport = 'reports.export';

  // ---- الموارد البشرية ----
  static const hrView = 'hr.view';
  static const hrManage = 'hr.manage';

  // ---- الأصول الثابتة ----
  static const assetsView = 'assets.view';
  static const assetsManage = 'assets.manage';

  // ---- الإعدادات ----
  static const settingsView = 'settings.view';
  static const settingsManage = 'settings.manage';

  // ---- المستخدمون والصلاحيات ----
  static const usersView = 'users.view';
  static const usersManage = 'users.manage';

  // ---- المزامنة والنسخ الاحتياطي ----
  static const syncManage = 'sync.manage';
  static const backupManage = 'backup.manage';

  /// كل الصلاحيات المتاحة في النظام
  static const all = <String>[
    salesView,
    salesCreate,
    salesEdit,
    salesDelete,
    purchasesView,
    purchasesCreate,
    purchasesEdit,
    purchasesDelete,
    inventoryView,
    inventoryManage,
    inventoryTransfer,
    inventoryCount,
    contactsView,
    contactsManage,
    accountsView,
    accountsManage,
    journalView,
    journalCreate,
    journalDelete,
    cashView,
    cashManage,
    reportsView,
    reportsExport,
    hrView,
    hrManage,
    assetsView,
    assetsManage,
    settingsView,
    settingsManage,
    usersView,
    usersManage,
    syncManage,
    backupManage,
  ];

  /// الاسم العربي لكل صلاحية (للعرض في واجهة الإدارة)
  static const Map<String, String> labelsAr = {
    salesView: 'عرض المبيعات',
    salesCreate: 'إنشاء فاتورة بيع',
    salesEdit: 'تعديل المبيعات',
    salesDelete: 'حذف المبيعات',
    purchasesView: 'عرض المشتريات',
    purchasesCreate: 'إنشاء فاتورة شراء',
    purchasesEdit: 'تعديل المشتريات',
    purchasesDelete: 'حذف المشتريات',
    inventoryView: 'عرض المخزون',
    inventoryManage: 'إدارة الأصناف',
    inventoryTransfer: 'تحويل بين المخازن',
    inventoryCount: 'جرد المخزون',
    contactsView: 'عرض جهات الاتصال',
    contactsManage: 'إدارة جهات الاتصال',
    accountsView: 'عرض دليل الحسابات',
    accountsManage: 'إدارة الحسابات',
    journalView: 'عرض القيود اليومية',
    journalCreate: 'إنشاء قيد يدوي',
    journalDelete: 'حذف قيد',
    cashView: 'عرض الخزينة',
    cashManage: 'إدارة الخزينة',
    reportsView: 'عرض التقارير',
    reportsExport: 'تصدير التقارير',
    hrView: 'عرض الموارد البشرية',
    hrManage: 'إدارة الموظفين',
    assetsView: 'عرض الأصول الثابتة',
    assetsManage: 'إدارة الأصول',
    settingsView: 'عرض الإعدادات',
    settingsManage: 'تعديل الإعدادات',
    usersView: 'عرض المستخدمين',
    usersManage: 'إدارة المستخدمين والصلاحيات',
    syncManage: 'إدارة المزامنة',
    backupManage: 'إدارة النسخ الاحتياطي',
  };

  /// مجموعة الصلاحيات الافتراضية لكل دور
  static Set<String> defaultsForRole(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return {...all};
      case UserRole.admin:
        // كل شيء عدا إدارة المالك نفسه (حماية)
        return {...all}..remove(usersManage);
      case UserRole.accountant:
        return {
          accountsView,
          accountsManage,
          journalView,
          journalCreate,
          journalDelete,
          reportsView,
          reportsExport,
          cashView,
          cashManage,
          salesView,
          purchasesView,
          contactsView,
          contactsManage,
          inventoryView,
          assetsView,
          settingsView,
        };
      case UserRole.sales:
        return {
          salesView,
          salesCreate,
          salesEdit,
          contactsView,
          contactsManage,
          inventoryView,
          reportsView,
          cashView,
        };
      case UserRole.warehouse:
        return {
          inventoryView,
          inventoryManage,
          inventoryTransfer,
          inventoryCount,
          purchasesView,
          purchasesCreate,
          reportsView,
        };
      case UserRole.viewer:
        return {
          salesView,
          purchasesView,
          inventoryView,
          contactsView,
          accountsView,
          reportsView,
        };
    }
  }
}

/// نموذج المستخدم
class AppUser {
  final String id; // uid من Firebase Auth أو UUID محلي
  String name;
  String email;
  String username; // اسم المستخدم (للدخول من داخل المنشأة)
  String passwordHash; // تجزئة كلمة المرور (SHA-256 + salt)
  String passwordSalt; // الملح
  String phone;
  UserRole role;
  Set<String> permissions; // صلاحيات مخصّصة (تتجاوز الدور إن وُجدت)
  bool useRoleDefaults; // إن كانت true نستخدم صلاحيات الدور الافتراضية
  bool isActive;
  String? branchId; // الفرع المرتبط (اختياري)
  String? photoUrl;
  String? fcmToken; // رمز الإشعارات السحابية
  String companyId; // المنشأة التابع لها المستخدم
  String createdBy; // معرّف من أنشأ هذا المستخدم (المالك الرئيسي)
  String createdAt;
  String updatedAt;
  bool synced; // هل تمّت مزامنته مع السحابة

  AppUser({
    required this.id,
    required this.name,
    this.email = '',
    this.username = '',
    this.passwordHash = '',
    this.passwordSalt = '',
    this.phone = '',
    this.role = UserRole.viewer,
    Set<String>? permissions,
    this.useRoleDefaults = true,
    this.isActive = true,
    this.branchId,
    this.photoUrl,
    this.fcmToken,
    this.companyId = '',
    this.createdBy = '',
    String? createdAt,
    String? updatedAt,
    this.synced = false,
  }) : permissions = permissions ?? {},
       createdAt = createdAt ?? DateTime.now().toIso8601String(),
       updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  /// هل لهذا المستخدم بيانات دخول محلية (اسم مستخدم + كلمة مرور)؟
  bool get hasCredentials =>
      username.isNotEmpty && passwordHash.isNotEmpty && passwordSalt.isNotEmpty;

  /// الصلاحيات الفعّالة (المخصّصة أو الافتراضية حسب الدور)
  Set<String> get effectivePermissions =>
      useRoleDefaults ? Perm.defaultsForRole(role) : permissions;

  bool can(String permission) => effectivePermissions.contains(permission);

  bool canAny(List<String> permissions) => permissions.any((p) => can(p));

  bool get isOwner => role == UserRole.owner;

  String get initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1);
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'email': email,
    'username': username,
    'passwordHash': passwordHash,
    'passwordSalt': passwordSalt,
    'phone': phone,
    'role': role.name,
    'permissions': permissions.toList(),
    'useRoleDefaults': useRoleDefaults,
    'isActive': isActive,
    'branchId': branchId,
    'photoUrl': photoUrl,
    'fcmToken': fcmToken,
    'companyId': companyId,
    'createdBy': createdBy,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'synced': synced,
  };

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
    id: m['id'] as String,
    name: m['name'] as String? ?? '',
    email: m['email'] as String? ?? '',
    username: m['username'] as String? ?? '',
    passwordHash: m['passwordHash'] as String? ?? '',
    passwordSalt: m['passwordSalt'] as String? ?? '',
    phone: m['phone'] as String? ?? '',
    role: UserRoleX.fromKey(m['role'] as String?),
    permissions: ((m['permissions'] as List?) ?? const [])
        .map((e) => e.toString())
        .toSet(),
    useRoleDefaults: m['useRoleDefaults'] as bool? ?? true,
    isActive: m['isActive'] as bool? ?? true,
    branchId: m['branchId'] as String?,
    photoUrl: m['photoUrl'] as String?,
    fcmToken: m['fcmToken'] as String?,
    companyId: m['companyId'] as String? ?? '',
    createdBy: m['createdBy'] as String? ?? '',
    createdAt: m['createdAt'] as String?,
    updatedAt: m['updatedAt'] as String?,
    synced: m['synced'] as bool? ?? false,
  );

  AppUser copyWith({
    String? name,
    String? email,
    String? username,
    String? passwordHash,
    String? passwordSalt,
    String? phone,
    UserRole? role,
    Set<String>? permissions,
    bool? useRoleDefaults,
    bool? isActive,
    String? branchId,
    String? photoUrl,
    String? fcmToken,
    String? companyId,
    String? createdBy,
    bool? synced,
  }) => AppUser(
    id: id,
    name: name ?? this.name,
    email: email ?? this.email,
    username: username ?? this.username,
    passwordHash: passwordHash ?? this.passwordHash,
    passwordSalt: passwordSalt ?? this.passwordSalt,
    phone: phone ?? this.phone,
    role: role ?? this.role,
    permissions: permissions ?? this.permissions,
    useRoleDefaults: useRoleDefaults ?? this.useRoleDefaults,
    isActive: isActive ?? this.isActive,
    branchId: branchId ?? this.branchId,
    photoUrl: photoUrl ?? this.photoUrl,
    fcmToken: fcmToken ?? this.fcmToken,
    companyId: companyId ?? this.companyId,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt,
    updatedAt: DateTime.now().toIso8601String(),
    synced: synced ?? this.synced,
  );
}

/// سجل نشاط المستخدمين (Audit للأحداث الحساسة)
class UserActivity {
  final String id;
  final String userId;
  final String userName;
  final String action; // login / logout / create_invoice / delete_...
  final String details;
  final String createdAt;

  UserActivity({
    required this.id,
    required this.userId,
    required this.userName,
    required this.action,
    this.details = '',
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'userName': userName,
    'action': action,
    'details': details,
    'createdAt': createdAt,
  };

  factory UserActivity.fromMap(Map<String, dynamic> m) => UserActivity(
    id: m['id'] as String,
    userId: m['userId'] as String? ?? '',
    userName: m['userName'] as String? ?? '',
    action: m['action'] as String? ?? '',
    details: m['details'] as String? ?? '',
    createdAt: m['createdAt'] as String?,
  );
}
