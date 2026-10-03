import 'dart:convert';
import 'dart:typed_data';
// ============================================================================
// المزود الرئيسي — ERPProvider
// يربط الواجهات بطبقة البيانات ومحرك القيود
// ============================================================================
import 'package:flutter/material.dart';
import '../data/app_database.dart';
import '../data/chart_of_accounts.dart';
import '../models/models.dart';
import '../services/journal_engine.dart';
import '../services/local_notifications.dart';
import '../services/account_sync_service.dart';
import '../theme/app_theme.dart';

class ERPProvider extends ChangeNotifier {
  // ---------------------------- البيانات ----------------------------
  List<Account> accounts = [];
  List<Contact> contacts = [];
  List<Item> items = [];
  List<ItemCategory> categories = [];
  List<Invoice> invoices = [];
  List<Payment> payments = [];
  List<Expense> expenses = [];
  List<ExpenseCategory> expenseCategories = [];
  List<InventoryMovement> movements = [];
  List<InventoryBalance> balances = [];
  List<Cashbox> cashboxes = [];
  List<Warehouse> warehouses = [];
  List<JournalEntry> journals = [];
  List<Employee> employees = [];
  List<Attendance> attendance = [];
  List<PayrollRecord> payrolls = [];
  List<Currency> currencies = [];
  List<Branch> branches = [];
  List<Unit> units = [];
  List<CostCenter> costCenters = [];
  List<ExchangeRate> exchangeRates = [];
  List<AuditLog> auditLogs = [];
  List<OrderDoc> orders = [];
  List<AppNotification> notifications = [];

  bool initialized = false;

  ERPProvider() {
    reload();
  }

  // ---------------------------- التحميل ----------------------------
  void reload() {
    accounts = AppDatabase.accounts;
    contacts = AppDatabase.contacts;
    items = AppDatabase.items;
    categories = AppDatabase.categories;
    invoices = AppDatabase.invoices;
    payments = AppDatabase.payments;
    expenses = AppDatabase.expenses;
    expenseCategories = AppDatabase.expenseCategories;
    movements = AppDatabase.movements;
    balances = AppDatabase.balances;
    cashboxes = AppDatabase.cashboxes;
    warehouses = AppDatabase.warehouses;
    journals = AppDatabase.journals;
    employees = AppDatabase.employees;
    attendance = AppDatabase.attendance;
    payrolls = AppDatabase.payrolls;
    currencies = AppDatabase.currencies;
    branches = AppDatabase.branches;
    units = AppDatabase.units;
    costCenters = AppDatabase.costCenters;
    exchangeRates = AppDatabase.exchangeRates;
    auditLogs = AppDatabase.auditLogs;
    orders = AppDatabase.orders;
    notifications = AppDatabase.notifications;
    fixedAssets = AppDatabase.fixedAssets;
    initialized = true;
    notifyListeners();
  }

  // ---------------------------- الإعدادات ----------------------------
  String get companyName => AppDatabase.getSetting('companyName', 'شركتي');
  String get companyPhone => AppDatabase.getSetting('companyPhone');
  String get companyAddress => AppDatabase.getSetting('companyAddress');
  String get currency => AppDatabase.getSetting('currency', 'ر.ي');
  double get taxRate =>
      double.tryParse(AppDatabase.getSetting('taxRate', '15')) ?? 0.0;
  String get invoiceFooter => AppDatabase.getSetting('invoiceFooter');
  String get companyTaxNumber => AppDatabase.getSetting('taxNumber');
  String get companyCrNumber => AppDatabase.getSetting('crNumber');

