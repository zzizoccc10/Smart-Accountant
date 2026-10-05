// ============================================================================
// نماذج لوحة التحكم المركزية — المحاسب السهل
// ----------------------------------------------------------------------------
// تحتوي على:
//   • SystemOwner   : مالك النظام (المشرف الأعلى الذي يدير كل المنشآت).
//   • CompanyAccount: حساب منشأة (مستأجر) — يُنشئه صاحب المنشأة عند التسجيل.
//   • DeviceRegistry: سجل الأجهزة/التنزيلات التي حمّلت التطبيق.
//   • AuthMode      : أوضاع الدخول المتاحة من الواجهة الرئيسية.
// ============================================================================

/// أوضاع/أدوار الدخول من الواجهة الرئيسية
enum AuthMode {
  /// الدخول كمسؤول/مستخدم منشأة محددة (الزر المُفعّل افتراضياً)
  companyUser,

  /// الدخول كمالك النظام (المشرف الأعلى → لوحة التحكم)
  systemOwner,

  /// الدخول كزائر بدون حساب (وضع تجريبي/محلي)
  guest,
}

extension AuthModeX on AuthMode {
  String get labelAr {
    switch (this) {
      case AuthMode.companyUser:
        return 'دخول المنشأة / مستخدم';
      case AuthMode.systemOwner:
        return 'مالك النظام';
      case AuthMode.guest:
        return 'الدخول بدون حساب';
    }
  }
}

/// خطة/فئة الاشتراك للمنشأة
enum CompanyPlan {
  free, // مجاني
  basic, // أساسي
  pro, // احترافي
  enterprise, // مؤسسات
}

extension CompanyPlanX on CompanyPlan {
  String get key => name;

  String get labelAr {
    switch (this) {
      case CompanyPlan.free:
        return 'مجاني';
      case CompanyPlan.basic:
        return 'أساسي';
      case CompanyPlan.pro:
        return 'احترافي';
      case CompanyPlan.enterprise:
        return 'مؤسسات';
    }
  }

  static CompanyPlan fromKey(String? k) => CompanyPlan.values.firstWhere(
        (p) => p.name == k,
        orElse: () => CompanyPlan.free,
      );
}

/// صلاحيات/امتيازات ممنوحة للمنشأة من مالك النظام
class CompanyPrivileges {
  /// مفاتيح الامتيازات الممنوحة
  final Set<String> granted;
  /// حدّ أقصى لعدد المستخدمين المسموح بإنشائهم (0 = غير محدود)
  final int maxUsers;
  /// هل يُسمح بالتصدير/الطباعة
  final bool allowExport;
  /// هل يُسمح بالمزامنة السحابية
  final bool allowCloud;
  /// هل يُسمح بالدعم الفني المتقدم
  final bool allowSupport;

  const CompanyPrivileges({
    this.granted = const {},
    this.maxUsers = 0,
    this.allowExport = true,
    this.allowCloud = true,
    this.allowSupport = false,
  });

  /// كل الامتيازات المتاحة للتخصيص
  static const List<String> allKeys = [
    'sales',
    'purchases',
    'inventory',
    'accounts',
    'reports',
    'hr',
    'assets',
    'pos',
  ];

  static const Map<String, String> labelsAr = {
    'sales': 'المبيعات',
    'purchases': 'المشتريات',
    'inventory': 'المخزون',
    'accounts': 'المحاسبة والقيود',
    'reports': 'التقارير',
    'hr': 'الموارد البشرية',
    'assets': 'الأصول الثابتة',
    'pos': 'نقاط البيع',
  };

  bool has(String key) => granted.isEmpty || granted.contains(key);

  Map<String, dynamic> toMap() => {
        'granted': granted.toList(),
        'maxUsers': maxUsers,
        'allowExport': allowExport,
        'allowCloud': allowCloud,
        'allowSupport': allowSupport,
      };

  factory CompanyPrivileges.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const CompanyPrivileges();
    return CompanyPrivileges(
      granted: ((m['granted'] as List?) ?? const [])
          .map((e) => e.toString())
          .toSet(),
      maxUsers: (m['maxUsers'] as num?)?.toInt() ?? 0,
      allowExport: m['allowExport'] as bool? ?? true,
      allowCloud: m['allowCloud'] as bool? ?? true,
      allowSupport: m['allowSupport'] as bool? ?? false,
    );
  }

  CompanyPrivileges copyWith({
    Set<String>? granted,
    int? maxUsers,
    bool? allowExport,
    bool? allowCloud,
    bool? allowSupport,
  }) =>
      CompanyPrivileges(
        granted: granted ?? this.granted,
        maxUsers: maxUsers ?? this.maxUsers,
        allowExport: allowExport ?? this.allowExport,
        allowCloud: allowCloud ?? this.allowCloud,
        allowSupport: allowSupport ?? this.allowSupport,
      );
}

