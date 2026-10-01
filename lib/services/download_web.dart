// ============================================================================
// تنزيل الملفات — تنفيذ خاص بالويب (تحميل مباشر من المتصفح)
// ============================================================================
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:typed_data';
import 'dart:html' as html;

Future<String?> downloadBytesImpl(
    Uint8List bytes, String filename, String mimeType) async {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return null;
}