  /// شعار الشركة مخزّن كـ base64 (قد يكون فارغاً)
  Uint8List? get companyLogoBytes {
    final b64 = AppDatabase.getSetting('companyLogo');
    if (b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }
  bool get allowNegativeStock =>
      AppDatabase.getSettingBool('allowNegativeStock', false);
  bool get isInit => AppDatabase.getSettingBool('isInit', false);

  Future<void> initCompany(String name, String phone, String curr) async {
    await AppDatabase.setSetting('companyName', name);
    await AppDatabase.setSetting('companyPhone', phone);
    await AppDatabase.setSetting('currency', curr);
    await AppDatabase.setSetting('isInit', 'true');
    reload();
  }

  Future<void> saveSettings(Map<String, String> values) async {
    for (final e in values.entries) {
      await AppDatabase.setSetting(e.key, e.value);
    }
    reload();
  }

  // ============================ الحسابات ============================
  Future<void> addAccount(Account acc) async {
    await AppDatabase.saveAccount(acc);
    reload();
  }

  Future<void> updateAccount(Account acc) async {
    await AppDatabase.saveAccount(acc);
    reload();
  }

  Future<void> deleteAccount(String id) async {
    await AppDatabase.deleteAccount(id);
    reload();
  }

  /// مزامنة دليل الحسابات مع كل الكيانات التشغيلية
  /// (عملاء/موردون/صناديق/مخازن/موظفون) — تُستدعى يدوياً من شاشة الدليل
  Future<int> syncChartOfAccounts() async {
    final n = await AccountSyncService.syncAll();
    reload();
    return n;
  }

  /// إضافة صندوق جديد مع إنشاء حسابه تلقائياً في الدليل
  Future<void> addCashbox(String name) async {
    var cb = Cashbox(id: AppDatabase.newId(), name: name);
    cb = await AccountSyncService.ensureCashboxAccount(cb);
    await AppDatabase.saveCashbox(cb);
    reload();
  }

  /// إضافة مخزن جديد مع إنشاء حسابه تلقائياً في الدليل
  Future<void> addWarehouse(String name, {String location = ''}) async {
    final w = Warehouse(
      id: AppDatabase.newId(),
      name: name,
      location: location,
    );
    await AppDatabase.saveWarehouse(w);
    await AccountSyncService.ensureWarehouseAccount(w);
    reload();
  }

  // ============================ جهات الاتصال ============================
  Future<Contact> addContact(Contact c) async {
    final id = c.id.isEmpty ? AppDatabase.newId() : c.id;
    var contact = Contact(
      id: id,
      code: c.code,
      name: c.name,
      contactType: c.contactType,
      phone: c.phone,
      phone2: c.phone2,
      email: c.email,
      address: c.address,
      taxNumber: c.taxNumber,
      creditLimit: c.creditLimit,
      openingBalance: c.openingBalance,
      notes: c.notes,
    );
    await AppDatabase.saveContact(contact);
    // مزامنة دليل الحسابات: إنشاء حساب فرعي تحت العملاء/الموردين
    try {
      final accId = await AccountSyncService.ensureContactAccount(contact);
      if (accId.isNotEmpty && accId != contact.accountId) {
        contact.accountId = accId;
        await AppDatabase.saveContact(contact);
      }
    } catch (_) {}
    reload();
    return contact;
  }

  Future<void> updateContact(Contact c) async {
    await AppDatabase.saveContact(c);
    // تحديث الحساب المرتبط (الاسم/الرصيد الافتتاحي)
    try {
      final accId = await AccountSyncService.ensureContactAccount(c);
      if (accId.isNotEmpty && accId != c.accountId) {
        c.accountId = accId;
        await AppDatabase.saveContact(c);
      }
    } catch (_) {}
    reload();
  }

  Future<void> deleteContact(String id) async {
    final c = AppDatabase.contactById(id);
    if (c == null) return;
    c.isDeleted = true;
    await AppDatabase.saveContact(c);
    try {
      await AccountSyncService.removeContactAccount(c.accountId);
    } catch (_) {}
    reload();
  }

  // ============================ الأصناف ============================
  Future<void> addItem(Item it) async {
    await AppDatabase.saveItem(it);
    reload();
  }

  Future<void> updateItem(Item it) async {
    await AppDatabase.saveItem(it);
    reload();
  }

  Future<void> deleteItem(String id) async {
    final it = AppDatabase.itemById(id);
    if (it == null) return;
    it.isDeleted = true;
    await AppDatabase.saveItem(it);
    reload();
  }

  Future<void> addCategory(ItemCategory c) async {
    await AppDatabase.saveCategory(c);
    reload();
  }

  double stockQty(String itemId) => AppDatabase.totalStockQty(itemId);

  double itemAvgCost(String itemId) {
    final itemBalances =
        balances.where((b) => b.itemId == itemId && b.quantity > 0).toList();
    if (itemBalances.isEmpty) return 0.0;
    double totalQty = 0;
    double totalVal = 0;
    for (final b in itemBalances) {
      totalQty += b.quantity;
      totalVal += b.quantity * b.avgCost;
    }
    return totalQty == 0 ? 0.0 : totalVal / totalQty;
  }

  // ============================ إنشاء فاتورة (المحرك الكامل) ============================
  /// ينفّذ التدفق الكامل: فاتورة + مخزون + قيد + صندوق + رصيد جهة الاتصال
  Future<Invoice> createInvoice({
    required String invoiceType, // sale/purchase/sale_return/purchase_return
    required String paymentType, // cash/credit
    required String date,
    String? contactId,
    required String warehouseId,
    String? cashboxId,
    required List<InvoiceLine> lines,
    double discountAmount = 0.0,
    double taxAmount = 0.0,
    double shipping = 0.0,
    String notes = '',
    double paidAmount = 0.0,
    String? originalInvoiceId,
  }) async {
    final isSale = invoiceType == 'sale' || invoiceType == 'sale_return';
    final isReturn =
        invoiceType == 'sale_return' || invoiceType == 'purchase_return';
    final contact = AppDatabase.contactById(contactId);

    // التحقق من الكمية المرتجعة ≤ الكمية المباعة - المرتجع سابقاً
    if (isReturn && originalInvoiceId != null && originalInvoiceId.isNotEmpty) {
      final original =
          AppDatabase.invoices.where((i) => i.id == originalInvoiceId).toList();
      if (original.isNotEmpty) {
        final origInv = original.first;
        // الرصيد المتاح للإرجاع لكل صنف
        final Map<String, double> previouslyReturned = {};
        for (final r in AppDatabase.invoices.where(
            (i) => i.originalInvoiceId == originalInvoiceId)) {
          for (final rl in r.lines) {
            previouslyReturned[rl.itemId] =
                (previouslyReturned[rl.itemId] ?? 0) + rl.quantity;
          }
        }
        for (final l in lines) {
          final soldLine = origInv.lines
              .where((ol) => ol.itemId == l.itemId)
              .fold(0.0, (s, ol) => s + ol.quantity);
          final already = previouslyReturned[l.itemId] ?? 0;
          final available = soldLine - already;
          if (l.quantity > available + 0.001) {
            throw Exception(
              'الكمية المرتجعة للصنف "${l.itemName}" (${l.quantity}) تتجاوز '
              'المتاح للإرجاع ($available)',
            );
          }
        }
      }
    }

    // حساب المجاميع
    final subtotal = lines.fold(0.0, (s, l) => s + l.lineSubtotal);
    final lineTax = lines.fold(0.0, (s, l) => s + l.taxAmount);
    final totalTax = lineTax + taxAmount;
    final total = subtotal - discountAmount + totalTax + shipping;

    // جلب تكلفة الأصناف الحالية (للبيع)
    final filledLines = <InvoiceLine>[];
    for (final l in lines) {
      double cost = l.costPrice;
      if (isSale && cost <= 0) {
        cost = itemAvgCost(l.itemId);
      }
      filledLines.add(InvoiceLine(
        itemId: l.itemId,
        itemName: l.itemName,
        quantity: l.quantity,
        unitPrice: l.unitPrice,
        discount: l.discount,
        taxRate: l.taxRate,
        costPrice: cost,
        unitId: l.unitId,
      ));
    }

    final prefix = switch (invoiceType) {
      'sale' => 'INV-',
      'purchase' => 'PUR-',
      'sale_return' => 'SRT-',
      _ => 'PRT-',
    };

    final inv = Invoice(
      id: AppDatabase.newId(),
      invoiceNumber: await AppDatabase.nextNumber('invoice_$invoiceType', prefix: prefix),
      invoiceType: invoiceType,
      paymentType: paymentType,
      date: date,
      contactId: contactId,
      contactName: contact?.name ?? 'عميل نقدي',
      warehouseId: warehouseId,
      cashboxId: cashboxId,
      lines: filledLines,
      discountAmount: discountAmount,
      taxAmount: totalTax,
      shipping: shipping,
      total: total,
      paidAmount: paymentType == 'cash' ? total : paidAmount,
      remaining: paymentType == 'cash' ? 0 : total - paidAmount,
      status: 'posted',
      notes: notes,
      originalInvoiceId: originalInvoiceId,
    );

    // 1) حفظ الفاتورة
    await AppDatabase.saveInvoice(inv);

    // 2) حركات المخزون + الأرصدة
    final cashbox = AppDatabase.cashboxById(cashboxId);
    for (final l in filledLines) {
      final isIn =
          (!isSale && !isReturn) || (isSale && isReturn); // شراء أو مرتجع بيع = إدخال
      await _applyStock(
        itemId: l.itemId,
        itemName: l.itemName,
        warehouseId: warehouseId,
        date: date,
        qty: l.quantity,
        unitCost: l.costPrice,
        isIn: isIn,
        refType: invoiceType,
        refId: inv.id,
      );
    }

    // 3) القيد المحاسبي
    JournalEntry? entry;
    switch (invoiceType) {
      case 'sale':
        entry = await JournalEngine.salesInvoice(inv: inv, cashbox: cashbox);
        break;
      case 'sale_return':
        entry = await JournalEngine.salesReturn(inv: inv, cashbox: cashbox);
        break;
      case 'purchase':
        entry = await JournalEngine.purchaseInvoice(inv: inv, cashbox: cashbox);
        break;
      case 'purchase_return':
        entry = await JournalEngine.purchaseReturn(inv: inv, cashbox: cashbox);
        break;
    }

    // 4) تحديث الصندوق (النقدي)
    if (paymentType == 'cash' && cashbox != null && entry != null) {
      final delta = isReturn
          ? (isSale ? -total : total) // مرتجع بيع: صرف من الصندوق / مرتجع شراء: قبض
          : (isSale ? total : -total); // بيع: قبض / شراء: صرف
      final cb = AppDatabase.cashboxById(cashbox.id)!;
      cb.currentBalance += delta;
      await AppDatabase.saveCashbox(cb);
    }

    reload();
    await logAction('create', 'invoice',
        entityId: inv.id,
        description: 'إنشاء فاتورة ${inv.invoiceNumber} بمبلغ ${inv.total}');
    return inv;
  }

  Future<void> _applyStock({
    required String itemId,
    required String itemName,
    required String warehouseId,
    required String date,
    required double qty,
    required double unitCost,
    required bool isIn,
    required String refType,
    required String refId,
  }) async {
    final bal = AppDatabase.balanceOf(itemId, warehouseId);
    final newQty = isIn ? bal.quantity + qty : bal.quantity - qty;

    // متوسط التكلفة المرجّح
    double newCost = bal.avgCost;
    if (isIn && unitCost > 0) {
      final totalQty = bal.quantity + qty;
      newCost = totalQty == 0
          ? unitCost
          : ((bal.quantity * bal.avgCost) + (qty * unitCost)) / totalQty;
    }

    await AppDatabase.saveBalance(InventoryBalance(
      itemId: itemId,
      warehouseId: warehouseId,
      quantity: newQty,
      avgCost: newCost,
    ));

    await AppDatabase.saveMovement(InventoryMovement(
      id: AppDatabase.newId(),
      itemId: itemId,
      itemName: itemName,
      warehouseId: warehouseId,
      date: date,
      movementType: refType,
      referenceType: refType,
      referenceId: refId,
      quantityIn: isIn ? qty : 0,
      quantityOut: isIn ? 0 : qty,
      unitCost: unitCost > 0 ? unitCost : bal.avgCost,
      balanceAfter: newQty,
    ));
  }

  Future<void> deleteInvoice(String id) async {
    final inv = AppDatabase.invoices.where((i) => i.id == id).toList();
    if (inv.isEmpty) {
      // قد تكون محذوفة منطقياً سابقاً — نحذف فعلياً من الصندوق
      await AppDatabase.deleteInvoice(id);
    } else {
      final i = inv.first;
      i.isDeleted = true;
      await AppDatabase.saveInvoice(i);
      await logAction('delete', 'invoice',
          entityId: i.id, description: 'حذف فاتورة ${i.invoiceNumber}');
    }
    reload();
  }

  // ============================ السندات ============================
  Future<Payment> createPayment({
    required String paymentType, // receipt/payment
    required String date,
    String? contactId,
    String? cashboxId,
    required double amount,
    String description = '',
    List<Map<String, dynamic>> allocations = const [],
  }) async {
    final contact = AppDatabase.contactById(contactId);
    final p = Payment(
      id: AppDatabase.newId(),
      paymentNumber: await AppDatabase.nextNumber(
        'payment_$paymentType',
        prefix: paymentType == 'receipt' ? 'RCV-' : 'PAY-',
      ),
      paymentType: paymentType,
      date: date,
      contactId: contactId,
      contactName: contact?.name ?? '',
      cashboxId: cashboxId,
      amount: amount,
      description: description,
    );
    await AppDatabase.savePayment(p);

    final cashbox = AppDatabase.cashboxById(cashboxId);
    if (paymentType == 'receipt') {
      await JournalEngine.receipt(p: p, cashbox: cashbox);
    } else {
      await JournalEngine.paymentVoucher(p: p, cashbox: cashbox);
    }

    if (cashbox != null) {
      final cb = AppDatabase.cashboxById(cashbox.id)!;
      cb.currentBalance += paymentType == 'receipt' ? amount : -amount;
      await AppDatabase.saveCashbox(cb);
    }

    // تخصيص الدفعة على الفواتير الآجلة
    for (final a in allocations) {
      final invId = a['invoiceId'] as String? ?? '';
      final allocAmt = (a['amount'] as num?)?.toDouble() ?? 0.0;
      if (invId.isEmpty || allocAmt <= 0) continue;
      final list = AppDatabase.invoices.where((i) => i.id == invId).toList();
      if (list.isEmpty) continue;
      final inv = list.first;
      await AppDatabase.saveAllocation(PaymentAllocation(
        id: AppDatabase.newId(),
        paymentId: p.id,
        invoiceType: inv.invoiceType,
        invoiceId: inv.id,
        invoiceNumber: inv.invoiceNumber,
        amount: allocAmt,
        date: date,
      ));
      inv.paidAmount += allocAmt;
      inv.remaining = (inv.total - inv.paidAmount);
      if (inv.remaining < 0.001) {
        inv.remaining = 0;
        inv.status = 'paid';
      }
      await AppDatabase.saveInvoice(inv);
    }
    reload();
    await logAction('create', 'payment',
        entityId: p.id,
        description: 'إنشاء ${p.paymentType == 'receipt' ? 'سند قبض' : 'سند صرف'} ${p.paymentNumber} بمبلغ ${p.amount}');
    return p;
  }

  /// الفواتير الآجلة غير المسددة لجهة اتصال معينة
  List<Invoice> unpaidInvoices(String contactId, String paymentType) {
    return invoices.where((inv) {
      if (inv.contactId != contactId) return false;
      if (inv.status == 'cancelled') return false;
      if (inv.remaining <= 0.001) return false;
      if (paymentType == 'receipt') {
        return inv.invoiceType == 'sale';
      } else {
        return inv.invoiceType == 'purchase';
      }
    }).toList();
  }

  // ============================ المصروفات ============================
  Future<Expense> createExpense({
    required String date,
    required ExpenseCategory category,
    required double amount,
    required double taxAmount,
    String? cashboxId,
    String description = '',
  }) async {
    final e = Expense(
      id: AppDatabase.newId(),
      expenseNumber: await AppDatabase.nextNumber('expense', prefix: 'EXP-'),
      date: date,
      categoryId: category.id,
      categoryName: category.name,
      accountId: category.accountId,
      accountName: category.accountName,
      amount: amount,
      taxAmount: taxAmount,
      total: amount + taxAmount,
      cashboxId: cashboxId,
      description: description,
    );
    await AppDatabase.saveExpense(e);

    final cashbox = AppDatabase.cashboxById(cashboxId);
    final entry = await JournalEngine.expense(e: e, cashbox: cashbox);
    if (cashbox != null && entry.id.isNotEmpty) {
      final cb = AppDatabase.cashboxById(cashbox.id)!;
      cb.currentBalance -= e.total;
      await AppDatabase.saveCashbox(cb);
    }
    reload();
    await logAction('create', 'expense',
        entityId: e.id, description: 'إنشاء مصروف ${e.expenseNumber} بمبلغ ${e.total}');
    return e;
  }

  Future<void> addExpenseCategory(ExpenseCategory c) async {
    await AppDatabase.saveExpenseCategory(c);
    reload();
  }

  // ============================ تحويل مخزني ============================
  Future<void> createStockTransfer({
    required String fromWh,
    required String toWh,
    required String date,
    required List<Map<String, dynamic>> lines, // {itemId, qty}
    String notes = '',
  }) async {
    double totalCost = 0;
    for (final l in lines) {
      final itemId = l['itemId'] as String;
      final qty = (l['qty'] as num).toDouble();
      final item = AppDatabase.itemById(itemId);
      final avgCost = itemAvgCost(itemId);
      totalCost += qty * avgCost;

      // خروج من المصدر
      await _applyStock(
        itemId: itemId,
        itemName: item?.name ?? '',
        warehouseId: fromWh,
        date: date,
        qty: qty,
        unitCost: avgCost,
        isIn: false,
        refType: 'transfer_out',
        refId: '',
      );
      // دخول للهدف
      await _applyStock(
        itemId: itemId,
        itemName: item?.name ?? '',
        warehouseId: toWh,
        date: date,
        qty: qty,
        unitCost: avgCost,
        isIn: true,
        refType: 'transfer_in',
        refId: '',
      );
    }
    await JournalEngine.stockTransfer(
      date: date,
      cost: totalCost,
      fromWh: fromWh,
      toWh: toWh,
    );
    reload();
  }

  // ============================ تسوية الجرد ============================
  Future<void> createStockAdjustment({
    required String warehouseId,
    required String date,
    required List<Map<String, dynamic>> lines, // {itemId, actualQty}
    String notes = '',
  }) async {
    double diffValue = 0;
    for (final l in lines) {
      final itemId = l['itemId'] as String;
      final actual = (l['actualQty'] as num).toDouble();
      final bal = AppDatabase.balanceOf(itemId, warehouseId);
      final diff = actual - bal.quantity;
      if (diff == 0) continue;
      final item = AppDatabase.itemById(itemId);
      final cost = bal.avgCost > 0 ? bal.avgCost : (item?.purchasePrice ?? 0);
      diffValue += diff * cost;

      await AppDatabase.saveBalance(InventoryBalance(
        itemId: itemId,
        warehouseId: warehouseId,
        quantity: actual,
        avgCost: bal.avgCost,
      ));

      await AppDatabase.saveMovement(InventoryMovement(
        id: AppDatabase.newId(),
        itemId: itemId,
        itemName: item?.name ?? '',
        warehouseId: warehouseId,
        date: date,
        movementType: diff > 0 ? 'adjustment_in' : 'adjustment_out',
        referenceType: 'adjustment',
        quantityIn: diff > 0 ? diff : 0,
        quantityOut: diff < 0 ? diff.abs() : 0,
        unitCost: cost,
        balanceAfter: actual,
        notes: notes,
      ));
    }
    if (diffValue.abs() > 0.001) {
      await JournalEngine.stockAdjustment(
        date: date,
        diffValue: diffValue,
        notes: notes,
      );
    }
    reload();
  }

  // ============================ رأس المال ============================
  Future<void> addCapital({
    required double amount,
    required String date,
    required bool isInjection,
    String? cashboxId,
  }) async {
    final cashbox = AppDatabase.cashboxById(cashboxId);
    final entry = await JournalEngine.capital(
      date: date,
      amount: amount,
      isInjection: isInjection,
      cashbox: cashbox,
    );
    if (cashbox != null && entry.id.isNotEmpty) {
      final cb = AppDatabase.cashboxById(cashbox.id)!;
      cb.currentBalance += isInjection ? amount : -amount;
      await AppDatabase.saveCashbox(cb);
    }
    reload();
  }

  // ============================ التقارير ============================
  /// أرصدة الحسابات: مجموع مدين/دائن لكل حساب من القيود
  Map<String, Map<String, double>> accountBalances() {
    final Map<String, Map<String, double>> result = {};
    for (final a in accounts) {
      result[a.id] = {'debit': 0.0, 'credit': 0.0};
    }
    for (final j in journals) {
      for (final l in j.lines) {
        if (result.containsKey(l.accountId)) {
          result[l.accountId]!['debit'] =
              result[l.accountId]!['debit']! + l.debit;
          result[l.accountId]!['credit'] =
              result[l.accountId]!['credit']! + l.credit;
        }
      }
    }
    // إضافة الأرصدة الافتتاحية
    for (final a in accounts) {
      if (a.openingBalance != 0) {
        final isDebitNature = a.accountNature == 'debit';
        if (isDebitNature) {
          result[a.id]!['debit'] = result[a.id]!['debit']! + a.openingBalance;
        } else {
          result[a.id]!['credit'] =
              result[a.id]!['credit']! + a.openingBalance;
        }
      }
    }
    return result;
  }

  /// رصيد حساب واحد (موجب = مدين، سالب = دائن)
  double accountBalance(String accountId) {
    final bals = accountBalances();
    final b = bals[accountId];
    if (b == null) return 0.0;
    return (b['debit'] ?? 0) - (b['credit'] ?? 0);
  }

  /// رصيد جهة اتصال
  double contactBalance(String contactId) {
    final contact = AppDatabase.contactById(contactId);
    if (contact == null) return 0.0;
    double bal = contact.openingBalance;
    for (final inv in invoices) {
      if (inv.contactId != contactId || inv.status == 'cancelled') continue;
      if (inv.invoiceType == 'sale') {
        bal += inv.paymentType == 'credit' ? inv.total : 0;
      } else if (inv.invoiceType == 'sale_return') {
        bal -= inv.total;
      } else if (inv.invoiceType == 'purchase') {
        bal -= inv.paymentType == 'credit' ? inv.total : 0;
      } else if (inv.invoiceType == 'purchase_return') {
        bal += inv.total;
      }
    }
    for (final p in payments) {
      if (p.contactId != contactId) continue;
      if (p.paymentType == 'receipt') bal -= p.amount;
      if (p.paymentType == 'payment') bal += p.amount;
    }
    return bal;
  }

  // ---------------------------- إحصاءات لوحة التحكم ----------------------------
  double get todaySales {
    final today = _today();
    return invoices
        .where((i) => i.invoiceType == 'sale' && i.date == today)
        .fold(0.0, (s, i) => s + i.total);
  }

  double get todayPurchases {
    final today = _today();
    return invoices
        .where((i) => i.invoiceType == 'purchase' && i.date == today)
        .fold(0.0, (s, i) => s + i.total);
  }

  double get cashBalance =>
      cashboxes.fold(0.0, (s, c) => s + c.currentBalance);

  double get totalReceivables => contacts
      .where((c) => c.contactType != 'supplier')
      .fold(0.0, (s, c) => s + (contactBalance(c.id) > 0 ? contactBalance(c.id) : 0));

  double get totalPayables => contacts
      .where((c) => c.contactType != 'customer')
      .fold(0.0, (s, c) => s + (contactBalance(c.id) < 0 ? -contactBalance(c.id) : 0));

  double get inventoryValue =>
      balances.fold(0.0, (s, b) => s + b.quantity * b.avgCost);

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  // مبيعات آخر 7 أيام للرسم البياني
  List<Map<String, dynamic>> get weeklySales {
    final result = <Map<String, dynamic>>[];
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final total = invoices
          .where((inv) => inv.invoiceType == 'sale' && inv.date == key)
          .fold(0.0, (s, inv) => s + inv.total);
      result.add({'day': d, 'total': total});
    }
    return result;
  }

