// ============================================================================
// خدمة التصدير — CSV / Excel لكل التقارير
// تعمل على الويب (تحميل مباشر) والأندرويد (حفظ في ملف)
// ============================================================================
import 'dart:typed_data';

import 'download_io.dart' if (dart.library.html) 'download_web.dart' as dl;
import 'print_service.dart';

class ExportService {
  /// تصدير جدول كـ CSV مع تحميل/حفظ الملف
  static Future<void> exportCsv({
    required String filename,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final csv = PrintService.buildCsv(headers, rows);
    final bytes = Uint8List.fromList(csv.codeUnits);
    await _deliver(bytes, filename, 'text/csv');
  }

  /// تصدير جدول كـ Excel (SpreadsheetML) — يفتح في Excel
  static Future<void> exportExcel({
    required String filename,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final xml = _buildSpreadsheetMl(headers, rows);
    final bytes = Uint8List.fromList(xml.codeUnits);
    await _deliver(bytes, filename, 'application/vnd.ms-excel');
  }

  static Future<void> _deliver(
    Uint8List bytes,
    String filename,
    String mime,
  ) async {
    await dl.downloadBytesImpl(bytes, filename, mime);
  }

  /// بناء ملف Excel بصيغة SpreadsheetML 2003 (لا يحتاج مكتبة خارجية)
  static String _buildSpreadsheetMl(
    List<String> headers,
    List<List<String>> rows,
  ) {
    final sb = StringBuffer();
    sb.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    sb.writeln('<?mso-application progid="Excel.Sheet"?>');
    sb.writeln(
      '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"',
    );
    sb.writeln(' xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">');
    sb.writeln('<Styles>');
    sb.writeln(
      '<Style ss:ID="hdr"><Font ss:Bold="1"/><Interior ss:Color="#DDEEFF" ss:Pattern="Solid"/></Style>',
    );
    sb.writeln('</Styles>');
    sb.writeln('<Worksheet ss:Name="Report"><Table>');

    sb.writeln('<Row>');
    for (final h in headers) {
      sb.writeln(
        '<Cell ss:StyleID="hdr"><Data ss:Type="String">${_x(h)}</Data></Cell>',
      );
    }
    sb.writeln('</Row>');

    for (final r in rows) {
      sb.writeln('<Row>');
      for (final c in r) {
        final num = double.tryParse(c.replaceAll(',', ''));
        if (num != null) {
          sb.writeln('<Cell><Data ss:Type="Number">$num</Data></Cell>');
        } else {
          sb.writeln('<Cell><Data ss:Type="String">${_x(c)}</Data></Cell>');
        }
      }
      sb.writeln('</Row>');
    }

    sb.writeln('</Table></Worksheet></Workbook>');
    return sb.toString();
  }

  static String _x(String v) => v
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
