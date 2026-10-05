// ============================================================================
// محرك القيود المزدوجة — JournalEngine
// يطبّق تدفقات البيانات لكل عملية (الجزء الرابع من المواصفة)
// قاعدة صارمة: SUM(debit) = SUM(credit)
// ============================================================================
import '../data/app_database.dart';
import '../data/chart_of_accounts.dart';
import '../models/models.dart';

class JournalEngine {
  /// إنشاء قيد متوازن وحفظه
  static Future<JournalEntry> post({
    required String date,
    required String description,
    required String sourceType,
    String? sourceId,
    required List<JournalLine> lines,
  }) async {
    // التحقق من التوازن
    final totalDebit = lines.fold(0.0, (s, l) => s + l.debit);
    final totalCredit = lines.fold(0.0, (s, l) => s + l.credit);
    if ((totalDebit - totalCredit).abs() > 0.001) {
      throw Exception('القيد غير متوازن! مدين=$totalDebit دائن=$totalCredit');
    }

    final entry = JournalEntry(
      id: AppDatabase.newId(),
      entryNumber: await AppDatabase.nextNumber('journal', prefix: 'JV-'),
      date: date,
      description: description,
      sourceType: sourceType,
      sourceId: sourceId,
      lines: lines,
    );
    await AppDatabase.saveJournal(entry);
    return entry;
  }

  static JournalLine dr(Account? acc, double amount, [String desc = '']) =>
      JournalLine(
        accountId: acc?.id ?? '',
        accountName: acc?.name ?? '',
        debit: amount,
        description: desc,
      );

  static JournalLine cr(Account? acc, double amount, [String desc = '']) =>
      JournalLine(
        accountId: acc?.id ?? '',
        accountName: acc?.name ?? '',
        credit: amount,
        description: desc,
      );

  // ======================= حلّ الحسابات الفرعية (الترحيل الصحيح) =======================
  /// حساب الصندوق: يُستخدم حساب الصندوق الفرعي إن وُجد وإلا الحساب الرئيسي.
  static Account? _cashAcc(Cashbox? cb) {
    if (cb != null && cb.accountId.isNotEmpty) {
      final a = AppDatabase.accountById(cb.accountId);
      if (a != null && a.isLeaf) return a;
    }
    return AppDatabase.accountByCode(CoA.cash);
  }

  /// حساب جهة الاتصال: يُستخدم الحساب الفرعي للعميل/المورد إن وُجد.
  static Account? _contactAcc(String? contactId, String fallbackCode) {
    if (contactId != null && contactId.isNotEmpty) {
      final c = AppDatabase.contactById(contactId);
      final accId = c?.accountId;
      if (accId != null && accId.isNotEmpty) {
        final a = AppDatabase.accountById(accId);
        if (a != null && a.isLeaf) return a;
      }
    }
    return AppDatabase.accountByCode(fallbackCode);
  }

  /// حساب المخزون: يُستخدم حساب المخزن الفرعي إن وُجد وإلا الحساب الرئيسي.
  static Account? _invAcc(String? warehouseId) {
    if (warehouseId != null && warehouseId.isNotEmpty) {
      final w = AppDatabase.warehouses
          .where((x) => x.id == warehouseId)
          .firstOrNull;
      if (w != null) {
        final acc = AppDatabase.accounts
            .where((a) => a.name == 'مخزون: ${w.name}')
            .firstOrNull;
        if (acc != null && acc.isLeaf) return acc;
      }
    }
    return AppDatabase.accountByCode(CoA.inventory);
  }

  // ============================ فاتورة مبيعات ============================
  /// تدفق 4.1 / 4.2 — نقدية أو آجلة
  static Future<JournalEntry> salesInvoice({
    required Invoice inv,
    required Cashbox? cashbox,
  }) async {
    final cash = _cashAcc(cashbox);
    final ar = _contactAcc(inv.contactId, CoA.arCustomers);
    final revenue = AppDatabase.accountByCode(CoA.salesRevenue);
    final vat = AppDatabase.accountByCode(CoA.vatPayable);
    final invAcc = _invAcc(inv.warehouseId);
    final cogs = AppDatabase.accountByCode(CoA.cogs);

    final netSales = inv.subtotal - inv.discountAmount;
    final lines = <JournalLine>[];

    // مدين: الصندوق (نقدي) أو العملاء (آجل)
    if (inv.paymentType == 'cash') {
      lines.add(dr(cash, inv.total, 'مبيعات نقدية'));
    } else {
      lines.add(dr(ar, inv.total, 'مبيعات آجلة'));
    }
    // دائن: إيرادات المبيعات
    lines.add(cr(revenue, netSales, 'إيرادات المبيعات'));
    // دائن: الضريبة المستحقة
    if (inv.taxAmount > 0) {
      lines.add(cr(vat, inv.taxAmount, 'ضريبة القيمة المضافة'));
    }
    // مدين COGS / دائن المخزون (تكلفة البضاعة)
    if (inv.totalCost > 0) {
      lines.add(dr(cogs, inv.totalCost, 'تكلفة المبيعات'));
      lines.add(cr(invAcc, inv.totalCost, 'إخراج مخزون'));
    }

    return post(
      date: inv.date,
      description: 'فاتورة مبيعات ${inv.invoiceNumber}',
      sourceType: 'sales_invoice',
      sourceId: inv.id,
      lines: lines,
    );
  }