  // ---------------------------- مبيعات الشهر (رسم بياني) ----------------------------
  List<Map<String, dynamic>> monthlySalesByDay(int days) {
    final result = <Map<String, dynamic>>[];
    final now = DateTime.now();
    for (int i = days - 1; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final total = invoices
          .where((inv) => inv.invoiceType == 'sale' && inv.date == key)
          .fold(0.0, (s, inv) => s + inv.total);
      result.add({'day': d, 'total': total});
    }
    return result;
  }

  // ============================ الموارد البشرية ============================
  Future<void> addEmployee(Employee e) async {
    await AppDatabase.saveEmployee(e);
    reload();
  }

  Future<void> updateEmployee(Employee e) async {
    await AppDatabase.saveEmployee(e);
    reload();
  }

  Future<void> deleteEmployee(String id) async {
    await AppDatabase.deleteEmployee(id);
    reload();
  }

  Future<void> saveAttendance(Attendance a) async {
    await AppDatabase.saveAttendance(a);
    reload();
  }

  /// إنشاء مسير راتب لموظف
  Future<PayrollRecord> createPayroll({
    required Employee employee,
    required String period, // 2025-06
    required String date,
    double overtimeAmount = 0.0,
    double advanceDeduction = 0.0,
    String? cashboxId,
  }) async {
    final netPay = employee.basicSalary +
        employee.allowances +
        overtimeAmount -
        employee.deductions -
        advanceDeduction;

    final rec = PayrollRecord(
      id: AppDatabase.newId(),
      payrollNumber: await AppDatabase.nextNumber('payroll', prefix: 'PRL-'),
      employeeId: employee.id,
      employeeName: employee.name,
      period: period,
      date: date,
      basicSalary: employee.basicSalary,
      allowances: employee.allowances,
      overtimeAmount: overtimeAmount,
      deductions: employee.deductions,
      advanceDeduction: advanceDeduction,
      netPay: netPay,
      cashboxId: cashboxId,
    );
    await AppDatabase.savePayroll(rec);

    final cashbox = AppDatabase.cashboxById(cashboxId);
    final entry = await JournalEngine.payroll(rec: rec, cashbox: cashbox);
    if (cashbox != null && entry.id.isNotEmpty) {
      final cb = AppDatabase.cashboxById(cashbox.id)!;
      cb.currentBalance -= netPay;
      await AppDatabase.saveCashbox(cb);
    }
    reload();
    return rec;
  }

