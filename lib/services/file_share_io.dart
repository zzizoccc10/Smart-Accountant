// ============================================================================
// مشاركة ملفات عبر النظام — تنفيذ Android/Desktop
// ============================================================================
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// يكتب البايتات في ملف مؤقت ويشاركها عبر ورقة المشاركة (تشمل واتساب، البريد...)
Future<bool> shareBytesImpl(
  Uint8List bytes,
  String filename,
  String mimeType,
) async {
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([
      XFile(file.path, mimeType: mimeType),
    ], subject: filename);
    return true;
  } catch (_) {
    return false;
  }
}