  // ============================ مرتجع مبيعات ============================
  /// تدفق 4.3
  static Future<JournalEntry> salesReturn({
    required Invoice inv,
    required Cashbox? cashbox,
  }) async {
    final cash = _cashAcc(cashbox);
    final ar = _contactAcc(inv.contactId, CoA.arCustomers);
    final returns = AppDatabase.accountByCode(CoA.salesReturns);
    final vat = AppDatabase.accountByCode(CoA.vatPayable);
    final invAcc = _invAcc(inv.warehouseId);
    final cogs = AppDatabase.accountByCode(CoA.cogs);

    final netSales = inv.subtotal - inv.discountAmount;
    final lines = <JournalLine>[];

    // مدين: مردودات المبيعات
    lines.add(dr(returns, netSales, 'مردودات المبيعات'));
    if (inv.taxAmount > 0) {
      lines.add(dr(vat, inv.taxAmount, 'عكس ضريبة'));
    }
    // دائن: الصندوق (نقدي) أو العميل (آجل)
    if (inv.paymentType == 'cash') {
      lines.add(cr(cash, inv.total, 'مرتجع نقدي'));
    } else {
      lines.add(cr(ar, inv.total, 'مرتجع آجل'));
    }
    // مدين المخزون / دائن COGS (إعادة للمخزون)
    if (inv.totalCost > 0) {
      lines.add(dr(invAcc, inv.totalCost, 'إعادة للمخزون'));
      lines.add(cr(cogs, inv.totalCost, 'عكس تكلفة'));
    }

    return post(
      date: inv.date,
      description: 'مرتجع مبيعات ${inv.invoiceNumber}',
      sourceType: 'sales_return',
      sourceId: inv.id,
      lines: lines,
    );
  }

  // ============================ فاتورة مشتريات ============================
  /// تدفق 4.4
  static Future<JournalEntry> purchaseInvoice({
    required Invoice inv,
    required Cashbox? cashbox,
  }) async {
    final cash = _cashAcc(cashbox);
    final ap = _contactAcc(inv.contactId, CoA.apSuppliers);
    final invAcc = _invAcc(inv.warehouseId);
    final vat = AppDatabase.accountByCode(CoA.vatReceivable);

    final lines = <JournalLine>[];
    // مدين: المخزون
    lines.add(dr(invAcc, inv.subtotal - inv.discountAmount, 'مخزون مشتريات'));
    if (inv.taxAmount > 0) {
      lines.add(dr(vat, inv.taxAmount, 'ضريبة قابلة للخصم'));
    }
    // دائن: الموردون (آجل) أو الصندوق (نقدي)
    if (inv.paymentType == 'cash') {
      lines.add(cr(cash, inv.total, 'شراء نقدي'));
    } else {
      lines.add(cr(ap, inv.total, 'شراء آجل'));
    }

    return post(
      date: inv.date,
      description: 'فاتورة مشتريات ${inv.invoiceNumber}',
      sourceType: 'purchase_invoice',
      sourceId: inv.id,
      lines: lines,
    );
  }