  double get monthlyPayrollTotal {
    final period = _today().substring(0, 7);
    return payrolls
        .where((p) => p.period == period)
        .fold(0.0, (s, p) => s + p.netPay);
  }

  // ============================ العملات ============================
  Future<void> addCurrency(Currency c) async {
    await AppDatabase.saveCurrency(c);
    reload();
  }

  Future<void> updateCurrency(Currency c) async {
    await AppDatabase.saveCurrency(c);
    reload();
  }

  Future<void> deleteCurrency(String id) async {
    await AppDatabase.deleteCurrency(id);
    reload();
  }

  Currency? get baseCurrency {
    if (currencies.isEmpty) return null;
    try {
      return currencies.firstWhere((c) => c.isBase);
    } catch (_) {
      return currencies.first;
    }
  }

  // ============================ الأمان (PIN) ============================
  bool get pinEnabled => AppDatabase.getSettingBool('pinEnabled', false);
  String get pin => AppDatabase.getSetting('pin', '');

  Future<void> setPin(bool enabled, String value) async {
    await AppDatabase.setSetting('pinEnabled', enabled ? 'true' : 'false');
    await AppDatabase.setSetting('pin', value);
    reload();
  }

  // ============================ الإقفال السنوي ============================
  String get fiscalYearClosed =>
      AppDatabase.getSetting('fiscalYearClosed', '');

