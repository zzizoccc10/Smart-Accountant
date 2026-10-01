// ============================================================================
// المحاسب السهل — نماذج البيانات الأساسية
// مبنية على المواصفة الفنية الكاملة (Double-Entry ERP)
// ============================================================================

/// الحساب المحاسبي — جدول accounts
class Account {
  final String id;
  String code; // رمز الحساب (1-1-01)
  String name;
  String nameEn;
  String accountType; // asset/liability/equity/revenue/expense
  String accountNature; // debit/credit
  String? parentId;
  int level;
  bool isLeaf; // حساب فرعي يقبل القيود
  bool isCash;
  bool isSystem; // حساب نظامي لا يُحذف
  double openingBalance;
  bool isActive;

  Account({
    required this.id,
    required this.code,
    required this.name,
    this.nameEn = '',
    required this.accountType,
    required this.accountNature,
    this.parentId,
    this.level = 1,
    this.isLeaf = true,
    this.isCash = false,
    this.isSystem = false,
    this.openingBalance = 0.0,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'code': code,
    'name': name,
    'nameEn': nameEn,
    'accountType': accountType,
    'accountNature': accountNature,
    'parentId': parentId,
    'level': level,
    'isLeaf': isLeaf,
    'isCash': isCash,
    'isSystem': isSystem,
    'openingBalance': openingBalance,
    'isActive': isActive,
  };

  factory Account.fromMap(Map<String, dynamic> m) => Account(
    id: m['id'] as String,
    code: m['code'] as String? ?? '',
    name: m['name'] as String? ?? '',
    nameEn: m['nameEn'] as String? ?? '',
    accountType: m['accountType'] as String? ?? 'asset',
    accountNature: m['accountNature'] as String? ?? 'debit',
    parentId: m['parentId'] as String?,
    level: (m['level'] as num?)?.toInt() ?? 1,
    isLeaf: m['isLeaf'] as bool? ?? true,
    isCash: m['isCash'] as bool? ?? false,
    isSystem: m['isSystem'] as bool? ?? false,
    openingBalance: (m['openingBalance'] as num?)?.toDouble() ?? 0.0,
    isActive: m['isActive'] as bool? ?? true,
  );
}

/// سطر القيد — journal_entry_lines
class JournalLine {
  String accountId;
  String accountName;
  double debit;
  double credit;
  String description;

  JournalLine({
    required this.accountId,
    required this.accountName,
    this.debit = 0.0,
    this.credit = 0.0,
    this.description = '',
  });

  Map<String, dynamic> toMap() => {
    'accountId': accountId,
    'accountName': accountName,
    'debit': debit,
    'credit': credit,
    'description': description,
  };

  factory JournalLine.fromMap(Map<String, dynamic> m) => JournalLine(
    accountId: m['accountId'] as String? ?? '',
    accountName: m['accountName'] as String? ?? '',
    debit: (m['debit'] as num?)?.toDouble() ?? 0.0,
    credit: (m['credit'] as num?)?.toDouble() ?? 0.0,
    description: m['description'] as String? ?? '',
  );
}

/// رأس القيد — journal_entries
class JournalEntry {
  final String id;
  String entryNumber;
  String date;
  String description;
  String sourceType; // invoice/payment/expense/manual...
  String? sourceId;
  List<JournalLine> lines;
  bool isPosted;
  String createdAt;

  JournalEntry({
    required this.id,
    required this.entryNumber,
    required this.date,
    required this.description,
    this.sourceType = 'manual',
    this.sourceId,
    List<JournalLine>? lines,
    this.isPosted = true,
    String? createdAt,
  }) : lines = lines ?? [],
       createdAt = createdAt ?? DateTime.now().toIso8601String();

  double get totalDebit => lines.fold(0.0, (s, l) => s + l.debit);
  double get totalCredit => lines.fold(0.0, (s, l) => s + l.credit);

  Map<String, dynamic> toMap() => {
    'id': id,
    'entryNumber': entryNumber,
    'date': date,
    'description': description,
    'sourceType': sourceType,
    'sourceId': sourceId,
    'lines': lines.map((l) => l.toMap()).toList(),
    'isPosted': isPosted,
    'createdAt': createdAt,
  };

  factory JournalEntry.fromMap(Map<String, dynamic> m) => JournalEntry(
    id: m['id'] as String,
    entryNumber: m['entryNumber'] as String? ?? '',
    date: m['date'] as String? ?? '',
    description: m['description'] as String? ?? '',
    sourceType: m['sourceType'] as String? ?? 'manual',
    sourceId: m['sourceId'] as String?,
    lines: (m['lines'] as List? ?? [])
        .map((e) => JournalLine.fromMap(Map<String, dynamic>.from(e)))
        .toList(),
    isPosted: m['isPosted'] as bool? ?? true,
    createdAt: m['createdAt'] as String?,
  );
}

/// جهة الاتصال (عميل/مورد) — contacts
class Contact {
  final String id;
  String code;
  String name;
  String contactType; // customer/supplier/both
  String? accountId;
  String phone;
  String phone2;
  String email;
  String address;
  String taxNumber;
  double creditLimit;
  double openingBalance;
  bool isActive;
  String notes;
  bool isDeleted;