/// حساب منشأة (مستأجر) — العنصر الأساسي في لوحة تحكم مالك النظام
class CompanyAccount {
  final String id; // معرّف المنشأة (companyId)
  String companyName; // اسم المنشأة التجاري
  String ownerName; // اسم صاحب المنشأة
  String username; // اسم المستخدم للدخول الرئيسي
  String email; // البريد الإلكتروني
  String passwordHash; // تجزئة كلمة المرور (SHA-256 + salt)
  String passwordSalt; // الملح
  String phone;

  bool isActive; // هل المنشأة مفعّلة (يوقفها مالك النظام)
  CompanyPlan plan;
  CompanyPrivileges privileges;

  String createdAt;
  String updatedAt;
  String lastLoginAt;

  // بيانات التتبع
  String deviceId; // الجهاز الذي أنشأ الحساب
  String appVersion;
  String createdVia; // 'email' | 'google' | 'device'
  bool synced;

  CompanyAccount({
    required this.id,
    required this.companyName,
    this.ownerName = '',
    required this.username,
    this.email = '',
    this.passwordHash = '',
    this.passwordSalt = '',
    this.phone = '',
    this.isActive = true,
    this.plan = CompanyPlan.free,
    CompanyPrivileges? privileges,
    String? createdAt,
    String? updatedAt,
    this.lastLoginAt = '',
    this.deviceId = '',
    this.appVersion = '',
    this.createdVia = 'email',
    this.synced = false,
  })  : privileges = privileges ?? const CompanyPrivileges(),
        createdAt = createdAt ?? DateTime.now().toIso8601String(),
        updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  String get initials {
    final t = companyName.trim();
    if (t.isEmpty) return '?';
    return t.substring(0, 1).toUpperCase();
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'companyName': companyName,
        'ownerName': ownerName,
        'username': username,
        'email': email,
        'passwordHash': passwordHash,
        'passwordSalt': passwordSalt,
        'phone': phone,
        'isActive': isActive,
        'plan': plan.name,
        'privileges': privileges.toMap(),
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'lastLoginAt': lastLoginAt,
        'deviceId': deviceId,
        'appVersion': appVersion,
        'createdVia': createdVia,
        'synced': synced,
      };

  factory CompanyAccount.fromMap(Map<String, dynamic> m) => CompanyAccount(
        id: m['id'].toString(),
        companyName: m['companyName'] as String? ?? '',
        ownerName: m['ownerName'] as String? ?? '',
        username: m['username'] as String? ?? '',
        email: m['email'] as String? ?? '',
        passwordHash: m['passwordHash'] as String? ?? '',
        passwordSalt: m['passwordSalt'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        isActive: m['isActive'] as bool? ?? true,
        plan: CompanyPlanX.fromKey(m['plan'] as String?),
        privileges: CompanyPrivileges.fromMap(
          m['privileges'] is Map
              ? Map<String, dynamic>.from(m['privileges'] as Map)
              : null,
        ),
        createdAt: m['createdAt'] as String?,
        updatedAt: m['updatedAt'] as String?,
        lastLoginAt: m['lastLoginAt'] as String? ?? '',
        deviceId: m['deviceId'] as String? ?? '',
        appVersion: m['appVersion'] as String? ?? '',
        createdVia: m['createdVia'] as String? ?? 'email',
        synced: m['synced'] as bool? ?? false,
      );

  CompanyAccount copyWith({
    String? companyName,
    String? ownerName,
    String? username,
    String? email,
    String? passwordHash,
    String? passwordSalt,
    String? phone,
    bool? isActive,
    CompanyPlan? plan,
    CompanyPrivileges? privileges,
    String? updatedAt,
    String? lastLoginAt,
    String? deviceId,
    String? appVersion,
    String? createdVia,
    bool? synced,
  }) =>
      CompanyAccount(
        id: id,
        companyName: companyName ?? this.companyName,
        ownerName: ownerName ?? this.ownerName,
        username: username ?? this.username,
        email: email ?? this.email,
        passwordHash: passwordHash ?? this.passwordHash,
        passwordSalt: passwordSalt ?? this.passwordSalt,
        phone: phone ?? this.phone,
        isActive: isActive ?? this.isActive,
        plan: plan ?? this.plan,
        privileges: privileges ?? this.privileges,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now().toIso8601String(),
        lastLoginAt: lastLoginAt ?? this.lastLoginAt,
        deviceId: deviceId ?? this.deviceId,
        appVersion: appVersion ?? this.appVersion,
        createdVia: createdVia ?? this.createdVia,
        synced: synced ?? this.synced,
      );
}

/// مالك النظام (المشرف الأعلى) — حساب واحد فقط في التطبيق
class SystemOwner {
  String name;
  String username;
  String email;
  String passwordHash;
  String passwordSalt;
  bool mustChangePassword; // مطالبة بتغيير كلمة المرور الافتراضية
  String createdAt;
  String lastLoginAt;