  // ============================ مرتجع مشتريات ============================
  static Future<JournalEntry> purchaseReturn({
    required Invoice inv,
    required Cashbox? cashbox,
  }) async {
    final cash = _cashAcc(cashbox);
    final ap = _contactAcc(inv.contactId, CoA.apSuppliers);
    final invAcc = _invAcc(inv.warehouseId);
    final vat = AppDatabase.accountByCode(CoA.vatReceivable);

    final lines = <JournalLine>[];
    // مدين: الموردون (آجل) أو الصندوق (نقدي)
    if (inv.paymentType == 'cash') {
      lines.add(dr(cash, inv.total, 'مرتجع شراء نقدي'));
    } else {
      lines.add(dr(ap, inv.total, 'مرتجع شراء آجل'));
    }
    // دائن: المخزون
    lines.add(cr(invAcc, inv.subtotal - inv.discountAmount, 'مخزون مرتجع'));
    if (inv.taxAmount > 0) {
      lines.add(cr(vat, inv.taxAmount, 'عكس ضريبة'));
    }

    return post(
      date: inv.date,
      description: 'مرتجع مشتريات ${inv.invoiceNumber}',
      sourceType: 'purchase_return',
      sourceId: inv.id,
      lines: lines,
    );
  }

  // ============================ سند قبض ============================
  /// تدفق 4.5
  static Future<JournalEntry> receipt({
    required Payment p,
    required Cashbox? cashbox,
  }) async {
    final cash = _cashAcc(cashbox);
    final ar = _contactAcc(p.contactId, CoA.arCustomers);
    final lines = [
      dr(cash, p.amount, 'قبض نقدية'),
      cr(ar, p.amount, 'تحصيل من ${p.contactName}'),
    ];
    return post(
      date: p.date,
      description: 'سند قبض ${p.paymentNumber}',
      sourceType: 'receipt',
      sourceId: p.id,
      lines: lines,
    );
  }

  // ============================ سند صرف ============================
  /// تدفق 4.6
  static Future<JournalEntry> paymentVoucher({
    required Payment p,
    required Cashbox? cashbox,
  }) async {
    final cash = _cashAcc(cashbox);
    final ap = _contactAcc(p.contactId, CoA.apSuppliers);
    final lines = [
      dr(ap, p.amount, 'سداد إلى ${p.contactName}'),
      cr(cash, p.amount, 'صرف نقدية'),
    ];
    return post(
      date: p.date,
      description: 'سند صرف ${p.paymentNumber}',
      sourceType: 'payment_voucher',
      sourceId: p.id,
      lines: lines,
    );
  }

  // ============================ مصروف ============================
  /// تدفق 4.7
  static Future<JournalEntry> expense({
    required Expense e,
    required Cashbox? cashbox,
  }) async {
    final cash = _cashAcc(cashbox);
    final expAcc = AppDatabase.accountById(e.accountId);
    final lines = [
      dr(expAcc, e.total, e.description.isEmpty ? 'مصروف' : e.description),
      cr(cash, e.total, 'دفع مصروف'),
    ];
    return post(
      date: e.date,
      description: 'مصروف: ${e.categoryName}',
      sourceType: 'expense',
      sourceId: e.id,
      lines: lines,
    );
  }

  // ============================ تحويل مخزني ============================
  /// تدفق 4.8 — قيد بقيمة التكلفة (تحويل بين حسابي المخزنين)
  static Future<JournalEntry> stockTransfer({
    required String date,
    required double cost,
    required String fromWh,
    required String toWh,
  }) async {
    final fromAcc = _invAcc(fromWh);
    final toAcc = _invAcc(toWh);
    final lines = [
      dr(toAcc, cost, 'مخزون محوّل إلى $toWh'),
      cr(fromAcc, cost, 'مخزون محوّل من $fromWh'),
    ];
    return post(
      date: date,
      description: 'تحويل مخزني',
      sourceType: 'stock_transfer',
      lines: lines,
    );
  }

  // ============================ تسوية الجرد ============================
  /// تدفق 4.9
  static Future<JournalEntry> stockAdjustment({
    required String date,
    required double diffValue, // موجب=زيادة، سالب=نقص
    required String notes,
    String? warehouseId,
  }) async {
    final invAcc = _invAcc(warehouseId);
    final gain = AppDatabase.accountByCode(CoA.inventoryGain);
    final loss = AppDatabase.accountByCode(CoA.inventoryLoss);

    final lines = <JournalLine>[];
    if (diffValue >= 0) {
      lines.add(dr(invAcc, diffValue, 'زيادة جرد'));
      lines.add(cr(gain, diffValue, 'إيرادات جرد'));
    } else {
      lines.add(dr(loss, diffValue.abs(), 'خسائر جرد'));
      lines.add(cr(invAcc, diffValue.abs(), 'نقص جرد'));
    }
    return post(
      date: date,
      description: 'تسوية جرد: $notes',
      sourceType: 'stock_adjustment',
      lines: lines,
    );
  }

