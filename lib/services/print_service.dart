// ============================================================================
// خدمة الطباعة والتصدير — PDF للفواتير + CSV للتقارير
// ============================================================================
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class PrintService {
  static pw.Font? _arabicFont;

  /// تحميل خط Cairo لدعم النص العربي في PDF
  static Future<pw.Font> _font() async {
    if (_arabicFont != null) return _arabicFont!;
    final data = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    _arabicFont = pw.Font.ttf(data);
    return _arabicFont!;
  }

  /// توليد فاتورة PDF
  static Future<Uint8List> invoicePdf({
    required Invoice inv,
    required String companyName,
    required String currency,
    String companyPhone = '',
    String companyAddress = '',
    String footer = '',
  }) async {
    final font = await _font();
    final doc = pw.Document();

    final typeLabel = _typeLabel(inv.invoiceType);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: font),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // رأس
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(companyName,
                        style: pw.TextStyle(
                            fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    if (companyPhone.isNotEmpty)
                      pw.Text('هاتف: $companyPhone',
                          style: const pw.TextStyle(fontSize: 10)),
                    if (companyAddress.isNotEmpty)
                      pw.Text(companyAddress,
                          style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(typeLabel,
                          style: pw.TextStyle(
                              fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.Text('#${inv.invoiceNumber}',
                          style: const pw.TextStyle(fontSize: 11)),
                      pw.Text('التاريخ: ${inv.date}',
                          style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(),
            pw.SizedBox(height: 4),
            // بيانات العميل
            pw.Row(
              children: [
                pw.Text('الجهة: ',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(inv.contactName),
                pw.Spacer(),
                pw.Text('نوع الدفع: ',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(inv.paymentType == 'cash' ? 'نقدي' : 'آجل'),
              ],
            ),
            pw.SizedBox(height: 10),
            // جدول الأصناف
            pw.TableHelper.fromTextArray(
              headers: ['#', 'الصنف', 'الكمية', 'السعر', 'الخصم', 'الإجمالي'],
              data: [
                for (var i = 0; i < inv.lines.length; i++)
                  [
                    '${i + 1}',
                    inv.lines[i].itemName,
                    Fmt.num(inv.lines[i].quantity),
                    Fmt.num(inv.lines[i].unitPrice),
                    Fmt.num(inv.lines[i].discount),
                    Fmt.num(inv.lines[i].lineTotal),
                  ]
              ],
              headerStyle:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignment: pw.Alignment.centerRight,
              headerAlignment: pw.Alignment.centerRight,
            ),
            pw.SizedBox(height: 10),
            // المجاميع
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.SizedBox(
                width: 220,
                child: pw.Column(
                  children: [
                    _totalRow('الإجمالي الفرعي', inv.subtotal, currency),
                    if (inv.discountAmount > 0)
                      _totalRow('الخصم', inv.discountAmount, currency),
                    if (inv.taxAmount > 0)
                      _totalRow('الضريبة', inv.taxAmount, currency),
                    if (inv.shipping > 0)
                      _totalRow('الشحن', inv.shipping, currency),
                    pw.Divider(),
                    _totalRow('الإجمالي', inv.total, currency, bold: true),
                    if (inv.paymentType == 'credit') ...[
                      _totalRow('المدفوع', inv.paidAmount, currency),
                      _totalRow('المتبقي', inv.remaining, currency),
                    ],
                  ],
                ),
              ),
            ),
            pw.Spacer(),
            pw.Divider(),
            pw.Center(
              child: pw.Text(
                footer.isEmpty ? 'شكراً لتعاملكم معنا' : footer,
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );

    return doc.save();
  }

  static pw.Widget _totalRow(String label, double value, String curr,
      {bool bold = false}) {
    final style = pw.TextStyle(
      fontSize: bold ? 12 : 10,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(Fmt.money(value, curr), style: style),
        ],
      ),
    );
  }

  static String _typeLabel(String t) => switch (t) {
        'sale' => 'فاتورة مبيعات',
        'purchase' => 'فاتورة مشتريات',
        'sale_return' => 'مرتجع مبيعات',
        _ => 'مرتجع مشتريات',
      };

  /// طباعة/مشاركة الفاتورة
  static Future<void> printInvoice({
    required Invoice inv,
    required String companyName,
    required String currency,
    String companyPhone = '',
    String companyAddress = '',
    String footer = '',
  }) async {
    final bytes = await invoicePdf(
      inv: inv,
      companyName: companyName,
      currency: currency,
      companyPhone: companyPhone,
      companyAddress: companyAddress,
      footer: footer,
    );
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: '${inv.invoiceNumber}.pdf',
    );
  }

  /// مشاركة الفاتورة كملف
  static Future<void> shareInvoice({
    required Invoice inv,
    required String companyName,
    required String currency,
    String companyPhone = '',
    String companyAddress = '',
    String footer = '',
  }) async {
    final bytes = await invoicePdf(
      inv: inv,
      companyName: companyName,
      currency: currency,
      companyPhone: companyPhone,
      companyAddress: companyAddress,
      footer: footer,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${inv.invoiceNumber}.pdf',
    );
  }

  /// تصدير جدول إلى CSV (يدعم العربية عبر BOM)
  static String buildCsv(List<String> headers, List<List<String>> rows) {
    final sb = StringBuffer();
    sb.writeln('\uFEFF${headers.map(_esc).join(',')}');
    for (final r in rows) {
      sb.writeln(r.map(_esc).join(','));
    }
    return sb.toString();
  }

  static String _esc(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  /// توليد تقرير عام (جدول) كـ PDF
  static Future<Uint8List> tablePdf({
    required String title,
    required String companyName,
    required List<String> headers,
    required List<List<String>> rows,
    List<String> totals = const [],
    String subtitle = '',
  }) async {
    final font = await _font();
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: font),
        build: (ctx) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(companyName,
                      style: pw.TextStyle(
                          fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text(title,
                      style: pw.TextStyle(
                          fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  if (subtitle.isNotEmpty)
                    pw.Text(subtitle, style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Text(
                'تاريخ الطباعة: ${DateTime.now().toIso8601String().split('T')[0]}',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Divider(),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle:
                pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerRight,
            headerAlignment: pw.Alignment.centerRight,
          ),
          if (totals.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Divider(),
            for (final t in totals)
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(t,
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold)),
              ),
          ],
        ],
      ),
    );
    return doc.save();
  }

  /// طباعة/حفظ تقرير كـ PDF
  static Future<void> printTable({
    required String title,
    required String companyName,
    required List<String> headers,
    required List<List<String>> rows,
    List<String> totals = const [],
    String subtitle = '',
  }) async {
    final bytes = await tablePdf(
      title: title,
      companyName: companyName,
      headers: headers,
      rows: rows,
      totals: totals,
      subtitle: subtitle,
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: '$title.pdf');
  }
}
