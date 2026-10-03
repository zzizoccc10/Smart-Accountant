// ============================================================================
// خدمة مزامنة دليل الحسابات — AccountSyncService
// تربط الكيانات التشغيلية (عملاء/موردين/صناديق/مخازن/موظفين) بحساباتها في الدليل
// وتُنشئ/تُحدّث الحسابات تلقائياً، مع اشتقاق الأكواد من التسلسل الهرمي.
// ============================================================================
import '../data/app_database.dart';
import '../data/chart_of_accounts.dart';
import '../models/models.dart';

class AccountSyncService {
  /// توليد كود فرعي جديد تحت حساب أب معطى
  /// مثال: الأب "1-1-02-001" => أول ابن "1-1-02-001-001"
  static String nextChildCode(String parentCode, List<Account> all) {
    final prefix = '$parentCode-';
    int maxN = 0;
    for (final a in all) {
      if (a.code.startsWith(prefix)) {
        final rest = a.code.substring(prefix.length);
        // آخر مقطع رقمي فقط (قد يوجد تعمق أكثر)
        final last = rest.split('-').first;
        final n = int.tryParse(last) ?? 0;
        if (n > maxN) maxN = n;
      }
    }
    return '$parentCode-${(maxN + 1).toString().padLeft(3, '0')}';
  }

  /// هل يملك الحساب أبناءً؟
  static bool hasChildren(String accountId, List<Account> all) =>
      all.any((a) => a.parentId == accountId);

  /// حساب الأب المستهدف حسب نوع الكيان
  static Account? parentFor(String kind) {
    final code = switch (kind) {
      'customer' => CoA.arCustomers, // العملاء
      'supplier' => CoA.apSuppliers, // الموردون
      'cashbox' => CoA.cash, // الصندوق
      'warehouse' => CoA.inventory, // المخزون
      _ => null,
    };
    if (code == null) return null;
    return AppDatabase.accountByCode(code);
  }

  /// إنشاء حساب فرعي تحت أب معطى مع ضبط التسلسل الهرمي
  static Future<Account> _createChild({
    required Account parent,
    required String name,
    String nameEn = '',
    double openingBalance = 0,
  }) async {
    final all = AppDatabase.accounts;
    final code = nextChildCode(parent.code, all);
    final child = Account(
      id: AppDatabase.newId(),
      code: code,
      name: name,
      nameEn: nameEn,
      accountType: parent.accountType,
      accountNature: parent.accountNature,
      parentId: parent.id,
      level: parent.level + 1,
      isLeaf: true,
      isCash: parent.isCash,
      isSystem: false,
      openingBalance: openingBalance,
    );
    // الأب يصبح حساباً رئيسياً (لا يقبل القيود مباشرة)
    if (parent.isLeaf || !parent.isSystem) {
      parent.isLeaf = false;
      await AppDatabase.saveAccount(parent);
    }
    await AppDatabase.saveAccount(child);
    return child;
  }

  // ======================= جهات الاتصال (عملاء/موردون) =======================
  /// يضمن وجود حساب لجهة الاتصال، ويُرجع accountId
  static Future<String> ensureContactAccount(Contact c) async {
    final kind = c.contactType == 'supplier' ? 'supplier' : 'customer';
    final parent = parentFor(kind);
    if (parent == null) return c.accountId ?? '';

    // إن كان مرتبطاً بحساب موجود، حدّثه
    if (c.accountId != null && c.accountId!.isNotEmpty) {
      final existing = AppDatabase.accountById(c.accountId);
      if (existing != null) {
        existing.name = c.name;
        existing.openingBalance = c.openingBalance;
        existing.accountType = parent.accountType;
        existing.accountNature = parent.accountNature;
        await AppDatabase.saveAccount(existing);
        return existing.id;
      }
    }

    // ابحث عن حساب بنفس الاسم تحت نفس الأب (منع التكرار)
    final all = AppDatabase.accounts;
    for (final a in all) {
      if (a.parentId == parent.id && a.name == c.name) {
        a.openingBalance = c.openingBalance;
        await AppDatabase.saveAccount(a);
        return a.id;
      }
    }

    final child = await _createChild(
      parent: parent,
      name: c.name,
      openingBalance: c.openingBalance,
    );
    return child.id;
  }

