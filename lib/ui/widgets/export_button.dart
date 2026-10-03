// ============================================================================
// زر تصدير موحّد (PDF + Excel + CSV) للتقارير
// ============================================================================
import 'package:flutter/material.dart';
import '../../services/export_service.dart';
import '../../services/print_service.dart';
import '../../services/share_service.dart';

class ExportButton extends StatelessWidget {
  final String title;
  final String companyName;
  final String filename;
  final List<String> headers;
  final List<List<String>> rows;
  final List<String> totals;

  const ExportButton({
    super.key,
    required this.title,
    required this.companyName,
    required this.filename,
    required this.headers,
    required this.rows,
    this.totals = const [],
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.ios_share),
      tooltip: 'تصدير',
      onSelected: (v) async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          switch (v) {
            case 'pdf':
              await PrintService.printTable(
                title: title,
                companyName: companyName,
                headers: headers,
                rows: rows,
                totals: totals,
              );
              break;
            case 'excel':
              await ExportService.exportExcel(
                filename: '$filename.xls',
                headers: headers,
                rows: rows,
              );
              messenger.showSnackBar(
                const SnackBar(content: Text('تم تصدير ملف Excel')),
              );
              break;
            case 'csv':
              await ExportService.exportCsv(
                filename: '$filename.csv',
                headers: headers,
                rows: rows,
              );
              messenger.showSnackBar(
                const SnackBar(content: Text('تم تصدير ملف CSV')),
              );
              break;
            case 'share':
              await PrintService.shareTable(
                title: title,
                companyName: companyName,
                headers: headers,
                rows: rows,
                totals: totals,
              );
              break;
            case 'whatsapp':
              await ShareService.whatsapp(_asText());
              messenger.showSnackBar(
                const SnackBar(content: Text('تم فتح واتساب')),
              );
              break;
            case 'sms':
              await ShareService.sms(_asText());
              messenger.showSnackBar(
                const SnackBar(content: Text('تم فتح تطبيق الرسائل')),
              );
              break;
          }
        } catch (e) {
          messenger.showSnackBar(
            SnackBar(content: Text('فشل التصدير: $e')),
          );
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'pdf',
          child: ListTile(
            leading: Icon(Icons.picture_as_pdf),
            title: Text('PDF'),
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: 'excel',
          child: ListTile(
            leading: Icon(Icons.table_chart),
            title: Text('Excel'),
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: 'csv',
          child: ListTile(
            leading: Icon(Icons.description),
            title: Text('CSV'),
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: 'share',
          child: ListTile(
            leading: Icon(Icons.ios_share),
            title: Text('مشاركة PDF'),
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: 'whatsapp',
          child: ListTile(
            leading: Icon(Icons.chat, color: Color(0xFF25D366)),
            title: Text('واتساب'),
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: 'sms',
          child: ListTile(
            leading: Icon(Icons.sms),
            title: Text('رسالة SMS'),
            dense: true,
          ),
        ),
      ],
    );
  }

  /// تحويل التقرير إلى نص لمشاركته عبر واتساب/SMS
  String _asText() {
    final sb = StringBuffer();
    sb.writeln('*$title*');
    sb.writeln(companyName);
    sb.writeln('--------------------');
    sb.writeln(headers.join(' | '));
    for (final r in rows) {
      sb.writeln(r.join(' | '));
    }
    if (totals.isNotEmpty) {
      sb.writeln('--------------------');
      for (final t in totals) {
        sb.writeln(t);
      }
    }
    return sb.toString();
  }
}
