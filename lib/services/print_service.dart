// ============================================================================
// خدمة الطباعة والتصدير — PDF للفواتير + CSV للتقارير
// ============================================================================
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'num_words.dart';

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
    String taxNumber = '',
    String crNumber = '',
    String footer = '',
    Uint8List? logoBytes,
  }) async {
    final font = await _font();
    final doc = pw.Document();

    final typeLabel = _typeLabel(inv.invoiceType);
    final logo = logoBytes == null ? null : pw.MemoryImage(logoBytes);

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
                    if (logo != null) ...[
                      pw.SizedBox(height: 42, child: pw.Image(logo)),
                      pw.SizedBox(height: 4),
                    ],
                    pw.Text(companyName,
                        style: pw.TextStyle(
                            fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    if (companyPhone.isNotEmpty)
                      pw.Text('هاتف: $companyPhone',
                          style: const pw.TextStyle(fontSize: 10)),
                    if (companyAddress.isNotEmpty)
                      pw.Text(companyAddress,
                          style: const pw.TextStyle(fontSize: 10)),
                    if (taxNumber.isNotEmpty)
                      pw.Text('الرقم الضريبي: $taxNumber',
                          style: const pw.TextStyle(fontSize: 10)),
                    if (crNumber.isNotEmpty)
                      pw.Text('سجل تجاري: $crNumber',
                          style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Row(
                  children: [
                    ?_zatcaQr(
                      inv: inv,
                      sellerName: companyName,
                      vatNumber: taxNumber,
                    ),
                    pw.SizedBox(width: 8),
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

  /// بناء رمز QR الضريبي (ZATCA — فوترة إلكترونية)
  /// يعتمد ترميز TLV ثم Base64 وفق متطلبات هيئة الزكاة والضريبة والجمارك.
  static String zatcaQrBase64({
    required String sellerName,
    required String vatNumber,
    required String timestamp,
    required double totalWithVat,
    required double vatTotal,
  }) {
    final buf = BytesBuilder();
    void addTlv(int tag, String value) {
      final bytes = utf8.encode(value);
      buf.addByte(tag);
      buf.addByte(bytes.length);
      buf.add(bytes);
    }

    addTlv(1, sellerName);
    addTlv(2, vatNumber);
    addTlv(3, timestamp);
    addTlv(4, totalWithVat.toStringAsFixed(2));
    addTlv(5, vatTotal.toStringAsFixed(2));
    return base64.encode(buf.toBytes());
  }

  /// عنصر QR للطباعة (يُخفى إذا لا يوجد رقم ضريبي)
  static pw.Widget? _zatcaQr({
    required Invoice inv,
    required String sellerName,
    required String vatNumber,
  }) {
    if (vatNumber.isEmpty) return null;
    final data = zatcaQrBase64(
      sellerName: sellerName,
      vatNumber: vatNumber,
      timestamp: DateTime.now().toIso8601String(),
      totalWithVat: inv.total,
      vatTotal: inv.taxAmount,
    );
    return pw.SizedBox(
      width: 70,
      height: 70,
      child: pw.BarcodeWidget(
        barcode: pw.Barcode.qrCode(),
        data: data,
        drawText: false,
      ),
    );
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
    String taxNumber = '',
    String crNumber = '',
    String footer = '',
    Uint8List? logoBytes,
  }) async {
    final bytes = await invoicePdf(
      inv: inv,
      companyName: companyName,
      currency: currency,
      companyPhone: companyPhone,
      companyAddress: companyAddress,
      taxNumber: taxNumber,
      crNumber: crNumber,
      footer: footer,
      logoBytes: logoBytes,
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
    String taxNumber = '',
    String crNumber = '',
    String footer = '',
    Uint8List? logoBytes,
  }) async {
    final bytes = await invoicePdf(
      inv: inv,
      companyName: companyName,
      currency: currency,
      companyPhone: companyPhone,
      companyAddress: companyAddress,
      taxNumber: taxNumber,
      crNumber: crNumber,
      footer: footer,
      logoBytes: logoBytes,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${inv.invoiceNumber}.pdf',
    );
  }

  /// توليد سند قبض/صرف PDF
  static Future<Uint8List> voucherPdf({
    required Payment v,
    required String companyName,
    required String currency,
    String companyPhone = '',
    String companyAddress = '',
    String taxNumber = '',
    String crNumber = '',
    String cashboxName = '',
    String footer = '',
    Uint8List? logoBytes,
  }) async {
    final font = await _font();
    final doc = pw.Document();
    final logo = logoBytes == null ? null : pw.MemoryImage(logoBytes);
    final isReceipt = v.paymentType == 'receipt';
    final title = isReceipt ? 'سند قبض' : 'سند صرف';
    final methodLabel = _methodLabel(v.paymentMethod);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: font),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // رأس المنشأة
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (logo != null) ...[
                      pw.SizedBox(height: 42, child: pw.Image(logo)),
                      pw.SizedBox(height: 4),
                    ],
                    pw.Text(companyName,
                        style: pw.TextStyle(
                            fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    if (companyPhone.isNotEmpty)
                      pw.Text('هاتف: $companyPhone',
                          style: const pw.TextStyle(fontSize: 10)),
                    if (companyAddress.isNotEmpty)
                      pw.Text(companyAddress,
                          style: const pw.TextStyle(fontSize: 10)),
                    if (taxNumber.isNotEmpty)
                      pw.Text('الرقم الضريبي: $taxNumber',
                          style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey500),
                    borderRadius: pw.BorderRadius.circular(6),
                    color: isReceipt ? PdfColors.green50 : PdfColors.red50,
                  ),
                  child: pw.Text(title,
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 1),
            pw.SizedBox(height: 6),

            // رقم السند والتاريخ
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('رقم السند: ${v.paymentNumber}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('التاريخ: ${v.date}'),
              ],
            ),
            pw.SizedBox(height: 14),

            // المبلغ بالأرقام والكلمات
            _voucherRow(isReceipt ? 'استلمنا من' : 'صرفنا إلى',
                v.contactName.isEmpty ? '____________' : v.contactName),
            pw.SizedBox(height: 8),
            _voucherRow('مبلغاً وقدره', Fmt.money(v.amount, currency)),
            pw.SizedBox(height: 8),
            _voucherRow('فقط', NumWords.money(v.amount, '')),
            pw.SizedBox(height: 8),
            _voucherRow('طريقة الدفع', methodLabel),
            if (cashboxName.isNotEmpty) ...[
              pw.SizedBox(height: 8),
              _voucherRow('الصندوق / الحساب', cashboxName),
            ],
            if (v.description.isNotEmpty) ...[
              pw.SizedBox(height: 8),
              _voucherRow('البيان', v.description),
            ],

            pw.SizedBox(height: 40),
            // التوقيعات
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _signBox(isReceipt ? 'توقيع المستلم' : 'توقيع المستفيد'),
                _signBox('توقيع المسؤول'),
              ],
            ),
            pw.Spacer(),
            pw.Divider(),
            pw.Center(
              child: pw.Text(
                footer.isEmpty ? 'شكراً لتعاملكم معنا' : footer,
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }

  static pw.Widget _voucherRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 110,
          child: pw.Text('$label:',
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: 12)),
        ),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 4),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.6)),
            ),
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }

  static pw.Widget _signBox(String label) {
    return pw.Column(
      children: [
        pw.SizedBox(height: 30, width: 150),
        pw.Container(width: 150, height: 0.7, color: PdfColors.grey500),
        pw.SizedBox(height: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  static String _methodLabel(String m) => switch (m) {
        'cash' => 'نقدي',
        'check' => 'شيك',
        'card' => 'بطاقة',
        'transfer' => 'تحويل بنكي',
        _ => m.isEmpty ? '_____' : m,
      };

  /// طباعة سند
  static Future<void> printVoucher({
    required Payment v,
    required String companyName,
    required String currency,
    String companyPhone = '',
    String companyAddress = '',
    String taxNumber = '',
    String crNumber = '',
    String cashboxName = '',
    String footer = '',
    Uint8List? logoBytes,
  }) async {
    final bytes = await voucherPdf(
      v: v,
      companyName: companyName,
      currency: currency,
      companyPhone: companyPhone,
      companyAddress: companyAddress,
      taxNumber: taxNumber,
      crNumber: crNumber,
      cashboxName: cashboxName,
      footer: footer,
      logoBytes: logoBytes,
    );
    await Printing.layoutPdf(
        onLayout: (_) async => bytes, name: '${v.paymentNumber}.pdf');
  }

  /// مشاركة سند كملف PDF
  static Future<void> shareVoucher({
    required Payment v,
    required String companyName,
    required String currency,
    String companyPhone = '',
    String companyAddress = '',
    String taxNumber = '',
    String crNumber = '',
    String cashboxName = '',
    String footer = '',
    Uint8List? logoBytes,
  }) async {
    final bytes = await voucherPdf(
      v: v,
      companyName: companyName,
      currency: currency,
      companyPhone: companyPhone,
      companyAddress: companyAddress,
      taxNumber: taxNumber,
      crNumber: crNumber,
      cashboxName: cashboxName,
      footer: footer,
      logoBytes: logoBytes,
    );
    await Printing.sharePdf(bytes: bytes, filename: '${v.paymentNumber}.pdf');
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

  /// مشاركة تقرير كملف PDF
  static Future<void> shareTable({
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
    await Printing.sharePdf(bytes: bytes, filename: '$title.pdf');
  }
}
