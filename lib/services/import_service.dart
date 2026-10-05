// ============================================================================
// خدمة الاستيراد — Excel (.xlsx) و CSV
// تعمل على الويب والأندرويد (Offline-First)
// ============================================================================
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

import '../data/app_database.dart';
import '../models/models.dart';

class ImportResult {
  final int success;
  final int failed;
  final List<String> errors;

  ImportResult({
    required this.success,
    required this.failed,
    required this.errors,
  });

  bool get hasErrors => errors.isNotEmpty;
}

class ImportService {
  // ---------------------------- قراءة الملف ----------------------------
  /// تحويل بايتات الملف إلى صفوف نصية `List<List<String>>`
  static List<List<String>> parseBytes(String filename, Uint8List bytes) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.csv')) {
      return _parseCsv(bytes);
    }
    // xlsx
    return _parseExcel(bytes);
  }

  static List<List<String>> _parseCsv(Uint8List bytes) {
    final content = String.fromCharCodes(bytes);
    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(content.replaceAll('\r\n', '\n'));
    return rows.map((r) => r.map((c) => c.toString().trim()).toList()).toList();
  }

  static List<List<String>> _parseExcel(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final result = <List<String>>[];
    for (final table in excel.tables.keys) {
      final sheet = excel.tables[table];
      if (sheet == null) continue;
      for (final row in sheet.rows) {
        if (row.length == 1 && (row[0]?.value == null)) continue;
        result.add(row.map((cell) => _cellText(cell?.value)).toList());
      }
      break; // أول ورقة فقط
    }
    return result;
  }

  static String _cellText(dynamic v) {
    if (v == null) return '';
    if (v is TextCellValue) return v.value.text ?? '';
    if (v is IntCellValue) return v.value.toString();
    if (v is DoubleCellValue) return v.value.toString();
    if (v is BoolCellValue) return v.value.toString();
    if (v is DateCellValue) {
      final d = v.asDateTimeLocal();
      return d.toIso8601String().substring(0, 10);
    }
    return v.toString();
  }

  // ---------------------------- استيراد الأصناف ----------------------------
  /// الأعمدة المتوقعة: كود | اسم | باركود | سعر شراء | سعر بيع | حد الطلب
  static Future<ImportResult> importItems(List<List<String>> rows) async {
    int ok = 0;
    final errors = <String>[];
    // تخطي صف العنوان
    for (var i = 1; i < rows.length; i++) {
      final r = rows[i];
      if (r.isEmpty || r.every((c) => c.trim().isEmpty)) continue;
      try {
        final name = _at(r, 1);
        if (name.isEmpty) {
          errors.add('صف ${i + 1}: الاسم مطلوب');
          continue;
        }
        final it = Item(
          id: AppDatabase.newId(),
          code: _at(r, 0),
          name: name,
          barcode: _at(r, 2),
          purchasePrice: _num(_at(r, 3)),
          salePrice: _num(_at(r, 4)),
          reorderLevel: _num(_at(r, 5)),
        );
        await AppDatabase.saveItem(it);
        ok++;
      } catch (e) {
        errors.add('صف ${i + 1}: $e');
      }
    }
    return ImportResult(
      success: ok,
      failed: rows.length - 1 - ok,
      errors: errors,
    );
  }

  // ---------------------------- استيراد جهات الاتصال ----------------------------
  /// الأعمدة: كود | اسم | النوع(عميل/مورد) | هاتف | بريد | الرقم الضريبي
  static Future<ImportResult> importContacts(List<List<String>> rows) async {
    int ok = 0;
    final errors = <String>[];
    for (var i = 1; i < rows.length; i++) {
      final r = rows[i];
      if (r.isEmpty || r.every((c) => c.trim().isEmpty)) continue;
      try {
        final name = _at(r, 1);
        if (name.isEmpty) {
          errors.add('صف ${i + 1}: الاسم مطلوب');
          continue;
        }
        final typeRaw = _at(r, 2);
        final type = typeRaw.contains('مورد')
            ? 'supplier'
            : (typeRaw.contains('كلاهما') ? 'both' : 'customer');
        final c = Contact(
          id: AppDatabase.newId(),
          code: _at(r, 0),
          name: name,
          contactType: type,
          phone: _at(r, 3),
          email: _at(r, 4),
          taxNumber: _at(r, 5),
        );
        await AppDatabase.saveContact(c);
        ok++;
      } catch (e) {
        errors.add('صف ${i + 1}: $e');
      }
    }
    return ImportResult(
      success: ok,
      failed: rows.length - 1 - ok,
      errors: errors,
    );
  }

  // ---------------------------- قوالب CSV للتنزيل ----------------------------
  static String itemsTemplateCsv() => const ListToCsvConverter().convert([
    ['الكود', 'الاسم', 'الباركود', 'سعر الشراء', 'سعر البيع', 'حد الطلب'],
    ['IT-001', 'قميص قطني', '1234567890', '40', '70', '10'],
    ['IT-002', 'حذاء رياضي', '1234567891', '120', '200', '5'],
  ]);

  static String contactsTemplateCsv() => const ListToCsvConverter().convert([
    ['الكود', 'الاسم', 'النوع', 'الهاتف', 'البريد', 'الرقم الضريبي'],
    [
      'C-001',
      'أحمد علي',
      'عميل',
      '0500000000',
      'a@mail.com',
      '300000000000003',
    ],
    ['S-001', 'شركة التوريدات', 'مورد', '0511111111', 'b@mail.com', ''],
  ]);

  // ---------------------------- أدوات مساعدة ----------------------------
  static String _at(List<String> r, int i) => i < r.length ? r[i].trim() : '';

  static double _num(String s) =>
      double.tryParse(s.replaceAll(',', '').trim()) ?? 0.0;
}