  SystemOwner({
    this.name = 'مالك النظام',
    required this.username,
    this.email = '',
    required this.passwordHash,
    required this.passwordSalt,
    this.mustChangePassword = false,
    String? createdAt,
    this.lastLoginAt = '',
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
        'name': name,
        'username': username,
        'email': email,
        'passwordHash': passwordHash,
        'passwordSalt': passwordSalt,
        'mustChangePassword': mustChangePassword,
        'createdAt': createdAt,
        'lastLoginAt': lastLoginAt,
      };

  factory SystemOwner.fromMap(Map<String, dynamic> m) => SystemOwner(
        name: m['name'] as String? ?? 'مالك النظام',
        username: m['username'] as String? ?? 'admin',
        email: m['email'] as String? ?? '',
        passwordHash: m['passwordHash'] as String? ?? '',
        passwordSalt: m['passwordSalt'] as String? ?? '',
        mustChangePassword: m['mustChangePassword'] as bool? ?? false,
        createdAt: m['createdAt'] as String?,
        lastLoginAt: m['lastLoginAt'] as String? ?? '',
      );
}

/// سجل جهاز/تنزيل — لتتبّع من حمّل التطبيق ومن أنشأ حساباً
class DeviceRegistry {
  final String deviceId; // معرّف فريد للجهاز
  String platform; // android / ios / web
  String appVersion;
  String model; // طراز الجهاز (إن توفر)
  String brand; // الشركة المصنّعة (Samsung/Xiaomi...)
  String osVersion; // إصدار نظام التشغيل
  String country; // البلد (من إعدادات الجهاز / رمز الدولة)
  String countryCode; // رمز البلد ISO

  String firstSeenAt;
  String lastSeenAt;
  int launchCount;

  // ربط الجهاز بالمستخدم/المنشأة
  String companyId;
  String userId;
  String userName;
  bool accountCreated; // هل أنشأ حساباً من هذا الجهاز

  bool synced;

  DeviceRegistry({
    required this.deviceId,
    this.platform = '',
    this.appVersion = '',
    this.model = '',
    this.brand = '',
    this.osVersion = '',
    this.country = '',
    this.countryCode = '',
    String? firstSeenAt,
    String? lastSeenAt,
    this.launchCount = 1,
    this.companyId = '',
    this.userId = '',
    this.userName = '',
    this.accountCreated = false,
    this.synced = false,
  })  : firstSeenAt = firstSeenAt ?? DateTime.now().toIso8601String(),
        lastSeenAt = lastSeenAt ?? DateTime.now().toIso8601String();

  /// وصف مختصر للجهاز (الشركة + الطراز)
  String get deviceLabel {
    if (brand.isEmpty && model.isEmpty) return platform;
    if (brand.isEmpty) return model;
    if (model.isEmpty) return brand;
    return '$brand $model';
  }

  Map<String, dynamic> toMap() => {
        'deviceId': deviceId,
        'platform': platform,
        'appVersion': appVersion,
        'model': model,
        'brand': brand,
        'osVersion': osVersion,
        'country': country,
        'countryCode': countryCode,
        'firstSeenAt': firstSeenAt,
        'lastSeenAt': lastSeenAt,
        'launchCount': launchCount,
        'companyId': companyId,
        'userId': userId,
        'userName': userName,
        'accountCreated': accountCreated,
        'synced': synced,
      };

  factory DeviceRegistry.fromMap(Map<String, dynamic> m) => DeviceRegistry(
        deviceId: m['deviceId'].toString(),
        platform: m['platform'] as String? ?? '',
        appVersion: m['appVersion'] as String? ?? '',
        model: m['model'] as String? ?? '',
        brand: m['brand'] as String? ?? '',
        osVersion: m['osVersion'] as String? ?? '',
        country: m['country'] as String? ?? '',
        countryCode: m['countryCode'] as String? ?? '',
        firstSeenAt: m['firstSeenAt'] as String?,
        lastSeenAt: m['lastSeenAt'] as String?,
        launchCount: (m['launchCount'] as num?)?.toInt() ?? 1,
        companyId: m['companyId'] as String? ?? '',
        userId: m['userId'] as String? ?? '',
        userName: m['userName'] as String? ?? '',
        accountCreated: m['accountCreated'] as bool? ?? false,
        synced: m['synced'] as bool? ?? false,
      );

