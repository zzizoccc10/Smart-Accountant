// ============================================================================
// طبقة البيانات — AppDatabase
// تعمل على الويب والأندرويد (Hive: تخزين محلي Offline-First)
// ============================================================================
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'chart_of_accounts.dart';

class AppDatabase {
  static const _uuid = Uuid();

  static const boxAccounts = 'accounts';
  static const boxContacts = 'contacts';
  static const boxItems = 'items';
  static const boxCategories = 'categories';
  static const boxInvoices = 'invoices';
  static const boxPayments = 'payments';
  static const boxExpenses = 'expenses';
  static const boxExpenseCats = 'expense_categories';
  static const boxMovements = 'movements';
  static const boxBalances = 'inv_balances';
  static const boxCashboxes = 'cashboxes';
  static const boxWarehouses = 'warehouses';
  static const boxJournals = 'journals';
  static const boxSettings = 'settings';
  static const boxSequences = 'sequences';
  static const boxEmployees = 'employees';
  static const boxAttendance = 'attendance';
  static const boxPayroll = 'payroll';
  static const boxCurrencies = 'currencies';

  static late Box _bAccounts;
  static late Box _bContacts;
  static late Box _bItems;
  static late Box _bCategories;
  static late Box _bInvoices;
  static late Box _bPayments;
  static late Box _bExpenses;
  static late Box _bExpenseCats;
  static late Box _bMovements;
  static late Box _bBalances;
  static late Box _bCashboxes;
  static late Box _bWarehouses;
  static late Box _bJournals;
  static late Box _bSettings;
  static late Box _bSequences;
  static late Box _bEmployees;
  static late Box _bAttendance;
  static late Box _bPayroll;
  static late Box _bCurrencies;

  static String newId() => _uuid.v4();

  /// تهيئة قاعدة البيانات — تُستدعى من main()
  static Future<void> init() async {
    await Hive.initFlutter();

    _bAccounts = await Hive.openBox(boxAccounts);
    _bContacts = await Hive.openBox(boxContacts);
    _bItems = await Hive.openBox(boxItems);
    _bCategories = await Hive.openBox(boxCategories);
    _bInvoices = await Hive.openBox(boxInvoices);
    _bPayments = await Hive.openBox(boxPayments);
    _bExpenses = await Hive.openBox(boxExpenses);
    _bExpenseCats = await Hive.openBox(boxExpenseCats);
    _bMovements = await Hive.openBox(boxMovements);
    _bBalances = await Hive.openBox(boxBalances);
    _bCashboxes = await Hive.openBox(boxCashboxes);
    _bWarehouses = await Hive.openBox(boxWarehouses);
    _bJournals = await Hive.openBox(boxJournals);
    _bSettings = await Hive.openBox(boxSettings);
    _bSequences = await Hive.openBox(boxSequences);
    _bEmployees = await Hive.openBox(boxEmployees);
    _bAttendance = await Hive.openBox(boxAttendance);
    _bPayroll = await Hive.openBox(boxPayroll);
    _bCurrencies = await Hive.openBox(boxCurrencies);

    if (_bSettings.get('seeded') != true) {
      await _seed();
    }
  }

  // ---------------------------- الحسابات ----------------------------
  static List<Account> get accounts => _bAccounts.values
      .map((e) => Account.fromMap(Map<String, dynamic>.from(e)))
      .toList();

  static Future<void> saveAccount(Account acc) =>
      _bAccounts.put(acc.id, acc.toMap());
  static Future<void> deleteAccount(String id) => _bAccounts.delete(id);

  static Account? accountByCode(String code) {
    for (final v in _bAccounts.values) {
      final m = Map<String, dynamic>.from(v);
      if (m['code'] == code) return Account.fromMap(m);
    }
    return null;
  }

  static Account? accountById(String? id) {
    if (id == null) return null;
    final v = _bAccounts.get(id);
    return v == null ? null : Account.fromMap(Map<String, dynamic>.from(v));
  }

  static List<Account> get leafAccounts =>
      accounts.where((a) => a.isLeaf && a.isActive).toList();

  // ---------------------------- جهات الاتصال ----------------------------
  static List<Contact> get contacts => _bContacts.values
      .map((e) => Contact.fromMap(Map<String, dynamic>.from(e)))
      .toList();