  /// إقفال السنة المالية: ترحيل صافي الربح إلى الأرباح المحتجزة
  Future<JournalEntry?> closeFiscalYear(String year) async {
    // حساب صافي الربح من الإيرادات والمصروفات
    final bals = accountBalances();
    double revenue = 0, expense = 0;
    for (final a in accounts) {
      if (!a.isLeaf) continue;
      final b = bals[a.id];
      if (b == null) continue;
      final bal = (b['debit'] ?? 0) - (b['credit'] ?? 0);
      if (a.accountType == 'revenue') {
        revenue += -bal; // الإيراد طبيعته دائن
      } else if (a.accountType == 'expense') {
        expense += bal; // المصروف طبيعته مدين
      }
    }
    final netProfit = revenue - expense;
    final date = '$year-12-31';
    final retained = AppDatabase.accountByCode(CoA.retainedEarnings);
    final netProfitAcc = AppDatabase.accountByCode(CoA.inventoryGain);
    final lines = <JournalLine>[];
    if (netProfit >= 0) {
      lines.add(JournalLine(
          accountId: netProfitAcc?.id ?? '',
          accountName: netProfitAcc?.name ?? 'صافي الربح',
          debit: netProfit,
          description: 'صافي ربح السنة'));
      lines.add(JournalLine(
          accountId: retained?.id ?? '',
          accountName: retained?.name ?? 'أرباح محتجزة',
          credit: netProfit,
          description: 'ترحيل للأرباح المحتجزة'));
    } else {
      lines.add(JournalLine(
          accountId: retained?.id ?? '',
          accountName: retained?.name ?? 'أرباح محتجزة',
          debit: netProfit.abs(),
          description: 'تغطية خسارة'));
      lines.add(JournalLine(
          accountId: netProfitAcc?.id ?? '',
          accountName: netProfitAcc?.name ?? 'صافي الخسارة',
          credit: netProfit.abs(),
          description: 'صافي خسارة السنة'));
    }
    final closed = await JournalEngine.post(
      date: date,
      description: 'ترحيل صافي الربح/الخسارة للسنة $year',
      sourceType: 'fiscal_close',
      lines: lines,
    );
    await AppDatabase.setSetting('fiscalYearClosed', year);
    reload();
    return closed;
  }