  Contact({
    required this.id,
    this.code = '',
    required this.name,
    this.contactType = 'customer',
    this.accountId,
    this.phone = '',
    this.phone2 = '',
    this.email = '',
    this.address = '',
    this.taxNumber = '',
    this.creditLimit = 0.0,
    this.openingBalance = 0.0,
    this.isActive = true,
    this.notes = '',
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'code': code,
    'name': name,
    'contactType': contactType,
    'accountId': accountId,
    'phone': phone,
    'phone2': phone2,
    'email': email,
    'address': address,
    'taxNumber': taxNumber,
    'creditLimit': creditLimit,
    'openingBalance': openingBalance,
    'isActive': isActive,
    'notes': notes,
    'isDeleted': isDeleted,
  };

  factory Contact.fromMap(Map<String, dynamic> m) => Contact(
    id: m['id'] as String,
    code: m['code'] as String? ?? '',
    name: m['name'] as String? ?? '',
    contactType: m['contactType'] as String? ?? 'customer',
    accountId: m['accountId'] as String?,
    phone: m['phone'] as String? ?? '',
    phone2: m['phone2'] as String? ?? '',
    email: m['email'] as String? ?? '',
    address: m['address'] as String? ?? '',
    taxNumber: m['taxNumber'] as String? ?? '',
    creditLimit: (m['creditLimit'] as num?)?.toDouble() ?? 0.0,
    openingBalance: (m['openingBalance'] as num?)?.toDouble() ?? 0.0,
    isActive: m['isActive'] as bool? ?? true,
    notes: m['notes'] as String? ?? '',
    isDeleted: m['isDeleted'] as bool? ?? false,
  );
}

/// الصنف — items
class Item {
  final String id;
  String code;
  String barcode;
  String name;
  String nameEn;
  String? categoryId;
  String? baseUnitId;
  String itemType; // stock/service/kit
  String costMethod; // FIFO/LIFO/Average
  double purchasePrice;
  double salePrice;
  double minSalePrice;
  double reorderLevel;
  double openingQty;
  double openingCost;
  double taxRate;
  bool isActive;
  bool isTracked;
  bool hasExpiry;
  String imagePath;
  bool isDeleted;

  Item({
    required this.id,
    this.code = '',
    this.barcode = '',
    required this.name,
    this.nameEn = '',
    this.categoryId,
    this.baseUnitId,
    this.itemType = 'stock',
    this.costMethod = 'Average',
    this.purchasePrice = 0.0,
    this.salePrice = 0.0,
    this.minSalePrice = 0.0,
    this.reorderLevel = 0.0,
    this.openingQty = 0.0,
    this.openingCost = 0.0,
    this.taxRate = 0.0,
    this.isActive = true,
    this.isTracked = true,
    this.hasExpiry = false,
    this.imagePath = '',
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'code': code,
    'barcode': barcode,
    'name': name,
    'nameEn': nameEn,
    'categoryId': categoryId,
    'baseUnitId': baseUnitId,
    'itemType': itemType,
    'costMethod': costMethod,
    'purchasePrice': purchasePrice,
    'salePrice': salePrice,
    'minSalePrice': minSalePrice,
    'reorderLevel': reorderLevel,
    'openingQty': openingQty,
    'openingCost': openingCost,
    'taxRate': taxRate,
    'isActive': isActive,
    'isTracked': isTracked,
    'hasExpiry': hasExpiry,
    'imagePath': imagePath,
    'isDeleted': isDeleted,
  };

  factory Item.fromMap(Map<String, dynamic> m) => Item(
    id: m['id'] as String,
    code: m['code'] as String? ?? '',
    barcode: m['barcode'] as String? ?? '',
    name: m['name'] as String? ?? '',
    nameEn: m['nameEn'] as String? ?? '',
    categoryId: m['categoryId'] as String?,
    baseUnitId: m['baseUnitId'] as String?,
    itemType: m['itemType'] as String? ?? 'stock',
    costMethod: m['costMethod'] as String? ?? 'Average',
    purchasePrice: (m['purchasePrice'] as num?)?.toDouble() ?? 0.0,
    salePrice: (m['salePrice'] as num?)?.toDouble() ?? 0.0,
    minSalePrice: (m['minSalePrice'] as num?)?.toDouble() ?? 0.0,
    reorderLevel: (m['reorderLevel'] as num?)?.toDouble() ?? 0.0,
    openingQty: (m['openingQty'] as num?)?.toDouble() ?? 0.0,
    openingCost: (m['openingCost'] as num?)?.toDouble() ?? 0.0,
    taxRate: (m['taxRate'] as num?)?.toDouble() ?? 0.0,
    isActive: m['isActive'] as bool? ?? true,
    isTracked: m['isTracked'] as bool? ?? true,
    hasExpiry: m['hasExpiry'] as bool? ?? false,
    imagePath: m['imagePath'] as String? ?? '',
    isDeleted: m['isDeleted'] as bool? ?? false,
  );
}

/// سطر فاتورة
class InvoiceLine {
  String itemId;
  String itemName;
  double quantity;
  double unitPrice;
  double discount;
  double taxRate;
  double costPrice;
  String unitId;

