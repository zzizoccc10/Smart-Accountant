// ============================================================================
// حفظ ملفات — تنفيذ الويب (تنزيل مباشر من المتصفح)
// ============================================================================
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

Future<String?> saveBytesToPickedLocationImpl(
  Uint8List bytes,
  String filename,
  String mimeType, {
  String? storageKey,
}) async {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return filename;
}

Future<String?> saveBytesDirectImpl(
  Uint8List bytes,
  String filename,
  String mimeType, {
  String? storageKey,
}) async {
  return saveBytesToPickedLocationImpl(
    bytes,
    filename,
    mimeType,
    storageKey: storageKey,
  );
}

/// الويب لا يدعم اختيار مجلد — يُرجع null
Future<String?> getDirectoryPathImpl({String? title}) async => null;
