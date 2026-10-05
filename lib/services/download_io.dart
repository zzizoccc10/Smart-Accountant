// ============================================================================
// تنزيل الملفات — تنفيذ للمنصات غير الويب (Android): حفظ في مجلد مؤقت
// ============================================================================
import 'dart:io';
import 'dart:typed_data';

Future<String?> downloadBytesImpl(
  Uint8List bytes,
  String filename,
  String mimeType,
) async {
  try {
    final dir = Directory.systemTemp.createTempSync('ea_dl_');
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    return file.path;
  } catch (_) {
    return null;
  }
}