  InvoiceLine({
    required this.itemId,
    required this.itemName,
    this.quantity = 1.0,
    this.unitPrice = 0.0,
    this.discount = 0.0,
    this.taxRate = 0.0,
    this.costPrice = 0.0,
    this.unitId = '',
  });

  double get lineSubtotal => quantity * unitPrice - discount;
  double get taxAmount => lineSubtotal * taxRate / 100;
  double get lineTotal => lineSubtotal + taxAmount;
  double get costTotal => quantity * costPrice;

  Map<String, dynamic> toMap() => {
    'itemId': itemId,
    'itemName': itemName,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'discount': discount,
    'taxRate': taxRate,
    'costPrice': costPrice,
    'unitId': unitId,
  };

  factory InvoiceLine.fromMap(Map<String, dynamic> m) => InvoiceLine(
    itemId: m['itemId'] as String? ?? '',
    itemName: m['itemName'] as String? ?? '',
    quantity: (m['quantity'] as num?)?.toDouble() ?? 1.0,
    unitPrice: (m['unitPrice'] as num?)?.toDouble() ?? 0.0,
    discount: (m['discount'] as num?)?.toDouble() ?? 0.0,
    taxRate: (m['taxRate'] as num?)?.toDouble() ?? 0.0,
    costPrice: (m['costPrice'] as num?)?.toDouble() ?? 0.0,
    unitId: m['unitId'] as String? ?? '',
  );
}

/// الفاتورة — sales_invoices / purchase_invoices / returns
class Invoice {
  final String id;
  String invoiceNumber;
  String invoiceType; // sale/purchase/sale_return/purchase_return
  String paymentType; // cash/credit
  String date;
  String dueDate;
  String? contactId;
  String contactName;
  String warehouseId;
  String? cashboxId;
  List<InvoiceLine> lines;
  double discountType; // 0=amount, 1=percent (kept simple)
  double discountValue;
  double discountAmount;
  double taxAmount;
  double shipping;
  double total;
  double paidAmount;
  double remaining;
  double exchangeRate;
  String? journalEntryId;
  String status; // draft/posted/cancelled
  String notes;
  String createdAt;
  String? originalInvoiceId; // للفواتير المرتجعة: الفاتورة الأصلية
  bool isDeleted;

  Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.invoiceType,
    this.paymentType = 'cash',
    required this.date,
    this.dueDate = '',
    this.contactId,
    this.contactName = '',
    this.warehouseId = '',
    this.cashboxId,
    List<InvoiceLine>? lines,
    this.discountType = 0.0,
    this.discountValue = 0.0,
    this.discountAmount = 0.0,
    this.taxAmount = 0.0,
    this.shipping = 0.0,
    this.total = 0.0,
    this.paidAmount = 0.0,
    this.remaining = 0.0,
    this.exchangeRate = 1.0,
    this.journalEntryId,
    this.status = 'posted',
    this.notes = '',
    this.originalInvoiceId,
    this.isDeleted = false,
    String? createdAt,
  }) : lines = lines ?? [],
       createdAt = createdAt ?? DateTime.now().toIso8601String();

  double get subtotal =>
      lines.fold(0.0, (s, l) => s + l.lineSubtotal);
  double get totalCost => lines.fold(0.0, (s, l) => s + l.costTotal);
  bool get isReturn =>
      invoiceType == 'sale_return' || invoiceType == 'purchase_return';
  bool get isSale =>
      invoiceType == 'sale' || invoiceType == 'sale_return';

  Map<String, dynamic> toMap() => {
    'id': id,
    'invoiceNumber': invoiceNumber,
    'invoiceType': invoiceType,
    'paymentType': paymentType,
    'date': date,
    'dueDate': dueDate,
    'contactId': contactId,
    'contactName': contactName,
    'warehouseId': warehouseId,
    'cashboxId': cashboxId,
    'lines': lines.map((l) => l.toMap()).toList(),
    'discountType': discountType,
    'discountValue': discountValue,
    'discountAmount': discountAmount,
    'taxAmount': taxAmount,
    'shipping': shipping,
    'total': total,
    'paidAmount': paidAmount,
    'remaining': remaining,
    'exchangeRate': exchangeRate,
    'journalEntryId': journalEntryId,
    'status': status,
    'notes': notes,
    'createdAt': createdAt,
    'originalInvoiceId': originalInvoiceId,
    'isDeleted': isDeleted,
  };

