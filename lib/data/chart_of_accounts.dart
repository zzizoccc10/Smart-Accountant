// ============================================================================
// دليل الحسابات الافتراضي — من المواصفة الفنية (الجزء الثالث)
// ============================================================================
import '../models/models.dart';

class CoA {
  // أكواد ثابتة تُستخدم في القيود الآلية
  static const cash = '1-1-01-001';
  static const bank = '1-1-01-003';
  static const arCustomers = '1-1-02-001'; // العملاء (ذمم مدينة)
  static const inventory = '1-1-03-001'; // المخزون
  static const vatReceivable = '1-1-04'; // ضريبة مستحقة (مدين)
  static const apSuppliers = '2-1-01-001'; // الموردون (ذمم دائنة)
  static const vatPayable = '2-1-03'; // ضرائب مستحقة (دائن)
  static const capital = '3-1'; // رأس المال
  static const retainedEarnings = '3-2'; // الأرباح المحتجزة
  static const drawings = '3-3'; // المسحوبات الشخصية
  static const salesRevenue = '4-1'; // إيرادات المبيعات
  static const serviceRevenue = '4-2'; // إيرادات الخدمات
  static const salesReturns = '4-3'; // مردودات ومسموحات المبيعات
  static const salesDiscount = '4-4'; // خصم مسموح به
  static const cogs = '5-1'; // تكلفة المبيعات
  static const salariesExpense = '5-2-01'; // الرواتب والأجور
  static const rentExpense = '5-2-02'; // الإيجار
  static const utilitiesExpense = '5-2-03'; // الكهرباء والماء
  static const telecomExpense = '5-2-04'; // الاتصالات
  static const stationeryExpense = '5-2-05'; // القرطاسية
  static const maintenanceExpense = '5-2-06'; // صيانة
  static const adsExpense = '5-2-07'; // إعلانات
  static const depreciationExpense = '5-2-08'; // استهلاك
  static const bankFeesExpense = '5-2-09'; // مصروفات بنكية
  static const inventoryGain = '4-5'; // إيرادات جرد (تستخدم كإيراد آخر)
  static const inventoryLoss = '5-5'; // مصروفات أخرى (خسائر جرد)
  static const fxLoss = '5-4'; // خسائر فروق العملة

