// ============================================================================
// خدمة Excel الموحّدة — كتابة وقراءة ملفات .xlsx
// تُستخدم لتصدير/استيراد كل أجزاء النظام (عملاء/موردون/أصناف/مخازن/صناديق/حسابات...)
// ============================================================================
import 'dart:typed_data';
import 'package:excel/excel.dart';

class ExcelService {
  /// بناء ملف Excel من عناوين + صفوف ويُرجع البايتات
  static Uint8List build({
    required List<String> headers,
    required List<List<String>> rows,
    String sheetName = 'Sheet1',
  }) {
    final excel = Excel.createExcel();
    // إعادة تسمية الورقة الافتراضية
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != sheetName) {
      excel.rename(defaultSheet, sheetName);
    }
    final sheet = excel[sheetName];

    // صف العناوين (منسّق)
    final headerRow = <CellValue?>[
      for (final h in headers) TextCellValue(h),
    ];
    sheet.appendRow(headerRow);

    // الصفوف
    for (final r in rows) {
      sheet.appendRow([
        for (final c in r) _cell(c),
      ]);
    }
    final bytes = excel.encode();
    return Uint8List.fromList(bytes ?? []);
  }

  /// تحويل نص إلى خلية (رقم إن أمكن)
  static CellValue _cell(String v) {
    final t = v.trim();
    if (t.isEmpty) return TextCellValue('');
    final asInt = int.tryParse(t);
    if (asInt != null) return IntCellValue(asInt);
    final asDbl = double.tryParse(t.replaceAll(',', ''));
    if (asDbl != null) return DoubleCellValue(asDbl);
    return TextCellValue(t);
  }

  /// قراءة ملف Excel إلى صفوف نصية
  static List<List<String>> parse(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final result = <List<String>>[];
    for (final name in excel.tables.keys) {
      final sheet = excel.tables[name];
      if (sheet == null) continue;
      for (final row in sheet.rows) {
        if (row.isEmpty) continue;
        final values = row.map((c) => _text(c?.value)).toList();
        if (values.every((v) => v.trim().isEmpty)) continue;
        result.add(values);
      }
      break; // أول ورقة فقط
    }
    return result;
  }

  static String _text(dynamic v) {
    if (v == null) return '';
    if (v is TextCellValue) return v.value.text ?? '';
    if (v is IntCellValue) return v.value.toString();
    if (v is DoubleCellValue) {
      final d = v.value;
      return d == d.roundToDouble() ? d.toInt().toString() : d.toString();
    }
    if (v is BoolCellValue) return v.value.toString();
    if (v is DateCellValue) {
      try {
        return v.asDateTimeLocal().toIso8601String().substring(0, 10);
      } catch (_) {
        return '';
      }
    }
    return v.toString();
  }
}
