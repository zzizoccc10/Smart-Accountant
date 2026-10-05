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

  Map<String, dynamic> toMap() => {
        'deviceId': deviceId,
        'platform': platform,
        'appVersion': appVersion,
        'model': model,
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
