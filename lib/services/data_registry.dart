// ============================================================================
// سجل الكيانات — تعريف موحّد للاستيراد/التصدير لكل أجزاء النظام
// كل كيان: مفاتيح الأعمدة (عربي) + تصدير الصفوف + استيراد صف
// ============================================================================
import 'dart:typed_data';

import '../data/app_database.dart';
import '../models/models.dart';
import 'excel_service.dart';
import 'import_service.dart';

class EntityField {
  final String key; // المفتاح الداخلي
  final String label; // العنوان العربي (في ملف Excel)
  final bool required;
  const EntityField(this.key, this.label, {this.required = false});
}

class DataEntity {
  final String id; // معرّف داخلي
  final String title; // الاسم العربي
  final List<EntityField> fields;
  final List<List<String>> Function() exportRows;

  /// يستورد صفاً واحداً (خريطة: key -> value). يُرجع رسالة خطأ أو null.
  final Future<String?> Function(Map<String, String> row) importRow;

  const DataEntity({
    required this.id,
    required this.title,
    required this.fields,
    required this.exportRows,
    required this.importRow,
  });

  List<String> get headers => fields.map((f) => f.label).toList();
}

class DataRegistry {
  static String _at(Map<String, String> m, String k) => (m[k] ?? '').trim();
  static double _num(String s) =>
      double.tryParse(s.replaceAll(',', '').trim()) ?? 0.0;