  // ============================ التنبيهات ============================
  /// أصناف وصلت لحد الطلب
  List<Item> get lowStockItems {
    final result = <Item>[];
    for (final it in items) {
      final qty = stockQty(it.id);
      if (it.reorderLevel > 0 && qty <= it.reorderLevel) {
        result.add(it);
      }
    }
    return result;
  }

  /// عملاء لهم مستحقات متأخرة (فواتير آجلة غير مسددة)
  List<Invoice> get overdueInvoices {
    final today = _today();
    return invoices.where((inv) {
      if (inv.invoiceType != 'sale' && inv.invoiceType != 'purchase') {
        return false;
      }
      if (inv.paymentType != 'credit') return false;
      if (inv.remaining <= 0.001) return false;
      if (inv.dueDate.isEmpty) return false;
      return inv.dueDate.compareTo(today) < 0;
    }).toList();
  }

  // ==================== إدارة الإشعارات ====================
  int get unreadNotifications => notifications.where((n) => !n.isRead).length;

  Future<void> markNotificationRead(String id) async {
    await AppDatabase.markNotificationRead(id);
    reload();
  }

  Future<void> markAllNotificationsRead() async {
    await AppDatabase.markAllNotificationsRead();
    reload();
  }

  Future<void> clearNotifications() async {
    await AppDatabase.clearNotifications();
    reload();
  }