  factory Invoice.fromMap(Map<String, dynamic> m) => Invoice(
    id: m['id'] as String,
    invoiceNumber: m['invoiceNumber'] as String? ?? '',
    invoiceType: m['invoiceType'] as String? ?? 'sale',
    paymentType: m['paymentType'] as String? ?? 'cash',
    date: m['date'] as String? ?? '',
    dueDate: m['dueDate'] as String? ?? '',
    contactId: m['contactId'] as String?,
    contactName: m['contactName'] as String? ?? '',
    warehouseId: m['warehouseId'] as String? ?? '',
    cashboxId: m['cashboxId'] as String?,
    lines: (m['lines'] as List? ?? [])
        .map((e) => InvoiceLine.fromMap(Map<String, dynamic>.from(e)))
        .toList(),
    discountType: (m['discountType'] as num?)?.toDouble() ?? 0.0,
    discountValue: (m['discountValue'] as num?)?.toDouble() ?? 0.0,
    discountAmount: (m['discountAmount'] as num?)?.toDouble() ?? 0.0,
    taxAmount: (m['taxAmount'] as num?)?.toDouble() ?? 0.0,
    shipping: (m['shipping'] as num?)?.toDouble() ?? 0.0,
    total: (m['total'] as num?)?.toDouble() ?? 0.0,
    paidAmount: (m['paidAmount'] as num?)?.toDouble() ?? 0.0,
    remaining: (m['remaining'] as num?)?.toDouble() ?? 0.0,
    exchangeRate: (m['exchangeRate'] as num?)?.toDouble() ?? 1.0,
    journalEntryId: m['journalEntryId'] as String?,
    status: m['status'] as String? ?? 'posted',
    notes: m['notes'] as String? ?? '',
    originalInvoiceId: m['originalInvoiceId'] as String?,
    isDeleted: m['isDeleted'] as bool? ?? false,
    createdAt: m['createdAt'] as String?,
  );
}

/// سند القبض/الصرف — payments
class Payment {
  final String id;
  String paymentNumber;
  String paymentType; // receipt/payment
  String date;
  String? contactId;
  String contactName;
  String? cashboxId;
  double amount;
  String paymentMethod; // cash/check/card/transfer
  String description;
  String? journalEntryId;
  String createdAt;
  bool isDeleted;

  Payment({
    required this.id,
    required this.paymentNumber,
    required this.paymentType,
    required this.date,
    this.contactId,
    this.contactName = '',
    this.cashboxId,
    this.amount = 0.0,
    this.paymentMethod = 'cash',
    this.description = '',
    this.journalEntryId,
    this.isDeleted = false,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
    'id': id,
    'paymentNumber': paymentNumber,
    'paymentType': paymentType,
    'date': date,
    'contactId': contactId,
    'contactName': contactName,
    'cashboxId': cashboxId,
    'amount': amount,
    'paymentMethod': paymentMethod,
    'description': description,
    'journalEntryId': journalEntryId,
    'isDeleted': isDeleted,
    'createdAt': createdAt,
  };

  factory Payment.fromMap(Map<String, dynamic> m) => Payment(
    id: m['id'] as String,
    paymentNumber: m['paymentNumber'] as String? ?? '',
    paymentType: m['paymentType'] as String? ?? 'receipt',
    date: m['date'] as String? ?? '',
    contactId: m['contactId'] as String?,
    contactName: m['contactName'] as String? ?? '',
    cashboxId: m['cashboxId'] as String?,
    amount: (m['amount'] as num?)?.toDouble() ?? 0.0,
    paymentMethod: m['paymentMethod'] as String? ?? 'cash',
    description: m['description'] as String? ?? '',
    journalEntryId: m['journalEntryId'] as String?,
    isDeleted: m['isDeleted'] as bool? ?? false,
    createdAt: m['createdAt'] as String?,
  );
}

/// تخصيص دفعة على فاتورة — payment_allocations
class PaymentAllocation {
  final String id;
  String paymentId;
  String invoiceType; // sale/purchase/sale_return/purchase_return
  String invoiceId;
  String invoiceNumber;
  double amount;
  String date;