  DeviceRegistry copyWith({
    String? platform,
    String? appVersion,
    String? model,
    String? brand,
    String? osVersion,
    String? country,
    String? countryCode,
    String? lastSeenAt,
    int? launchCount,
    String? companyId,
    String? userId,
    String? userName,
    bool? accountCreated,
    bool? synced,
  }) =>
      DeviceRegistry(
        deviceId: deviceId,
        platform: platform ?? this.platform,
        appVersion: appVersion ?? this.appVersion,
        model: model ?? this.model,
        brand: brand ?? this.brand,
        osVersion: osVersion ?? this.osVersion,
        country: country ?? this.country,
        countryCode: countryCode ?? this.countryCode,
        firstSeenAt: firstSeenAt,
        lastSeenAt: lastSeenAt ?? DateTime.now().toIso8601String(),
        launchCount: launchCount ?? this.launchCount,
        companyId: companyId ?? this.companyId,
        userId: userId ?? this.userId,
        userName: userName ?? this.userName,
        accountCreated: accountCreated ?? this.accountCreated,
        synced: synced ?? this.synced,
      );
}

/// سجل عملية (نشاط) — يُستخدم لعدّادات العمليات لكل منشأة/مستخدم
class OperationLog {
  final String id;
  final String companyId; // المنشأة التابع لها
  final String userId; // المستخدم الذي قام بالعملية
  final String userName;
  final String action; // نوع العملية (invoice_create/login/...)
  final String details;
  final String createdAt;

  OperationLog({
    required this.id,
    this.companyId = '',
    this.userId = '',
    this.userName = '',
    required this.action,
    this.details = '',
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  /// الوصف العربي للعملية
  String get actionLabelAr {
    const map = {
      'login': 'تسجيل دخول',
      'logout': 'تسجيل خروج',
      'register_company': 'إنشاء منشأة',
      'invoice_create': 'إنشاء فاتورة',
      'invoice_delete': 'حذف فاتورة',
      'payment_create': 'سند دفع/قبض',
      'journal_create': 'قيد يومية',
      'expense_create': 'مصروف',
      'item_create': 'إضافة صنف',
      'contact_create': 'إضافة جهة',
      'user_create': 'إضافة مستخدم',
      'update_user': 'تعديل مستخدم',
      'password_reset_request': 'طلب استعادة كلمة مرور',
      'sync': 'مزامنة',
      'backup': 'نسخة احتياطية',
      'guest_login': 'دخول زائر',
      'google_login': 'دخول Google',
    };
    return map[action] ?? action;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'companyId': companyId,
        'userId': userId,
        'userName': userName,
        'action': action,
        'details': details,
        'createdAt': createdAt,
      };

  factory OperationLog.fromMap(Map<String, dynamic> m) => OperationLog(
        id: m['id'].toString(),
        companyId: m['companyId'] as String? ?? '',
        userId: m['userId'] as String? ?? '',
        userName: m['userName'] as String? ?? '',
        action: m['action'] as String? ?? '',
        details: m['details'] as String? ?? '',
        createdAt: m['createdAt'] as String?,
      );
}

/// حساب زائر (دخول بدون حساب) — يُسجَّل في قائمة منفصلة لدى مالك النظام
class GuestAccount {
  final String id;
  String deviceId;
  String platform;
  String model;
  String country;
  String countryCode;
  String firstSeenAt;
  String lastSeenAt;
  int visits;
  bool converted; // هل أنشأ حساباً لاحقاً
  String convertedToCompanyId;
  bool synced;

  GuestAccount({
    required this.id,
    this.deviceId = '',
    this.platform = '',
    this.model = '',
    this.country = '',
    this.countryCode = '',
    String? firstSeenAt,
    String? lastSeenAt,
    this.visits = 1,
    this.converted = false,
    this.convertedToCompanyId = '',
    this.synced = false,
  })  : firstSeenAt = firstSeenAt ?? DateTime.now().toIso8601String(),
        lastSeenAt = lastSeenAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
        'id': id,
        'deviceId': deviceId,
        'platform': platform,
        'model': model,
        'country': country,
        'countryCode': countryCode,
        'firstSeenAt': firstSeenAt,
        'lastSeenAt': lastSeenAt,
        'visits': visits,
        'converted': converted,
        'convertedToCompanyId': convertedToCompanyId,
        'synced': synced,
      };

  factory GuestAccount.fromMap(Map<String, dynamic> m) => GuestAccount(
        id: m['id'].toString(),
        deviceId: m['deviceId'] as String? ?? '',
        platform: m['platform'] as String? ?? '',
        model: m['model'] as String? ?? '',
        country: m['country'] as String? ?? '',
        countryCode: m['countryCode'] as String? ?? '',
        firstSeenAt: m['firstSeenAt'] as String?,
        lastSeenAt: m['lastSeenAt'] as String?,
        visits: (m['visits'] as num?)?.toInt() ?? 1,
        converted: m['converted'] as bool? ?? false,
        convertedToCompanyId: m['convertedToCompanyId'] as String? ?? '',
        synced: m['synced'] as bool? ?? false,
      );

  GuestAccount copyWith({
    String? platform,
    String? model,
    String? country,
    String? countryCode,
    String? lastSeenAt,
    int? visits,
    bool? converted,
    String? convertedToCompanyId,
    bool? synced,
  }) =>
      GuestAccount(
        id: id,
        deviceId: deviceId,
        platform: platform ?? this.platform,
        model: model ?? this.model,
        country: country ?? this.country,
        countryCode: countryCode ?? this.countryCode,
        firstSeenAt: firstSeenAt,
        lastSeenAt: lastSeenAt ?? DateTime.now().toIso8601String(),
        visits: visits ?? this.visits,
        converted: converted ?? this.converted,
        convertedToCompanyId: convertedToCompanyId ?? this.convertedToCompanyId,
        synced: synced ?? this.synced,
      );
}

/// حساب دخول عبر Google — يُسجَّل في قائمة منفصلة لدى مالك النظام
class GoogleAccount {
  final String id; // uid من Firebase أو معرّف البريد
  String email;
  String displayName;
  String photoUrl;
  String deviceId;
  String platform;
  String model;
  String country;
  String countryCode;
  String firstSeenAt;
  String lastSeenAt;
  int loginCount;
  String companyId; // المنشأة المرتبطة (إن وُجدت)
  bool synced;