  // ============================ رأس المال ============================
  static Future<JournalEntry> capital({
    required String date,
    required double amount,
    required bool isInjection, // true=إيداع، false=مسحوبات
    required Cashbox? cashbox,
  }) async {
    final cash = _cashAcc(cashbox);
    final capital = AppDatabase.accountByCode(CoA.capital);
    final drawings = AppDatabase.accountByCode(CoA.drawings);

    final lines = isInjection
        ? [dr(cash, amount, 'إيداع رأس مال'), cr(capital, amount, 'رأس المال')]
        : [dr(drawings, amount, 'مسحوبات'), cr(cash, amount, 'سحب نقدية')];

    return post(
      date: date,
      description: isInjection ? 'إيداع رأس مال' : 'مسحوبات شخصية',
      sourceType: 'capital',
      lines: lines,
    );
  }

  // ============================ راتب موظف ============================
  /// تدفق 4.10 — مدين: مصروف الرواتب، دائن: الصندوق
  static Future<JournalEntry> payroll({
    required PayrollRecord rec,
    required Cashbox? cashbox,
  }) async {
    final cash = _cashAcc(cashbox);
    final salary = AppDatabase.accountByCode(CoA.salariesExpense);
    final lines = [
      dr(salary, rec.netPay, 'راتب ${rec.employeeName} — ${rec.period}'),
      cr(cash, rec.netPay, 'صرف راتب'),
    ];
    return post(
      date: rec.date,
      description: 'راتب ${rec.employeeName} (${rec.period})',
      sourceType: 'payroll',
      sourceId: rec.id,
      lines: lines,
    );
  }

  // ============================ إهلاك أصل ثابت ============================
  /// مدين: مصروف الإهلاك، دائن: مجمع الإهلاك
  static Future<JournalEntry> depreciation({
    required FixedAsset asset,
    required double amount,
  }) async {
    final exp = AppDatabase.accountByCode(CoA.depreciationExpense);
    final accDep = AppDatabase.accountByCode(CoA.accumulatedDepreciation);
    final lines = [
      dr(exp, amount, 'إهلاك ${asset.name}'),
      cr(accDep, amount, 'مجمع إهلاك ${asset.name}'),
    ];
    return post(
      date: DateTime.now().toIso8601String().substring(0, 10),
      description: 'قسط إهلاك: ${asset.name}',
      sourceType: 'depreciation',
      sourceId: asset.id,
      lines: lines,
    );
  }

  // ============================ تخريد/بيع أصل ============================
  /// القيمة الدفترية = التكلفة - مجمع الإهلاك
  /// - إذا بيع بمبلغ: مدين الصندوق + مجمع الإهلاك، دائن الأصل،
  ///   والفرق ربح (إيراد) أو خسارة (مصروف).
  static Future<JournalEntry> assetDisposal({
    required FixedAsset asset,
    required double saleAmount,
    required Cashbox? cashbox,
  }) async {
    final cash = _cashAcc(cashbox);
    final assetAcc = AppDatabase.accountByCode(asset.assetAccountCode);
    final accDep = AppDatabase.accountByCode(CoA.accumulatedDepreciation);
    final gain = AppDatabase.accountByCode(CoA.otherRevenue);
    final loss = AppDatabase.accountByCode(CoA.inventoryLoss);

    final bookValue = asset.bookValue;
    final diff = saleAmount - bookValue; // موجب = ربح، سالب = خسارة

    final lines = <JournalLine>[];
    if (saleAmount > 0) {
      lines.add(dr(cash, saleAmount, 'بيع أصل'));
    }
    if (asset.accumulatedDepreciation > 0) {
      lines.add(
        dr(accDep, asset.accumulatedDepreciation, 'استبعاد مجمع الإهلاك'),
      );
    }
    lines.add(cr(assetAcc, asset.cost, 'استبعاد الأصل'));
    if (diff > 0.001) {
      lines.add(cr(gain, diff, 'ربح بيع أصل'));
    } else if (diff < -0.001) {
      lines.add(dr(loss, diff.abs(), 'خسارة بيع أصل'));
    }

    return post(
      date: asset.disposalDate.isEmpty
          ? DateTime.now().toIso8601String().substring(0, 10)
          : asset.disposalDate,
      description: 'تخريد الأصل: ${asset.name}',
      sourceType: 'asset_disposal',
      sourceId: asset.id,
      lines: lines,
    );
  }
}