  static Future<void> saveContact(Contact c) => _bContacts.put(c.id, c.toMap());
  static Future<void> deleteContact(String id) => _bContacts.delete(id);

  static Contact? contactById(String? id) {
    if (id == null) return null;
    final v = _bContacts.get(id);
    return v == null ? null : Contact.fromMap(Map<String, dynamic>.from(v));
  }

  // ---------------------------- الأصناف ----------------------------
  static List<Item> get items => _bItems.values
      .map((e) => Item.fromMap(Map<String, dynamic>.from(e)))
      .toList();

  static Future<void> saveItem(Item it) => _bItems.put(it.id, it.toMap());
  static Future<void> deleteItem(String id) => _bItems.delete(id);

  static Item? itemById(String? id) {
    if (id == null) return null;
    final v = _bItems.get(id);
    return v == null ? null : Item.fromMap(Map<String, dynamic>.from(v));
  }

  static List<ItemCategory> get categories => _bCategories.values
      .map((e) => ItemCategory.fromMap(Map<String, dynamic>.from(e)))
      .toList();

  static Future<void> saveCategory(ItemCategory c) =>
      _bCategories.put(c.id, c.toMap());
  static Future<void> deleteCategory(String id) => _bCategories.delete(id);

  // ---------------------------- الفواتير ----------------------------
  static List<Invoice> get invoices => _bInvoices.values
      .map((e) => Invoice.fromMap(Map<String, dynamic>.from(e)))
      .toList();

  static Future<void> saveInvoice(Invoice inv) =>
      _bInvoices.put(inv.id, inv.toMap());
  static Future<void> deleteInvoice(String id) => _bInvoices.delete(id);

  // ---------------------------- السندات ----------------------------
  static List<Payment> get payments => _bPayments.values
      .map((e) => Payment.fromMap(Map<String, dynamic>.from(e)))
      .toList();

  static Future<void> savePayment(Payment p) => _bPayments.put(p.id, p.toMap());
  static Future<void> deletePayment(String id) => _bPayments.delete(id);

  // ---------------------------- المصروفات ----------------------------
  static List<Expense> get expenses => _bExpenses.values
      .map((e) => Expense.fromMap(Map<String, dynamic>.from(e)))
      .toList();

  static Future<void> saveExpense(Expense e) => _bExpenses.put(e.id, e.toMap());
  static Future<void> deleteExpense(String id) => _bExpenses.delete(id);

  static List<ExpenseCategory> get expenseCategories => _bExpenseCats.values
      .map((e) => ExpenseCategory.fromMap(Map<String, dynamic>.from(e)))
      .toList();

  static Future<void> saveExpenseCategory(ExpenseCategory c) =>
      _bExpenseCats.put(c.id, c.toMap());
  static Future<void> deleteExpenseCategory(String id) =>
      _bExpenseCats.delete(id);

  // ---------------------------- حركات المخزون ----------------------------
  static List<InventoryMovement> get movements => _bMovements.values
      .map((e) => InventoryMovement.fromMap(Map<String, dynamic>.from(e)))
      .toList();

  static Future<void> saveMovement(InventoryMovement m) =>
      _bMovements.put(m.id, m.toMap());

  // ---------------------------- أرصدة المخزون ----------------------------
  static List<InventoryBalance> get balances => _bBalances.values
      .map((e) => InventoryBalance.fromMap(Map<String, dynamic>.from(e)))
      .toList();

  static InventoryBalance balanceOf(String itemId, String warehouseId) {
    final v = _bBalances.get('$itemId::$warehouseId');
    if (v == null) {
      return InventoryBalance(itemId: itemId, warehouseId: warehouseId);
    }
    return InventoryBalance.fromMap(Map<String, dynamic>.from(v));
  }

  static Future<void> saveBalance(InventoryBalance b) =>
      _bBalances.put(b.key, b.toMap());

  static double totalStockQty(String itemId) => balances
      .where((b) => b.itemId == itemId)
      .fold(0.0, (s, b) => s + b.quantity);

  // ---------------------------- الصناديق ----------------------------
  static List<Cashbox> get cashboxes => _bCashboxes.values
      .map((e) => Cashbox.fromMap(Map<String, dynamic>.from(e)))
      .toList();