  PaymentAllocation({
    required this.id,
    required this.paymentId,
    required this.invoiceType,
    required this.invoiceId,
    this.invoiceNumber = '',
    required this.amount,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'paymentId': paymentId,
    'invoiceType': invoiceType,
    'invoiceId': invoiceId,
    'invoiceNumber': invoiceNumber,
    'amount': amount,
    'date': date,
  };

  factory PaymentAllocation.fromMap(Map<String, dynamic> m) => PaymentAllocation(
    id: m['id'] as String,
    paymentId: m['paymentId'] as String? ?? '',
    invoiceType: m['invoiceType'] as String? ?? 'sale',
    invoiceId: m['invoiceId'] as String? ?? '',
    invoiceNumber: m['invoiceNumber'] as String? ?? '',
    amount: (m['amount'] as num?)?.toDouble() ?? 0.0,
    date: m['date'] as String? ?? '',
  );
}

/// المصروف — expenses
class Expense {
  final String id;
  String expenseNumber;
  String date;
  String? categoryId;
  String categoryName;
  String accountId;
  String accountName;
  double amount;
  double taxAmount;
  double total;
  String? cashboxId;
  String? contactId;
  String description;
  String? journalEntryId;
  String createdAt;
  bool isDeleted;

  Expense({
    required this.id,
    this.expenseNumber = '',
    required this.date,
    this.categoryId,
    this.categoryName = '',
    this.accountId = '',
    this.accountName = '',
    this.amount = 0.0,
    this.taxAmount = 0.0,
    this.total = 0.0,
    this.cashboxId,
    this.contactId,
    this.description = '',
    this.journalEntryId,
    this.isDeleted = false,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
    'id': id,
    'expenseNumber': expenseNumber,
    'date': date,
    'categoryId': categoryId,
    'categoryName': categoryName,
    'accountId': accountId,
    'accountName': accountName,
    'amount': amount,
    'taxAmount': taxAmount,
    'total': total,
    'cashboxId': cashboxId,
    'contactId': contactId,
    'description': description,
    'journalEntryId': journalEntryId,
    'isDeleted': isDeleted,
    'createdAt': createdAt,
  };

  factory Expense.fromMap(Map<String, dynamic> m) => Expense(
    id: m['id'] as String,
    expenseNumber: m['expenseNumber'] as String? ?? '',
    date: m['date'] as String? ?? '',
    categoryId: m['categoryId'] as String?,
    categoryName: m['categoryName'] as String? ?? '',
    accountId: m['accountId'] as String? ?? '',
    accountName: m['accountName'] as String? ?? '',
    amount: (m['amount'] as num?)?.toDouble() ?? 0.0,
    taxAmount: (m['taxAmount'] as num?)?.toDouble() ?? 0.0,
    total: (m['total'] as num?)?.toDouble() ?? 0.0,
    cashboxId: m['cashboxId'] as String?,
    contactId: m['contactId'] as String?,
    description: m['description'] as String? ?? '',
    journalEntryId: m['journalEntryId'] as String?,
    isDeleted: m['isDeleted'] as bool? ?? false,
    createdAt: m['createdAt'] as String?,
  );
}

/// حركة المخزون — inventory_movements
class InventoryMovement {
  final String id;
  String itemId;
  String itemName;
  String warehouseId;
  String date;
  String movementType; // purchase/sale/return_in/return_out/transfer_in/transfer_out/adjustment/opening
  String referenceType;
  String? referenceId;
  double quantityIn;
  double quantityOut;
  double unitCost;
  double balanceAfter;
  String notes;
  String createdAt;