  /// فحص دوري (يُستدعى بعد العمليات المهمة) لتوليد إشعارات جديدة:
  /// نقص المخزون + الفواتير المستحقة + تجاوز حد الائتمان
  Future<int> generateAlerts({bool push = true}) async {
    final existing = notifications;
    final existingKeys = existing
        .map((n) => '${n.type}:${n.referenceId ?? ''}')
        .toSet();
    var created = 0;

    // 1) نقص المخزون
    for (final it in lowStockItems) {
      final key = 'low_stock:${it.id}';
      if (existingKeys.contains(key)) continue;
      final qty = stockQty(it.id);
      final n = AppNotification(
        id: AppDatabase.newId(),
        type: 'low_stock',
        title: 'نقص في المخزون',
        body:
            'الصنف "${it.name}" وصل للحد الأدنى (المتاح: ${Fmt.num(qty)}، حد الطلب: ${Fmt.num(it.reorderLevel)})',
        referenceType: 'item',
        referenceId: it.id,
      );
      await AppDatabase.saveNotification(n);
      if (push) await LocalNotifications.lowStock(it.name, qty, it.reorderLevel);
      created++;
    }

    // 2) الفواتير المستحقة (تاريخ الاستحقاق قريب أو فائت)
    for (final inv in overdueInvoices) {
      final key = 'invoice_due:${inv.id}';
      if (existingKeys.contains(key)) continue;
      final n = AppNotification(
        id: AppDatabase.newId(),
        type: 'invoice_due',
        title: 'فاتورة مستحقة السداد',
        body:
            'الفاتورة ${inv.invoiceNumber} للجهة "${inv.contactName}" — المتبقي: ${Fmt.money(inv.remaining, currency)}',
        referenceType: 'invoice',
        referenceId: inv.id,
      );
      await AppDatabase.saveNotification(n);
      if (push) {
        await LocalNotifications.invoiceDue(
            inv.invoiceNumber, inv.contactName, inv.remaining, currency);
      }
      created++;
    }

    // 3) تجاوز حد الائتمان للعملاء
    for (final c in contacts) {
      if (c.creditLimit <= 0) continue;
      final bal = contactBalance(c.id);
      if (bal <= c.creditLimit) continue;
      final key = 'credit_limit:${c.id}';
      if (existingKeys.contains(key)) continue;
      final n = AppNotification(
        id: AppDatabase.newId(),
        type: 'credit_limit',
        title: 'تجاوز حد الائتمان',
        body:
            'الجهة "${c.name}" تجاوزت حد الائتمان (الرصيد: ${Fmt.money(bal, currency)}، الحد: ${Fmt.money(c.creditLimit, currency)})',
        referenceType: 'contact',
        referenceId: c.id,
      );
      await AppDatabase.saveNotification(n);
      if (push) {
        await LocalNotifications.creditLimitExceeded(c.name, bal, c.creditLimit);
      }
      created++;
    }

    if (created > 0) reload();
    return created;
  }

  // ============================ الأصول الثابتة ============================
  List<FixedAsset> fixedAssets = [];

  Future<void> addFixedAsset(FixedAsset a) async {
    await AppDatabase.saveFixedAsset(a);
    await JournalEngine.post(
      date: a.purchaseDate,
      description: 'شراء أصل: ${a.name}',
      sourceType: 'asset_purchase',
      sourceId: a.id,
      lines: [
        JournalEngine.dr(
            AppDatabase.accountByCode(a.assetAccountCode), a.cost, 'شراء أصل'),
        JournalEngine.cr(
            AppDatabase.accountByCode(CoA.cash), a.cost, 'دفع ثمن الأصل'),
      ],
    );
    reload();
  }

  Future<void> updateFixedAsset(FixedAsset a) async {
    await AppDatabase.saveFixedAsset(a);
    reload();
  }

  Future<void> deleteFixedAsset(String id) async {
    await AppDatabase.deleteFixedAsset(id);
    reload();
  }

  /// تشغيل قسط إهلاك شهري لكل الأصول النشطة (أو أصل واحد)
  Future<int> runMonthlyDepreciation({String? assetId, int months = 1}) async {
    int count = 0;
    for (final a in fixedAssets) {
      if (a.status != 'active') continue;
      if (assetId != null && a.id != assetId) continue;
      if (a.isFullyDepreciated) continue;
      double amount = a.monthlyDepreciation * months;
      final remaining = a.depreciableAmount - a.accumulatedDepreciation;
      if (amount > remaining) amount = remaining;
      if (amount <= 0.001) continue;
      a.accumulatedDepreciation += amount;
      await AppDatabase.saveFixedAsset(a);
      await JournalEngine.depreciation(asset: a, amount: amount);
      count++;
    }
    reload();
    return count;
  }

  /// تخريد أصل (بيع أو استبعاد)
  Future<void> disposeAsset({
    required String assetId,
    required double saleAmount,
    String? date,
  }) async {
    final a = AppDatabase.fixedAssetById(assetId);
    if (a == null) return;
    a.status = 'disposed';
    a.disposalAmount = saleAmount;
    a.disposalDate =
        date ?? DateTime.now().toIso8601String().substring(0, 10);
    await AppDatabase.saveFixedAsset(a);
    await JournalEngine.assetDisposal(
      asset: a,
      saleAmount: saleAmount,
      cashbox: null,
    );
    reload();
  }

  /// إجمالي قيمة الأصول بالتكلفة
  double get totalAssetCost =>
      fixedAssets.where((a) => a.status == 'active').fold(0.0, (s, a) => s + a.cost);

  /// إجمالي مجمع الإهلاك
  double get totalAccumulatedDepreciation => fixedAssets
      .where((a) => a.status == 'active')
      .fold(0.0, (s, a) => s + a.accumulatedDepreciation);

  /// صافي القيمة الدفترية
  double get totalAssetBookValue =>
      fixedAssets.where((a) => a.status == 'active').fold(0.0, (s, a) => s + a.bookValue);

  // ============================ الفروع ============================
  Future<void> addBranch(Branch b) async {
    await AppDatabase.saveBranch(b);
    reload();
  }

  Future<void> updateBranch(Branch b) async {
    await AppDatabase.saveBranch(b);
    reload();
  }

  Future<void> deleteBranch(String id) async {
    final b = AppDatabase.branchById(id);
    if (b != null) {
      b.isDeleted = true;
      await AppDatabase.saveBranch(b);
    }
    reload();
  }

