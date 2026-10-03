// ============================================================================
// خدمة النسخ الاحتياطي والاستعادة — BackupService
// تصدّر كل بيانات Hive إلى ملف JSON وتستعيدها منه
// ============================================================================
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../data/app_database.dart';
import 'download_io.dart' if (dart.library.html) 'download_web.dart' as dl;
import 'file_share_io.dart' if (dart.library.html) 'file_share_web.dart' as fs;

class BackupService {
  /// تصدير نسخة احتياطية وإرجاع مسار/اسم الملف
  static Future<String?> exportBackup() async {
    final data = AppDatabase.exportAll();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    final bytes = Uint8List.fromList(utf8.encode(jsonStr));
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final filename = 'easy_accountant_backup_$stamp.json';
    return dl.downloadBytesImpl(bytes, filename, 'application/json');
  }

  /// مشاركة النسخة الاحتياطية عبر ورقة المشاركة (واتساب/البريد/درايف...)
  static Future<bool> shareBackup() async {
    try {
      final data = AppDatabase.exportAll();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final filename = 'easy_accountant_backup_$stamp.json';
      return fs.shareBytesImpl(bytes, filename, 'application/json');
    } catch (_) {
      return false;
    }
  }

  /// استيراد نسخة احتياطية من ملف يختاره المستخدم
  static Future<BackupResult> restoreBackup() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) {
        return BackupResult(false, 'تم الإلغاء');
      }
      final file = picked.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        return BackupResult(false, 'تعذّر قراءة الملف');
      }
      final text = utf8.decode(bytes);
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        return BackupResult(false, 'ملف غير صالح');
      }
      final meta = decoded['_meta'];
      if (meta is! Map || meta['app'] != 'easy_accountant') {
        return BackupResult(false, 'هذا الملف ليس نسخة احتياطية للتطبيق');
      }
      await AppDatabase.importAll(Map<String, dynamic>.from(decoded));
      return BackupResult(true, 'تمت الاستعادة بنجاح');
    } catch (e) {
      return BackupResult(false, 'خطأ في الاستعادة: $e');
    }
  }
}

class BackupResult {
  final bool success;
  final String message;
  BackupResult(this.success, this.message);
}