  InventoryMovement({
    required this.id,
    required this.itemId,
    this.itemName = '',
    this.warehouseId = 'wh_main',
    required this.date,
    required this.movementType,
    this.referenceType = '',
    this.referenceId,
    this.quantityIn = 0.0,
    this.quantityOut = 0.0,
    this.unitCost = 0.0,
    this.balanceAfter = 0.0,
    this.notes = '',
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  double get totalCost => (quantityIn + quantityOut) * unitCost;

  Map<String, dynamic> toMap() => {
    'id': id,
    'itemId': itemId,
    'itemName': itemName,
    'warehouseId': warehouseId,
    'date': date,
    'movementType': movementType,
    'referenceType': referenceType,
    'referenceId': referenceId,
    'quantityIn': quantityIn,
    'quantityOut': quantityOut,
    'unitCost': unitCost,
    'balanceAfter': balanceAfter,
    'notes': notes,
    'createdAt': createdAt,
  };

  factory InventoryMovement.fromMap(Map<String, dynamic> m) => InventoryMovement(
    id: m['id'] as String,
    itemId: m['itemId'] as String? ?? '',
    itemName: m['itemName'] as String? ?? '',
    warehouseId: m['warehouseId'] as String? ?? 'wh_main',
    date: m['date'] as String? ?? '',
    movementType: m['movementType'] as String? ?? 'adjustment',
    referenceType: m['referenceType'] as String? ?? '',
    referenceId: m['referenceId'] as String?,
    quantityIn: (m['quantityIn'] as num?)?.toDouble() ?? 0.0,
    quantityOut: (m['quantityOut'] as num?)?.toDouble() ?? 0.0,
    unitCost: (m['unitCost'] as num?)?.toDouble() ?? 0.0,
    balanceAfter: (m['balanceAfter'] as num?)?.toDouble() ?? 0.0,
    notes: m['notes'] as String? ?? '',
    createdAt: m['createdAt'] as String?,
  );
}

/// الصندوق — cashboxes
class Cashbox {
  final String id;
  String name;
  String code;
  String accountId;
  String accountName;
  double openingBalance;
  double currentBalance;
  bool isActive;

  Cashbox({
    required this.id,
    required this.name,
    this.code = '',
    this.accountId = '',
    this.accountName = '',
    this.openingBalance = 0.0,
    this.currentBalance = 0.0,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'code': code,
    'accountId': accountId,
    'accountName': accountName,
    'openingBalance': openingBalance,
    'currentBalance': currentBalance,
    'isActive': isActive,
  };

  factory Cashbox.fromMap(Map<String, dynamic> m) => Cashbox(
    id: m['id'] as String,
    name: m['name'] as String? ?? '',
    code: m['code'] as String? ?? '',
    accountId: m['accountId'] as String? ?? '',
    accountName: m['accountName'] as String? ?? '',
    openingBalance: (m['openingBalance'] as num?)?.toDouble() ?? 0.0,
    currentBalance: (m['currentBalance'] as num?)?.toDouble() ?? 0.0,
    isActive: m['isActive'] as bool? ?? true,
  );
}

/// المخزن — warehouses
class Warehouse {
  final String id;
  String name;
  String code;
  String location;
  bool isActive;
  bool allowNegative;

  Warehouse({
    required this.id,
    required this.name,
    this.code = '',
    this.location = '',
    this.isActive = true,
    this.allowNegative = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'code': code,
    'location': location,
    'isActive': isActive,
    'allowNegative': allowNegative,
  };

  factory Warehouse.fromMap(Map<String, dynamic> m) => Warehouse(
    id: m['id'] as String,
    name: m['name'] as String? ?? '',
    code: m['code'] as String? ?? '',
    location: m['location'] as String? ?? '',
    isActive: m['isActive'] as bool? ?? true,
    allowNegative: m['allowNegative'] as bool? ?? false,
  );
}

/// تصنيف الأصناف
class ItemCategory {
  final String id;
  String name;
  String? parentId;

  ItemCategory({required this.id, required this.name, this.parentId});

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'parentId': parentId,
  };

  factory ItemCategory.fromMap(Map<String, dynamic> m) => ItemCategory(
    id: m['id'] as String,
    name: m['name'] as String? ?? '',
    parentId: m['parentId'] as String?,
  );
}

/// تصنيف المصروفات
class ExpenseCategory {
  final String id;
  String name;
  String accountId;
  String accountName;

  ExpenseCategory({
    required this.id,
    required this.name,
    this.accountId = '',
    this.accountName = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'accountId': accountId,
    'accountName': accountName,
  };

  factory ExpenseCategory.fromMap(Map<String, dynamic> m) => ExpenseCategory(
    id: m['id'] as String,
    name: m['name'] as String? ?? '',
    accountId: m['accountId'] as String? ?? '',
    accountName: m['accountName'] as String? ?? '',
  );
}

/// رصيد المخزون
class InventoryBalance {
  String itemId;
  String warehouseId;
  double quantity;
  double avgCost;

  InventoryBalance({
    required this.itemId,
    required this.warehouseId,
    this.quantity = 0.0,
    this.avgCost = 0.0,
  });

  String get key => '$itemId::$warehouseId';

  Map<String, dynamic> toMap() => {
    'itemId': itemId,
    'warehouseId': warehouseId,
    'quantity': quantity,
    'avgCost': avgCost,
  };

  factory InventoryBalance.fromMap(Map<String, dynamic> m) => InventoryBalance(
    itemId: m['itemId'] as String? ?? '',
    warehouseId: m['warehouseId'] as String? ?? '',
    quantity: (m['quantity'] as num?)?.toDouble() ?? 0.0,
    avgCost: (m['avgCost'] as num?)?.toDouble() ?? 0.0,
  );
}

// ============================================================================
// وحدة الموارد البشرية (HR)
// ============================================================================

/// الموظف — employees
class Employee {
  final String id;
  String code;
  String name;
  String jobTitle;
  String department;
  String phone;
  String email;
  String nationalId;
  String hireDate;
  double basicSalary;
  double allowances; // بدلات
  double deductions; // خصومات ثابتة
  String salaryAccountId;
  bool isActive;
  String notes;

  Employee({
    required this.id,
    this.code = '',
    required this.name,
    this.jobTitle = '',
    this.department = '',
    this.phone = '',
    this.email = '',
    this.nationalId = '',
    this.hireDate = '',
    this.basicSalary = 0.0,
    this.allowances = 0.0,
    this.deductions = 0.0,
    this.salaryAccountId = '',
    this.isActive = true,
    this.notes = '',
  });

  double get netSalary => basicSalary + allowances - deductions;

  Map<String, dynamic> toMap() => {
    'id': id,
    'code': code,
    'name': name,
    'jobTitle': jobTitle,
    'department': department,
    'phone': phone,
    'email': email,
    'nationalId': nationalId,
    'hireDate': hireDate,
    'basicSalary': basicSalary,
    'allowances': allowances,
    'deductions': deductions,
    'salaryAccountId': salaryAccountId,
    'isActive': isActive,
    'notes': notes,
  };

  factory Employee.fromMap(Map<String, dynamic> m) => Employee(
    id: m['id'] as String,
    code: m['code'] as String? ?? '',
    name: m['name'] as String? ?? '',
    jobTitle: m['jobTitle'] as String? ?? '',
    department: m['department'] as String? ?? '',
    phone: m['phone'] as String? ?? '',
    email: m['email'] as String? ?? '',
    nationalId: m['nationalId'] as String? ?? '',
    hireDate: m['hireDate'] as String? ?? '',
    basicSalary: (m['basicSalary'] as num?)?.toDouble() ?? 0.0,
    allowances: (m['allowances'] as num?)?.toDouble() ?? 0.0,
    deductions: (m['deductions'] as num?)?.toDouble() ?? 0.0,
    salaryAccountId: m['salaryAccountId'] as String? ?? '',
    isActive: m['isActive'] as bool? ?? true,
    notes: m['notes'] as String? ?? '',
  );
}

/// سجل الحضور — attendance
class Attendance {
  final String id;
  String employeeId;
  String employeeName;
  String date;
  String status; // present/absent/late/leave/holiday
  double overtimeHours;
  String notes;

  Attendance({
    required this.id,
    required this.employeeId,
    this.employeeName = '',
    required this.date,
    this.status = 'present',
    this.overtimeHours = 0.0,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'employeeId': employeeId,
    'employeeName': employeeName,
    'date': date,
    'status': status,
    'overtimeHours': overtimeHours,
    'notes': notes,
  };

  factory Attendance.fromMap(Map<String, dynamic> m) => Attendance(
    id: m['id'] as String,
    employeeId: m['employeeId'] as String? ?? '',
    employeeName: m['employeeName'] as String? ?? '',
    date: m['date'] as String? ?? '',
    status: m['status'] as String? ?? 'present',
    overtimeHours: (m['overtimeHours'] as num?)?.toDouble() ?? 0.0,
    notes: m['notes'] as String? ?? '',
  );
}

/// مسير راتب — payroll
class PayrollRecord {
  final String id;
  String payrollNumber;
  String employeeId;
  String employeeName;
  String period; // 2025-06
  String date;
  double basicSalary;
  double allowances;
  double overtimeAmount;
  double deductions;
  double advanceDeduction; // خصم سلفة
  double netPay;
  String paymentMethod; // cash
  String? cashboxId;
  String? journalEntryId;
  String notes;
  String createdAt;

  PayrollRecord({
    required this.id,
    this.payrollNumber = '',
    required this.employeeId,
    this.employeeName = '',
    required this.period,
    required this.date,
    this.basicSalary = 0.0,
    this.allowances = 0.0,
    this.overtimeAmount = 0.0,
    this.deductions = 0.0,
    this.advanceDeduction = 0.0,
    this.netPay = 0.0,
    this.paymentMethod = 'cash',
    this.cashboxId,
    this.journalEntryId,
    this.notes = '',
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
    'id': id,
    'payrollNumber': payrollNumber,
    'employeeId': employeeId,
    'employeeName': employeeName,
    'period': period,
    'date': date,
    'basicSalary': basicSalary,
    'allowances': allowances,
    'overtimeAmount': overtimeAmount,
    'deductions': deductions,
    'advanceDeduction': advanceDeduction,
    'netPay': netPay,
    'paymentMethod': paymentMethod,
    'cashboxId': cashboxId,
    'journalEntryId': journalEntryId,
    'notes': notes,
    'createdAt': createdAt,
  };

  factory PayrollRecord.fromMap(Map<String, dynamic> m) => PayrollRecord(
    id: m['id'] as String,
    payrollNumber: m['payrollNumber'] as String? ?? '',
    employeeId: m['employeeId'] as String? ?? '',
    employeeName: m['employeeName'] as String? ?? '',
    period: m['period'] as String? ?? '',
    date: m['date'] as String? ?? '',
    basicSalary: (m['basicSalary'] as num?)?.toDouble() ?? 0.0,
    allowances: (m['allowances'] as num?)?.toDouble() ?? 0.0,
    overtimeAmount: (m['overtimeAmount'] as num?)?.toDouble() ?? 0.0,
    deductions: (m['deductions'] as num?)?.toDouble() ?? 0.0,
    advanceDeduction: (m['advanceDeduction'] as num?)?.toDouble() ?? 0.0,
    netPay: (m['netPay'] as num?)?.toDouble() ?? 0.0,
    paymentMethod: m['paymentMethod'] as String? ?? 'cash',
    cashboxId: m['cashboxId'] as String?,
    journalEntryId: m['journalEntryId'] as String?,
    notes: m['notes'] as String? ?? '',
    createdAt: m['createdAt'] as String?,
  );
}

// ============================================================================
// تعدد العملات
// ============================================================================

/// عملة — currencies
class Currency {
  final String id;
  String code; // USD, SAR, EGP
  String name;
  String symbol;
  double rate; // سعر الصرف مقابل العملة الأساسية
  bool isBase;
  bool isActive;

  Currency({
    required this.id,
    required this.code,
    required this.name,
    this.symbol = '',
    this.rate = 1.0,
    this.isBase = false,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'code': code,
    'name': name,
    'symbol': symbol,
    'rate': rate,
    'isBase': isBase,
    'isActive': isActive,
  };

  factory Currency.fromMap(Map<String, dynamic> m) => Currency(
    id: m['id'] as String,
    code: m['code'] as String? ?? '',
    name: m['name'] as String? ?? '',
    symbol: m['symbol'] as String? ?? '',
    rate: (m['rate'] as num?)?.toDouble() ?? 1.0,
    isBase: m['isBase'] as bool? ?? false,
    isActive: m['isActive'] as bool? ?? true,
  );
}

// ============================================================================
// الأصول الثابتة والإهلاك
// ============================================================================

/// أصل ثابت — fixed_assets
class FixedAsset {
  final String id;
  String code;
  String name;
  String category; // أرض/مبنى/سيارة/أثاث/كمبيوتر/أخرى
  String purchaseDate;
  double cost; // التكلفة
  double salvageValue; // القيمة التخريدية
  int usefulLifeYears; // العمر الإنتاجي بالسنوات
  double accumulatedDepreciation; // مجمع الإهلاك
  String assetAccountCode; // حساب الأصل
  String method; // straight_line / declining
  String status; // active/disposed
  double disposalAmount; // قيمة البيع عند التخريد
  String disposalDate;
  String notes;

  FixedAsset({
    required this.id,
    this.code = '',
    required this.name,
    this.category = 'أخرى',
    required this.purchaseDate,
    required this.cost,
    this.salvageValue = 0.0,
    this.usefulLifeYears = 5,
    this.accumulatedDepreciation = 0.0,
    this.assetAccountCode = '',
    this.method = 'straight_line',
    this.status = 'active',
    this.disposalAmount = 0.0,
    this.disposalDate = '',
    this.notes = '',
  });

  /// القيمة الدفترية = التكلفة - مجمع الإهلاك
  double get bookValue => cost - accumulatedDepreciation;

  /// القابل للإهلاك = التكلفة - القيمة التخريدية
  double get depreciableAmount => cost - salvageValue;

  /// قسط الإهلاك السنوي (القسط الثابت)
  double get annualDepreciation {
    if (usefulLifeYears <= 0) return 0;
    return depreciableAmount / usefulLifeYears;
  }

  /// قسط الإهلاك الشهري
  double get monthlyDepreciation => annualDepreciation / 12;

  /// هل انتهى الإهلاك؟
  bool get isFullyDepreciated =>
      accumulatedDepreciation >= depreciableAmount - 0.001;

  Map<String, dynamic> toMap() => {
    'id': id,
    'code': code,
    'name': name,
    'category': category,
    'purchaseDate': purchaseDate,
    'cost': cost,
    'salvageValue': salvageValue,
    'usefulLifeYears': usefulLifeYears,
    'accumulatedDepreciation': accumulatedDepreciation,
    'assetAccountCode': assetAccountCode,
    'method': method,
    'status': status,
    'disposalAmount': disposalAmount,
    'disposalDate': disposalDate,
    'notes': notes,
  };

  factory FixedAsset.fromMap(Map<String, dynamic> m) => FixedAsset(
    id: m['id'] as String,
    code: m['code'] as String? ?? '',
    name: m['name'] as String? ?? '',
    category: m['category'] as String? ?? 'أخرى',
    purchaseDate: m['purchaseDate'] as String? ?? '',
    cost: (m['cost'] as num?)?.toDouble() ?? 0.0,
    salvageValue: (m['salvageValue'] as num?)?.toDouble() ?? 0.0,
    usefulLifeYears: (m['usefulLifeYears'] as num?)?.toInt() ?? 0,
    accumulatedDepreciation:
        (m['accumulatedDepreciation'] as num?)?.toDouble() ?? 0.0,
    assetAccountCode: m['assetAccountCode'] as String? ?? '',
    method: m['method'] as String? ?? 'straight_line',
    status: m['status'] as String? ?? 'active',
    disposalAmount: (m['disposalAmount'] as num?)?.toDouble() ?? 0.0,
    disposalDate: m['disposalDate'] as String? ?? '',
    notes: m['notes'] as String? ?? '',
  );
}