  // ============================ وحدات القياس ============================
  Future<void> addUnit(Unit u) async {
    await AppDatabase.saveUnit(u);
    reload();
  }

  Future<void> updateUnit(Unit u) async {
    await AppDatabase.saveUnit(u);
    reload();
  }

  Future<void> deleteUnit(String id) async {
    final u = AppDatabase.unitById(id);
    if (u != null) {
      u.isDeleted = true;
      await AppDatabase.saveUnit(u);
    }
    reload();
  }

  Unit? unitOf(String? id) => id == null ? null : AppDatabase.unitById(id);

  // ============================ مراكز التكلفة ============================
  Future<void> addCostCenter(CostCenter c) async {
    await AppDatabase.saveCostCenter(c);
    reload();
  }

  Future<void> updateCostCenter(CostCenter c) async {
    await AppDatabase.saveCostCenter(c);
    reload();
  }

  Future<void> deleteCostCenter(String id) async {
    final c = AppDatabase.costCenterById(id);
    if (c != null) {
      c.isDeleted = true;
      await AppDatabase.saveCostCenter(c);
    }
    reload();
  }

  // ============================ أسعار الصرف ============================
  Future<void> addExchangeRate(ExchangeRate r) async {
    await AppDatabase.saveExchangeRate(r);
    reload();
  }

  Future<void> updateExchangeRate(ExchangeRate r) async {
    await AppDatabase.saveExchangeRate(r);
    reload();
  }

  Future<void> deleteExchangeRate(String id) async {
    await AppDatabase.deleteExchangeRate(id);
    reload();
  }

  List<ExchangeRate> ratesOfCurrency(String currencyId) =>
      exchangeRates.where((r) => r.currencyId == currencyId).toList();

  // ============================ سجل المراجعة ============================
  /// تسجيل عملية في سجل المراجعة
  Future<void> logAction(String action, String entity,
      {String entityId = '', String description = ''}) async {
    final log = AuditLog(
      id: AppDatabase.newId(),
      action: action,
      entity: entity,
      entityId: entityId,
      description: description,
      userName: AppDatabase.getSetting('companyName', 'مستخدم'),
      date: DateTime.now().toIso8601String(),
    );
    await AppDatabase.saveAuditLog(log);
  }

  Future<void> clearAuditLog() async {
    await AppDatabase.clearAuditLog();
    reload();
  }

  List<AuditLog> auditLogsByEntity(String entity) =>
      auditLogs.where((l) => l.entity == entity).toList();

  // ============================ المستندات التجارية (عروض/أوامر) ============================
  List<OrderDoc> ordersOfType(String docType) =>
      orders.where((o) => o.docType == docType).toList();

  Future<OrderDoc> createOrder({
    required String docType, // quotation | sales_order | purchase_order
    required String date,
    String? contactId,
    required String warehouseId,
    required List<InvoiceLine> lines,
    double discountAmount = 0.0,
    double taxAmount = 0.0,
    double shipping = 0.0,
    String validUntil = '',
    String notes = '',
  }) async {
    final contact = AppDatabase.contactById(contactId);
    final prefix = switch (docType) {
      'quotation' => 'QT-',
      'sales_order' => 'SO-',
      _ => 'PO-',
    };
    final subtotal = lines.fold<double>(0.0, (s, l) => s + l.lineSubtotal);
    final total = subtotal - discountAmount + taxAmount + shipping;
    final o = OrderDoc(
      id: AppDatabase.newId(),
      docNumber: await AppDatabase.nextNumber('order_$docType', prefix: prefix),
      docType: docType,
      date: date,
      validUntil: validUntil,
      contactId: contactId,
      contactName: contact?.name ?? '',
      warehouseId: warehouseId,
      lines: lines,
      discountAmount: discountAmount,
      taxAmount: taxAmount,
      shipping: shipping,
      total: total,
      status: 'draft',
      notes: notes,
    );
    await AppDatabase.saveOrder(o);
    reload();
    await logAction('create', 'order',
        entityId: o.id, description: 'إنشاء ${o.typeLabel} ${o.docNumber} بمبلغ ${o.total}');
    return o;
  }

  Future<void> updateOrderStatus(String id, String status) async {
    final o = AppDatabase.orderById(id);
    if (o != null) {
      o.status = status;
      await AppDatabase.saveOrder(o);
      reload();
    }
  }

  Future<void> deleteOrder(String id) async {
    final o = AppDatabase.orderById(id);
    if (o != null) {
      o.isDeleted = true;
      await AppDatabase.saveOrder(o);
      await logAction('delete', 'order',
          entityId: o.id, description: 'حذف ${o.typeLabel} ${o.docNumber}');
    }
    reload();
  }

  /// تحويل مستند (عرض سعر/أمر بيع/أمر شراء) إلى فاتورة
  Future<Invoice?> convertOrderToInvoice(
    String orderId, {
    required String paymentType, // cash/credit
    String? cashboxId,
    String? date,
  }) async {
    final o = AppDatabase.orderById(orderId);
    if (o == null) return null;
    final invoiceType = o.docType == 'purchase_order' ? 'purchase' : 'sale';
    final inv = await createInvoice(
      invoiceType: invoiceType,
      paymentType: paymentType,
      date: date ?? DateTime.now().toIso8601String().substring(0, 10),
      contactId: o.contactId,
      warehouseId: o.warehouseId,
      cashboxId: cashboxId,
      lines: o.lines,
      discountAmount: o.discountAmount,
      taxAmount: o.taxAmount,
      shipping: o.shipping,
      notes: 'محوّل من ${o.typeLabel} ${o.docNumber}',
    );
    o.status = 'converted';
    o.convertedInvoiceId = inv.id;
    await AppDatabase.saveOrder(o);
    reload();
    await logAction('post', 'order',
        entityId: o.id, description: 'تحويل ${o.typeLabel} ${o.docNumber} إلى فاتورة ${inv.invoiceNumber}');
    return inv;
  }
}