  static Future<void> saveCashbox(Cashbox c) => _bCashboxes.put(c.id, c.toMap());
  static Future<void> deleteCashbox(String id) => _bCashboxes.delete(id);

  static Cashbox? cashboxById(String? id) {
    if (id == null) return null;
    final v = _bCashboxes.get(id);
    return v == null ? null : Cashbox.fromMap(Map<String, dynamic>.from(v));
  }

  // ---------------------------- المخازن ----------------------------
  static List<Warehouse> get warehouses => _bWarehouses.values
      .map((e) => Warehouse.fromMap(Map<String, dynamic>.from(e)))
      .toList();

  static Future<void> saveWarehouse(Warehouse w) =>
      _bWarehouses.put(w.id, w.toMap());
  static Future<void> deleteWarehouse(String id) => _bWarehouses.delete(id);

  // ---------------------------- القيود ----------------------------
  static List<JournalEntry> get journals => _bJournals.values
      .map((e) => JournalEntry.fromMap(Map<String, dynamic>.from(e)))
      .toList();

  static Future<void> saveJournal(JournalEntry j) =>
      _bJournals.put(j.id, j.toMap());
  static Future<void> deleteJournal(String id) => _bJournals.delete(id);

  // ---------------------------- الموظفون ----------------------------
  static List<Employee> get employees => _bEmployees.values
      .map((e) => Employee.fromMap(Map<String, dynamic>.from(e)))
      .toList();

  static Future<void> saveEmployee(Employee e) =>
      _bEmployees.put(e.id, e.toMap());
  static Future<void> deleteEmployee(String id) => _bEmployees.delete(id);

  static Employee? employeeById(String? id) {
    if (id == null) return null;
    final v = _bEmployees.get(id);
    return v == null ? null : Employee.fromMap(Map<String, dynamic>.from(v));
  }

  // ---------------------------- الحضور ----------------------------
  static List<Attendance> get attendance => _bAttendance.values
      .map((e) => Attendance.fromMap(Map<String, dynamic>.from(e)))
      .toList();

  static Future<void> saveAttendance(Attendance a) =>
      _bAttendance.put(a.id, a.toMap());

  static List<Attendance> attendanceOf(String employeeId, String period) =>
      attendance
          .where((a) =>
              a.employeeId == employeeId && a.date.startsWith(period))
          .toList();

  // ---------------------------- الرواتب ----------------------------
  static List<PayrollRecord> get payrolls => _bPayroll.values
      .map((e) => PayrollRecord.fromMap(Map<String, dynamic>.from(e)))
      .toList();

  static Future<void> savePayroll(PayrollRecord p) =>
      _bPayroll.put(p.id, p.toMap());
  static Future<void> deletePayroll(String id) => _bPayroll.delete(id);

  static bool payrollExists(String employeeId, String period) => payrolls
      .any((p) => p.employeeId == employeeId && p.period == period);

  // ---------------------------- العملات ----------------------------
  static List<Currency> get currencies => _bCurrencies.values
      .map((e) => Currency.fromMap(Map<String, dynamic>.from(e)))
      .toList();

  static Future<void> saveCurrency(Currency c) =>
      _bCurrencies.put(c.id, c.toMap());
  static Future<void> deleteCurrency(String id) => _bCurrencies.delete(id);

  // ---------------------------- الإعدادات ----------------------------
  static String getSetting(String key, [String def = '']) =>
      _bSettings.get(key, defaultValue: def).toString();

  static Future<void> setSetting(String key, String value) =>
      _bSettings.put(key, value);

  static bool getSettingBool(String key, [bool def = false]) {
    final v = _bSettings.get(key);
    if (v == null) return def;
    return v == true || v.toString() == 'true' || v.toString() == '1';
  }

  // ---------------------------- الترقيم التسلسلي ----------------------------
  static Future<String> nextNumber(String name, {String prefix = ''}) async {
    final current = (_bSequences.get(name, defaultValue: 1000) as int) + 1;
    await _bSequences.put(name, current);
    final year = DateTime.now().year;
    return '$prefix$current/$year';
  }

  // ---------------------------- حذف كل البيانات ----------------------------
  static Future<void> clearAll() async {
    for (final b in [
      _bAccounts,
      _bContacts,
      _bItems,
      _bCategories,
      _bInvoices,
      _bPayments,
      _bExpenses,
      _bExpenseCats,
      _bMovements,
      _bBalances,
      _bCashboxes,
      _bWarehouses,
      _bJournals,
      _bSequences,
      _bEmployees,
      _bAttendance,
      _bPayroll,
      _bCurrencies,
    ]) {
      await b.clear();
    }
    await _bSettings.delete('seeded');
    await _seed();
  }