  /// بناء الشجرة الكاملة
  static List<Account> build() {
    final List<Account> a = [];
    int counter = 0;
    // حفظ معرفات الأب حسب الكود
    final Map<String, String> idByCode = {};
    void addAndTrack(
      String code,
      String name,
      String type,
      String nature,
      String? parentCode, {
      int level = 1,
      bool leaf = false,
      bool cash = false,
      bool system = false,
    }) {
      final id = 'acc_${(++counter).toString().padLeft(3, '0')}';
      a.add(
        Account(
          id: id,
          code: code,
          name: name,
          accountType: type,
          accountNature: nature,
          parentId: parentCode != null ? idByCode[parentCode] : null,
          level: level,
          isLeaf: leaf,
          isCash: cash,
          isSystem: system,
        ),
      );
      idByCode[code] = id;
    }

    // ===================== 1. الأصول =====================
    addAndTrack('1', 'الأصول', 'asset', 'debit', null, level: 1);
    addAndTrack('1-1', 'الأصول المتداولة', 'asset', 'debit', '1', level: 2);
    addAndTrack('1-1-01', 'النقدية', 'asset', 'debit', '1-1', level: 3);
    addAndTrack('1-1-01-001', 'الصندوق الرئيسي', 'asset', 'debit', '1-1-01', level: 4, leaf: true, cash: true, system: true);
    addAndTrack('1-1-01-002', 'الصندوق الفرعي - فرع 1', 'asset', 'debit', '1-1-01', level: 4, leaf: true, cash: true);
    addAndTrack('1-1-01-003', 'البنك', 'asset', 'debit', '1-1-01', level: 4, leaf: true, cash: true);
    addAndTrack('1-1-02', 'الذمم المدينة', 'asset', 'debit', '1-1', level: 3);
    addAndTrack('1-1-02-001', 'العملاء', 'asset', 'debit', '1-1-02', level: 4, leaf: true, system: true);
    addAndTrack('1-1-02-002', 'أوراق القبض', 'asset', 'debit', '1-1-02', level: 4, leaf: true);
    addAndTrack('1-1-02-003', 'مصروفات مدفوعة مقدماً', 'asset', 'debit', '1-1-02', level: 4, leaf: true);
    addAndTrack('1-1-03', 'المخزون', 'asset', 'debit', '1-1', level: 3);
    addAndTrack('1-1-03-001', 'مخزون - المخزن الرئيسي', 'asset', 'debit', '1-1-03', level: 4, leaf: true, system: true);
    addAndTrack('1-1-03-002', 'مخزون - فرع 1', 'asset', 'debit', '1-1-03', level: 4, leaf: true);
    addAndTrack('1-1-04', 'الضرائب المستحقة (مدين)', 'asset', 'debit', '1-1', level: 3, leaf: true, system: true);
    addAndTrack('1-2', 'الأصول الثابتة', 'asset', 'debit', '1', level: 2);
    addAndTrack('1-2-01', 'الأراضي', 'asset', 'debit', '1-2', level: 3, leaf: true);
    addAndTrack('1-2-02', 'المباني', 'asset', 'debit', '1-2', level: 3, leaf: true);
    addAndTrack('1-2-03', 'السيارات', 'asset', 'debit', '1-2', level: 3, leaf: true);
    addAndTrack('1-2-04', 'الأثاث', 'asset', 'debit', '1-2', level: 3, leaf: true);
    addAndTrack('1-2-05', 'أجهزة الكمبيوتر', 'asset', 'debit', '1-2', level: 3, leaf: true);
    addAndTrack('1-2-99', 'مجمع الاستهلاك', 'asset', 'credit', '1-2', level: 3, leaf: true);

    // ===================== 2. الخصوم =====================
    addAndTrack('2', 'الخصوم', 'liability', 'credit', null, level: 1);
    addAndTrack('2-1', 'الخصوم المتداولة', 'liability', 'credit', '2', level: 2);
    addAndTrack('2-1-01', 'الذمم الدائنة', 'liability', 'credit', '2-1', level: 3);
    addAndTrack('2-1-01-001', 'الموردون', 'liability', 'credit', '2-1-01', level: 4, leaf: true, system: true);
    addAndTrack('2-1-01-002', 'أوراق الدفع', 'liability', 'credit', '2-1-01', level: 4, leaf: true);
    addAndTrack('2-1-02', 'مصروفات مستحقة', 'liability', 'credit', '2-1', level: 3, leaf: true);
    addAndTrack('2-1-03', 'الضرائب المستحقة (دائن)', 'liability', 'credit', '2-1', level: 3, leaf: true, system: true);
    addAndTrack('2-1-04', 'قروض قصيرة الأجل', 'liability', 'credit', '2-1', level: 3, leaf: true);
    addAndTrack('2-2', 'الخصوم طويلة الأجل', 'liability', 'credit', '2', level: 2);
    addAndTrack('2-2-01', 'قروض طويلة الأجل', 'liability', 'credit', '2-2', level: 3, leaf: true);

    // ===================== 3. حقوق الملكية =====================
    addAndTrack('3', 'حقوق الملكية', 'equity', 'credit', null, level: 1);
    addAndTrack('3-1', 'رأس المال', 'equity', 'credit', '3', level: 2, leaf: true, system: true);
    addAndTrack('3-2', 'الأرباح المحتجزة', 'equity', 'credit', '3', level: 2, leaf: true, system: true);
    addAndTrack('3-3', 'المسحوبات الشخصية', 'equity', 'debit', '3', level: 2, leaf: true);
    addAndTrack('3-4', 'جاري الشركاء', 'equity', 'credit', '3', level: 2, leaf: true);

    // ===================== 4. الإيرادات =====================
    addAndTrack('4', 'الإيرادات', 'revenue', 'credit', null, level: 1);
    addAndTrack('4-1', 'إيرادات المبيعات', 'revenue', 'credit', '4', level: 2, leaf: true, system: true);
    addAndTrack('4-2', 'إيرادات الخدمات', 'revenue', 'credit', '4', level: 2, leaf: true);
    addAndTrack('4-3', 'مردودات ومسموحات المبيعات', 'revenue', 'debit', '4', level: 2, leaf: true, system: true);
    addAndTrack('4-4', 'خصم مسموح به', 'revenue', 'debit', '4', level: 2, leaf: true);
    addAndTrack('4-5', 'إيرادات أخرى', 'revenue', 'credit', '4', level: 2, leaf: true, system: true);

    // ===================== 5. المصروفات =====================
    addAndTrack('5', 'المصروفات', 'expense', 'debit', null, level: 1);
    addAndTrack('5-1', 'تكلفة المبيعات (COGS)', 'expense', 'debit', '5', level: 2, leaf: true, system: true);
    addAndTrack('5-2', 'المصروفات العمومية والإدارية', 'expense', 'debit', '5', level: 2);
    addAndTrack('5-2-01', 'الرواتب والأجور', 'expense', 'debit', '5-2', level: 3, leaf: true, system: true);
    addAndTrack('5-2-02', 'الإيجار', 'expense', 'debit', '5-2', level: 3, leaf: true);
    addAndTrack('5-2-03', 'الكهرباء والماء', 'expense', 'debit', '5-2', level: 3, leaf: true);
    addAndTrack('5-2-04', 'الاتصالات', 'expense', 'debit', '5-2', level: 3, leaf: true);
    addAndTrack('5-2-05', 'القرطاسية', 'expense', 'debit', '5-2', level: 3, leaf: true);
    addAndTrack('5-2-06', 'صيانة', 'expense', 'debit', '5-2', level: 3, leaf: true);
    addAndTrack('5-2-07', 'إعلانات', 'expense', 'debit', '5-2', level: 3, leaf: true);
    addAndTrack('5-2-08', 'استهلاك', 'expense', 'debit', '5-2', level: 3, leaf: true);
    addAndTrack('5-2-09', 'مصروفات بنكية', 'expense', 'debit', '5-2', level: 3, leaf: true);
    addAndTrack('5-3', 'مصروفات البيع والتوزيع', 'expense', 'debit', '5', level: 2, leaf: true);
    addAndTrack('5-4', 'خسائر فروق العملة', 'expense', 'debit', '5', level: 2, leaf: true);
    addAndTrack('5-5', 'مصروفات أخرى', 'expense', 'debit', '5', level: 2, leaf: true, system: true);

    return a;
  }
}
