// ============================================================================
// خدمة الإحصاءات — StatsService
// ----------------------------------------------------------------------------
// تجمّع كل الأرقام التي تعرضها لوحة تحكم مالك النظام (الداشبورد الرئيسية):
//   • عدد المنشآت (نشطة/موقوفة) والمستخدمين والأجهزة والزوار وحسابات Google.
//   • عدّادات العمليات (إجمالي/اليوم/لكل منشأة/لكل مستخدم).
//   • ترتيب المنشآت والأعضاء الأكثر نشاطاً + سلاسل زمنية للرسم البياني.
// لا تخزّن شيئاً — كلها حسابات على القراءة من الخدمات الأخرى.
// ============================================================================
import '../models/control_models.dart';
import '../models/user_models.dart';
import 'control_service.dart';
import 'operation_service.dart';
import 'user_service.dart';

class StatsService {
  // ---------------------------- أرقام عامة ----------------------------
  static List<CompanyAccount> get companies => ControlService.allCompanies();

  static int get companiesCount => companies.length;

  static int get activeCompaniesCount =>
      companies.where((c) => c.isActive).length;

  static int get stoppedCompaniesCount => companiesCount - activeCompaniesCount;

  static List<AppUser> get users => UserService.all();

  static int get usersCount => users.length;

  static int get activeUsersCount => users.where((u) => u.isActive).length;

  static int get devicesCount => ControlService.allDevices().length;

  static int get accountsCreatedCount =>
      ControlService.allDevices().where((d) => d.accountCreated).length;

  static List<GuestAccount> get guests => ControlService.allGuests();

  static int get guestsCount => guests.length;

  static List<GoogleAccount> get googleAccounts =>
      ControlService.allGoogleAccounts();

  static int get googleCount => googleAccounts.length;

  // ---------------------------- العمليات ----------------------------
  static int get operationsCount => OperationService.all().length;

  static int get operationsToday => OperationService.todayCount();

  static int opsOfCompany(String companyId) =>
      OperationService.countOfCompany(companyId);

  static int opsOfCompanySince(String companyId, int days) =>
      OperationService.countOfCompanySince(companyId, days);

  static int opsOfUser(String userId) =>
      OperationService.countOfUser(userId);

  /// عدد مستخدمي منشأة (المستخدم الرئيسي + الفرعيين)
  static int usersOfCompany(String companyId) =>
      UserService.countOfCompany(companyId);

  /// عدد الأجهزة المرتبطة بمنشأة
  static int devicesOfCompany(String companyId) =>
      ControlService.allDevices().where((d) => d.companyId == companyId).length;

  /// عدد الزوار الذين تحوّلوا إلى حسابات
  static int get guestsConverted => guests.where((g) => g.converted).length;

  // ---------------------------- ترتيب/سلاسل ----------------------------

  /// أكثر المنشآت من ناحية العمليات (تنازلياً)
  static List<CompanyAccount> topCompaniesByOps({int limit = 5}) {
    final list = [...companies]
      ..sort((a, b) => opsOfCompany(b.id).compareTo(opsOfCompany(a.id)));
    return list.take(limit).toList();
  }

  /// أكثر المستخدمين نشاطاً في منشأة معيّنة
  static List<AppUser> topUsersOfCompany(String companyId, {int limit = 10}) {
    final list = UserService.ofCompany(companyId)
      ..sort((a, b) => opsOfUser(b.id).compareTo(opsOfUser(a.id)));
    return list.take(limit).toList();
  }

  /// سلسلة عدد العمليات لكل يوم خلال آخر [days] يوماً (الأقدم → الأحدث).
  static List<MapEntry<String, int>> opsByDay({int days = 7}) {
    final all = OperationService.all();
    final now = DateTime.now();
    final result = <MapEntry<String, int>>[];
    for (var i = days - 1; i >= 0; i--) {
      final d = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
      final count = all.where((o) => o.createdAt.startsWith(key)).length;
      result.add(MapEntry(key, count));
    }
    return result;
  }

  /// توزيع المنشآت حسب الخطة
  static Map<CompanyPlan, int> get companiesByPlan {
    final map = <CompanyPlan, int>{};
    for (final p in CompanyPlan.values) {
      map[p] = companies.where((c) => c.plan == p).length;
    }
    return map;
  }

  /// توزيع الأجهزة حسب النظام (android/ios/web)
  static Map<String, int> get devicesByPlatform {
    final map = <String, int>{};
    for (final d in ControlService.allDevices()) {
      final key = d.platform.isEmpty ? 'unknown' : d.platform;
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  /// أكثر الدول التي يُفتح منها التطبيق
  static List<MapEntry<String, int>> topCountries({int limit = 6}) {
    final map = <String, int>{};
    for (final d in ControlService.allDevices()) {
      final key = d.country.isEmpty ? 'غير معروف' : d.country;
      map[key] = (map[key] ?? 0) + 1;
    }
    for (final g in guests) {
      final key = g.country.isEmpty ? 'غير معروف' : g.country;
      map[key] = (map[key] ?? 0) + 1;
    }
    final list = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list.take(limit).toList();
  }

  /// أحدث العمليات
  static List<OperationLog> recentOperations({int limit = 20}) =>
      OperationService.all().take(limit).toList();
}