  /// عند حذف جهة اتصال: إخفاء/حذف حسابها إن لم يكن عليه حركات
  static Future<void> removeContactAccount(String? accountId) async {
    if (accountId == null || accountId.isEmpty) return;
    final acc = AppDatabase.accountById(accountId);
    if (acc == null || acc.isSystem) return;
    // لا تحذف إن كانت هناك قيود عليه
    final used = AppDatabase.journals.any(
      (j) => j.lines.any((l) => l.accountId == accountId),
    );
    if (used) {
      acc.isActive = false;
      await AppDatabase.saveAccount(acc);
    } else {
      await AppDatabase.deleteAccount(accountId);
    }
  }

  // ======================= الصناديق =======================
  static Future<Cashbox> ensureCashboxAccount(Cashbox cb) async {
    final parent = parentFor('cashbox');
    if (parent == null) return cb;
    if (cb.accountId.isNotEmpty) {
      final existing = AppDatabase.accountById(cb.accountId);
      if (existing != null) {
        existing.name = 'صندوق: ${cb.name}';
        await AppDatabase.saveAccount(existing);
        return Cashbox(
          id: cb.id,
          name: cb.name,
          code: cb.code,
          accountId: existing.id,
          accountName: existing.name,
          openingBalance: cb.openingBalance,
          currentBalance: cb.currentBalance,
          isActive: cb.isActive,
        );
      }
    }
    final all = AppDatabase.accounts;
    for (final a in all) {
      if (a.parentId == parent.id && a.name == 'صندوق: ${cb.name}') {
        return Cashbox(
          id: cb.id,
          name: cb.name,
          code: cb.code,
          accountId: a.id,
          accountName: a.name,
          openingBalance: cb.openingBalance,
          currentBalance: cb.currentBalance,
          isActive: cb.isActive,
        );
      }
    }
    final child = await _createChild(
      parent: parent,
      name: 'صندوق: ${cb.name}',
      openingBalance: cb.openingBalance,
    );
    return Cashbox(
      id: cb.id,
      name: cb.name,
      code: cb.code,
      accountId: child.id,
      accountName: child.name,
      openingBalance: cb.openingBalance,
      currentBalance: cb.currentBalance,
      isActive: cb.isActive,
    );
  }

  // ======================= المخازن =======================
  static Future<void> ensureWarehouseAccount(Warehouse w) async {
    final parent = parentFor('warehouse');
    if (parent == null) return;
    final targetName = 'مخزون: ${w.name}';
    final all = AppDatabase.accounts;
    for (final a in all) {
      if (a.parentId == parent.id && a.name == targetName) return;
    }
    await _createChild(parent: parent, name: targetName);
  }

  // ======================= الموظفون =======================
  static Future<String> ensureEmployeeAccount(Employee e) async {
    final parent = AppDatabase.accountByCode(CoA.salariesExpense);
    if (parent == null) return e.salaryAccountId;
    if (e.salaryAccountId.isNotEmpty) {
      final existing = AppDatabase.accountById(e.salaryAccountId);
      if (existing != null) {
        existing.name = 'راتب: ${e.name}';
        await AppDatabase.saveAccount(existing);
        return existing.id;
      }
    }
    final all = AppDatabase.accounts;
    for (final a in all) {
      if (a.parentId == parent.id && a.name == 'راتب: ${e.name}') return a.id;
    }
    final child = await _createChild(parent: parent, name: 'راتب: ${e.name}');
    return child.id;
  }

  // ======================= مزامنة شاملة =======================
  /// يزامن كل الكيانات القائمة مع دليل الحسابات (تُستدعى مرة عند الترقية/الطلب)
  static Future<int> syncAll() async {
    var count = 0;

    for (final c in AppDatabase.contacts) {
      if (c.isDeleted) continue;
      final before = c.accountId;
      final id = await ensureContactAccount(c);
      if (before != id) {
        c.accountId = id;
        await AppDatabase.saveContact(c);
        count++;
      }
    }

    for (final cb in AppDatabase.cashboxes) {
      final before = cb.accountId;
      final updated = await ensureCashboxAccount(cb);
      if (updated.accountId != before) {
        await AppDatabase.saveCashbox(updated);
        count++;
      }
    }

    for (final w in AppDatabase.warehouses) {
      await ensureWarehouseAccount(w);
      count++;
    }

    for (final e in AppDatabase.employees) {
      if (!e.isActive) continue;
      final id = await ensureEmployeeAccount(e);
      if (e.salaryAccountId != id) {
        e.salaryAccountId = id;
        await AppDatabase.saveEmployee(e);
        count++;
      }
    }

    return count;
  }
}