  GoogleAccount({
    required this.id,
    this.email = '',
    this.displayName = '',
    this.photoUrl = '',
    this.deviceId = '',
    this.platform = '',
    this.model = '',
    this.country = '',
    this.countryCode = '',
    String? firstSeenAt,
    String? lastSeenAt,
    this.loginCount = 1,
    this.companyId = '',
    this.synced = false,
  })  : firstSeenAt = firstSeenAt ?? DateTime.now().toIso8601String(),
        lastSeenAt = lastSeenAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'deviceId': deviceId,
        'platform': platform,
        'model': model,
        'country': country,
        'countryCode': countryCode,
        'firstSeenAt': firstSeenAt,
        'lastSeenAt': lastSeenAt,
        'loginCount': loginCount,
        'companyId': companyId,
        'synced': synced,
      };

  factory GoogleAccount.fromMap(Map<String, dynamic> m) => GoogleAccount(
        id: m['id'].toString(),
        email: m['email'] as String? ?? '',
        displayName: m['displayName'] as String? ?? '',
        photoUrl: m['photoUrl'] as String? ?? '',
        deviceId: m['deviceId'] as String? ?? '',
        platform: m['platform'] as String? ?? '',
        model: m['model'] as String? ?? '',
        country: m['country'] as String? ?? '',
        countryCode: m['countryCode'] as String? ?? '',
        firstSeenAt: m['firstSeenAt'] as String?,
        lastSeenAt: m['lastSeenAt'] as String?,
        loginCount: (m['loginCount'] as num?)?.toInt() ?? 1,
        companyId: m['companyId'] as String? ?? '',
        synced: m['synced'] as bool? ?? false,
      );

  GoogleAccount copyWith({
    String? displayName,
    String? photoUrl,
    String? deviceId,
    String? platform,
    String? model,
    String? country,
    String? countryCode,
    String? lastSeenAt,
    int? loginCount,
    String? companyId,
    bool? synced,
  }) =>
      GoogleAccount(
        id: id,
        email: email,
        displayName: displayName ?? this.displayName,
        photoUrl: photoUrl ?? this.photoUrl,
        deviceId: deviceId ?? this.deviceId,
        platform: platform ?? this.platform,
        model: model ?? this.model,
        country: country ?? this.country,
        countryCode: countryCode ?? this.countryCode,
        firstSeenAt: firstSeenAt,
        lastSeenAt: lastSeenAt ?? DateTime.now().toIso8601String(),
        loginCount: loginCount ?? this.loginCount,
        companyId: companyId ?? this.companyId,
        synced: synced ?? this.synced,
      );
}
