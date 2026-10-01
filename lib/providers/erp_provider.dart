// ============================================================================
// المزود الرئيسي — ERPProvider
// يربط الواجهات بطبقة البيانات ومحرك القيود
// ============================================================================
import 'package:flutter/material.dart';
import '../data/app_database.dart';
import '../models/models.dart';
import '../services/journal_engine.dart';

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
    initialized = true;
    notifyListeners();
  }

  // ---------------------------- الإعدادات ----------------------------
  String get companyName => AppDatabase.getSetting('companyName', 'شركتي');
  String get companyPhone => AppDatabase.getSetting('companyPhone');
  String get companyAddress => AppDatabase.getSetting('companyAddress');
  String get currency => AppDatabase.getSetting('currency', 'ر.س');
  double get taxRate =>
      double.tryParse(AppDatabase.getSetting('taxRate', '15')) ?? 0.0;
  String get invoiceFooter => AppDatabase.getSetting('invoiceFooter');
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

  // ============================ جهات الاتصال ============================
  Future<Contact> addContact(Contact c) async {
    final id = c.id.isEmpty ? AppDatabase.newId() : c.id;
    final contact = Contact(
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
    reload();
    return contact;
  }

  Future<void> updateContact(Contact c) async {
    await AppDatabase.saveContact(c);
    reload();
  }

  Future<void> deleteContact(String id) async {
    await AppDatabase.deleteContact(id);
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
    await AppDatabase.deleteItem(id);
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
  }) async {
    final isSale = invoiceType == 'sale' || invoiceType == 'sale_return';
    final isReturn =
        invoiceType == 'sale_return' || invoiceType == 'purchase_return';
    final contact = AppDatabase.contactById(contactId);

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
    await AppDatabase.deleteInvoice(id);
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
    reload();
    return p;
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
}