  // ---------------------------- قائمة الكيانات ----------------------------
  static final List<DataEntity> entities = [
    // العملاء والموردون
    DataEntity(
      id: 'contacts',
      title: 'العملاء والموردون',
      fields: const [
        EntityField('code', 'الكود'),
        EntityField('name', 'الاسم', required: true),
        EntityField('type', 'النوع'),
        EntityField('phone', 'الهاتف'),
        EntityField('email', 'البريد'),
        EntityField('address', 'العنوان'),
        EntityField('tax', 'الرقم الضريبي'),
        EntityField('credit', 'حد الائتمان'),
        EntityField('opening', 'الرصيد الافتتاحي'),
      ],
      exportRows: () => [
        for (final c in AppDatabase.contacts)
          if (!c.isDeleted)
            [
              c.code,
              c.name,
              _contactTypeLabel(c.contactType),
              c.phone,
              c.email,
              c.address,
              c.taxNumber,
              c.creditLimit.toString(),
              c.openingBalance.toString(),
            ],
      ],
      importRow: (r) async {
        final name = _at(r, 'name');
        if (name.isEmpty) return 'الاسم مطلوب';
        final typeRaw = _at(r, 'type');
        final type = typeRaw.contains('مورد') || typeRaw == 'supplier'
            ? (typeRaw.contains('كلاهما') || typeRaw.contains('both')
                  ? 'both'
                  : 'supplier')
            : 'customer';
        final c = Contact(
          id: AppDatabase.newId(),
          code: _at(r, 'code'),
          name: name,
          contactType: type,
          phone: _at(r, 'phone'),
          email: _at(r, 'email'),
          address: _at(r, 'address'),
          taxNumber: _at(r, 'tax'),
          creditLimit: _num(_at(r, 'credit')),
          openingBalance: _num(_at(r, 'opening')),
        );
        await AppDatabase.saveContact(c);
        return null;
      },
    ),

    // الأصناف
    DataEntity(
      id: 'items',
      title: 'الأصناف',
      fields: const [
        EntityField('code', 'الكود'),
        EntityField('name', 'الاسم', required: true),
        EntityField('barcode', 'الباركود'),
        EntityField('category', 'التصنيف'),
        EntityField('purchase', 'سعر الشراء'),
        EntityField('sale', 'سعر البيع'),
        EntityField('reorder', 'حد الطلب'),
        EntityField('opening', 'الكمية الافتتاحية'),
        EntityField('tax', 'نسبة الضريبة'),
      ],
      exportRows: () => [
        for (final i in AppDatabase.items)
          if (!i.isDeleted)
            [
              i.code,
              i.name,
              i.barcode,
              _categoryName(i.categoryId),
              i.purchasePrice.toString(),
              i.salePrice.toString(),
              i.reorderLevel.toString(),
              i.openingQty.toString(),
              i.taxRate.toString(),
            ],
      ],
      importRow: (r) async {
        final name = _at(r, 'name');
        if (name.isEmpty) return 'الاسم مطلوب';
        final it = Item(
          id: AppDatabase.newId(),
          code: _at(r, 'code'),
          name: name,
          barcode: _at(r, 'barcode'),
          purchasePrice: _num(_at(r, 'purchase')),
          salePrice: _num(_at(r, 'sale')),
          reorderLevel: _num(_at(r, 'reorder')),
          openingQty: _num(_at(r, 'opening')),
          taxRate: _num(_at(r, 'tax')),
        );
        await AppDatabase.saveItem(it);
        return null;
      },
    ),

    // المخازن
    DataEntity(
      id: 'warehouses',
      title: 'المخازن',
      fields: const [
        EntityField('code', 'الكود'),
        EntityField('name', 'الاسم', required: true),
        EntityField('location', 'الموقع'),
      ],
      exportRows: () => [
        for (final w in AppDatabase.warehouses) [w.code, w.name, w.location],
      ],
      importRow: (r) async {
        final name = _at(r, 'name');
        if (name.isEmpty) return 'الاسم مطلوب';
        await AppDatabase.saveWarehouse(
          Warehouse(
            id: AppDatabase.newId(),
            name: name,
            code: _at(r, 'code'),
            location: _at(r, 'location'),
          ),
        );
        return null;
      },
    ),

    // الصناديق
    DataEntity(
      id: 'cashboxes',
      title: 'الصناديق',
      fields: const [
        EntityField('code', 'الكود'),
        EntityField('name', 'الاسم', required: true),
        EntityField('opening', 'الرصيد الافتتاحي'),
      ],
      exportRows: () => [
        for (final c in AppDatabase.cashboxes)
          [c.code, c.name, c.openingBalance.toString()],
      ],
      importRow: (r) async {
        final name = _at(r, 'name');
        if (name.isEmpty) return 'الاسم مطلوب';
        await AppDatabase.saveCashbox(
          Cashbox(
            id: AppDatabase.newId(),
            name: name,
            code: _at(r, 'code'),
            openingBalance: _num(_at(r, 'opening')),
          ),
        );
        return null;
      },
    ),

    // دليل الحسابات
    DataEntity(
      id: 'accounts',
      title: 'دليل الحسابات',
      fields: const [
        EntityField('code', 'الكود', required: true),
        EntityField('name', 'الاسم', required: true),
        EntityField('type', 'النوع'),
        EntityField('nature', 'الطبيعة'),
        EntityField('parent', 'كود الحساب الأب'),
        EntityField('opening', 'الرصيد الافتتاحي'),
      ],
      exportRows: () => [
        for (final a in AppDatabase.accounts)
          [
            a.code,
            a.name,
            _accTypeLabel(a.accountType),
            a.accountNature == 'debit' ? 'مدين' : 'دائن',
            _parentCode(a.parentId),
            a.openingBalance.toString(),
          ],
      ],
      importRow: (r) async {
        final code = _at(r, 'code');
        final name = _at(r, 'name');
        if (code.isEmpty) return 'الكود مطلوب';
        if (name.isEmpty) return 'الاسم مطلوب';
        final parentCode = _at(r, 'parent');
        final parent = parentCode.isEmpty
            ? null
            : AppDatabase.accountByCode(parentCode);
        final typeRaw = _at(r, 'type');
        final type = _accTypeFromLabel(typeRaw);
        final nature = _at(r, 'nature').contains('دائن') ? 'credit' : 'debit';
        await AppDatabase.saveAccount(
          Account(
            id: AppDatabase.newId(),
            code: code,
            name: name,
            accountType: type,
            accountNature: nature,
            parentId: parent?.id,
            level: parent == null ? 1 : parent.level + 1,
            isLeaf: true,
            openingBalance: _num(_at(r, 'opening')),
          ),
        );
        return null;
      },
    ),

    // الموظفون
    DataEntity(
      id: 'employees',
      title: 'الموظفون',
      fields: const [
        EntityField('code', 'الكود'),
        EntityField('name', 'الاسم', required: true),
        EntityField('job', 'الوظيفة'),
        EntityField('department', 'القسم'),
        EntityField('phone', 'الهاتف'),
        EntityField('email', 'البريد'),
        EntityField('national', 'الرقم الوطني'),
        EntityField('hire', 'تاريخ التعيين'),
        EntityField('basic', 'الراتب الأساسي'),
        EntityField('allowances', 'البدلات'),
        EntityField('deductions', 'الخصومات'),
      ],
      exportRows: () => [
        for (final e in AppDatabase.employees)
          [
            e.code,
            e.name,
            e.jobTitle,
            e.department,
            e.phone,
            e.email,
            e.nationalId,
            e.hireDate,
            e.basicSalary.toString(),
            e.allowances.toString(),
            e.deductions.toString(),
          ],
      ],
      importRow: (r) async {
        final name = _at(r, 'name');
        if (name.isEmpty) return 'الاسم مطلوب';
        await AppDatabase.saveEmployee(
          Employee(
            id: AppDatabase.newId(),
            code: _at(r, 'code'),
            name: name,
            jobTitle: _at(r, 'job'),
            department: _at(r, 'department'),
            phone: _at(r, 'phone'),
            email: _at(r, 'email'),
            nationalId: _at(r, 'national'),
            hireDate: _at(r, 'hire'),
            basicSalary: _num(_at(r, 'basic')),
            allowances: _num(_at(r, 'allowances')),
            deductions: _num(_at(r, 'deductions')),
          ),
        );
        return null;
      },
    ),

    // الفروع
    DataEntity(
      id: 'branches',
      title: 'الفروع',
      fields: const [
        EntityField('code', 'الكود'),
        EntityField('name', 'الاسم', required: true),
        EntityField('phone', 'الهاتف'),
        EntityField('email', 'البريد'),
        EntityField('address', 'العنوان'),
      ],
      exportRows: () => [
        for (final b in AppDatabase.branches)
          [b.code, b.name, b.phone, b.email, b.address],
      ],
      importRow: (r) async {
        final name = _at(r, 'name');
        if (name.isEmpty) return 'الاسم مطلوب';
        await AppDatabase.saveBranch(
          Branch(
            id: AppDatabase.newId(),
            code: _at(r, 'code'),
            name: name,
            phone: _at(r, 'phone'),
            email: _at(r, 'email'),
            address: _at(r, 'address'),
          ),
        );
        return null;
      },
    ),

    // وحدات القياس
    DataEntity(
      id: 'units',
      title: 'وحدات القياس',
      fields: const [
        EntityField('code', 'الكود'),
        EntityField('name', 'الاسم', required: true),
        EntityField('symbol', 'الرمز'),
        EntityField('factor', 'معامل التحويل'),
      ],
      exportRows: () => [
        for (final u in AppDatabase.units)
          [u.code, u.name, u.symbol, u.conversionFactor.toString()],
      ],
      importRow: (r) async {
        final name = _at(r, 'name');
        if (name.isEmpty) return 'الاسم مطلوب';
        final f = _num(_at(r, 'factor'));
        await AppDatabase.saveUnit(
          Unit(
            id: AppDatabase.newId(),
            code: _at(r, 'code'),
            name: name,
            symbol: _at(r, 'symbol'),
            conversionFactor: f == 0 ? 1.0 : f,
          ),
        );
        return null;
      },
    ),
  ];

