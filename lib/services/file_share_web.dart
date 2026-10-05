// ============================================================================
// مشاركة ملفات عبر النظام — تنفيذ الويب (تنزيل مباشر بدل ورقة المشاركة)
// ============================================================================
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:typed_data';
import 'dart:html' as html;

Future<bool> shareBytesImpl(
  Uint8List bytes,
  String filename,
  String mimeType,
) async {
  try {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = filename
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
    return true;
  } catch (_) {
    return false;
  }
}