  // ============================ البيانات الأولية ============================
  static Future<void> _seed() async {
    // 1. دليل الحسابات
    final coa = CoA.build();
    for (final acc in coa) {
      await _bAccounts.put(acc.id, acc.toMap());
    }

    // 2. المخازن
    await _bWarehouses.put('wh_main', Warehouse(
      id: 'wh_main', name: 'المخزن الرئيسي', code: 'WH-01', location: 'الفرع الرئيسي',
    ).toMap());
    await _bWarehouses.put('wh_branch1', Warehouse(
      id: 'wh_branch1', name: 'مخزن فرع 1', code: 'WH-02', location: 'فرع 1',
    ).toMap());

    // 3. الصناديق
    final cashAcc = accountByCode(CoA.cash);
    await _bCashboxes.put('cb_main', Cashbox(
      id: 'cb_main',
      name: 'الصندوق الرئيسي',
      code: 'CSH-01',
      accountId: cashAcc?.id ?? '',
      accountName: cashAcc?.name ?? 'الصندوق الرئيسي',
      openingBalance: 0,
      currentBalance: 0,
    ).toMap());

    // 4. تصنيفات الأصناف
    await _bCategories.put('cat_1', ItemCategory(id: 'cat_1', name: 'ملابس').toMap());
    await _bCategories.put('cat_2', ItemCategory(id: 'cat_2', name: 'أحذية').toMap());
    await _bCategories.put('cat_3', ItemCategory(id: 'cat_3', name: 'إلكترونيات').toMap());
    await _bCategories.put('cat_4', ItemCategory(id: 'cat_4', name: 'مواد غذائية').toMap());

    // 5. تصنيفات المصروفات (مرتبطة بحسابات المصروفات)
    final expCats = [
      ['الرواتب والأجور', CoA.salariesExpense],
      ['الإيجار', CoA.rentExpense],
      ['الكهرباء والماء', CoA.utilitiesExpense],
      ['الاتصالات', CoA.telecomExpense],
      ['القرطاسية', CoA.stationeryExpense],
      ['صيانة', CoA.maintenanceExpense],
      ['إعلانات', CoA.adsExpense],
      ['مصروفات بنكية', CoA.bankFeesExpense],
    ];
    for (var i = 0; i < expCats.length; i++) {
      final acc = accountByCode(expCats[i][1]);
      await _bExpenseCats.put('expcat_$i', ExpenseCategory(
        id: 'expcat_$i',
        name: expCats[i][0],
        accountId: acc?.id ?? '',
        accountName: acc?.name ?? expCats[i][0],
      ).toMap());
    }

    // 6. إعدادات افتراضية
    await _bSettings.put('companyName', 'شركتي');
    await _bSettings.put('companyPhone', '');
    await _bSettings.put('companyAddress', '');
    await _bSettings.put('currency', 'ر.س');
    await _bSettings.put('taxRate', '15');
    await _bSettings.put('invoiceFooter', 'شكراً لتعاملكم معنا');
    await _bSettings.put('allowNegativeStock', 'false');
    await _bSettings.put('isInit', 'false');
    await _bSettings.put('pinEnabled', 'false');
    await _bSettings.put('pin', '');
    await _bSettings.put('fiscalYearClosed', '');

    // 7. العملات الافتراضية
    await _bCurrencies.put('cur_base', Currency(
      id: 'cur_base', code: 'SAR', name: 'ريال سعودي', symbol: 'ر.س',
      rate: 1.0, isBase: true,
    ).toMap());
    await _bCurrencies.put('cur_usd', Currency(
      id: 'cur_usd', code: 'USD', name: 'دولار أمريكي', symbol: '\$',
      rate: 3.75, isBase: false,
    ).toMap());
    await _bCurrencies.put('cur_egp', Currency(
      id: 'cur_egp', code: 'EGP', name: 'جنيه مصري', symbol: 'ج.م',
      rate: 0.077, isBase: false,
    ).toMap());

    await _bSettings.put('seeded', true);
  }
}