  static DataEntity? byId(String id) {
    for (final e in entities) {
      if (e.id == id) return e;
    }
    return null;
  }

  // ---------------------------- التصدير ----------------------------
  static List<String> exportCsv(String entityId) {
    final e = byId(entityId);
    if (e == null) return [];
    final csv = StringBuffer();
    csv.writeln(e.headers.join(','));
    for (final r in e.exportRows()) {
      csv.writeln(r.map(_csvEsc).join(','));
    }
    return [csv.toString()];
  }

  static Uint8List exportExcel(String entityId) {
    final e = byId(entityId)!;
    return ExcelService.build(
      headers: e.headers,
      rows: e.exportRows(),
      sheetName: e.title,
    );
  }

  // ---------------------------- الاستيراد ----------------------------
  static Future<ImportResult> importFromRows(
    String entityId,
    List<List<String>> rows,
  ) async {
    final e = byId(entityId);
    if (e == null) {
      return ImportResult(success: 0, failed: 0, errors: ['كيان غير معروف']);
    }
    // ربط عناوين الملف بحقول الكيان (بالترتيب)
    int ok = 0;
    final errors = <String>[];
    for (var i = 1; i < rows.length; i++) {
      final r = rows[i];
      if (r.isEmpty || r.every((c) => c.trim().isEmpty)) continue;
      final map = <String, String>{};
      for (var j = 0; j < e.fields.length; j++) {
        map[e.fields[j].key] = j < r.length ? r[j] : '';
      }
      try {
        final err = await e.importRow(map);
        if (err != null) {
          errors.add('صف ${i + 1}: $err');
        } else {
          ok++;
        }
      } catch (ex) {
        errors.add('صف ${i + 1}: $ex');
      }
    }
    return ImportResult(
      success: ok,
      failed: rows.length - 1 - ok,
      errors: errors,
    );
  }

  // ---------------------------- أدوات مساعدة ----------------------------
  static String _csvEsc(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  static String _contactTypeLabel(String t) => switch (t) {
    'supplier' => 'مورد',
    'both' => 'عميل ومورد',
    _ => 'عميل',
  };

  static String _accTypeLabel(String t) => switch (t) {
    'asset' => 'أصول',
    'liability' => 'خصوم',
    'equity' => 'حقوق ملكية',
    'revenue' => 'إيرادات',
    _ => 'مصروفات',
  };

  static String _accTypeFromLabel(String label) {
    if (label.contains('خصوم')) return 'liability';
    if (label.contains('حقوق')) return 'equity';
    if (label.contains('إيراد')) return 'revenue';
    if (label.contains('مصروف')) return 'expense';
    return 'asset';
  }

  static String _categoryName(String? id) {
    if (id == null) return '';
    try {
      return AppDatabase.categories.firstWhere((c) => c.id == id).name;
    } catch (_) {
      return '';
    }
  }

  static String _parentCode(String? parentId) {
    if (parentId == null) return '';
    return AppDatabase.accountById(parentId)?.code ?? '';
  }
}
