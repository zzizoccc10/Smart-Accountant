// ============================================================================
// خدمة النسخ الاحتياطي والاستعادة — BackupService
// - تحفظ كل بيانات Hive في ملف JSON داخل مكان يختاره المستخدم
// - تتذكّر المكان المختار وتعيد فتحه عند الاستعادة
// ============================================================================
import 'dart:convert';
import 'dart:typed_data';

import '../data/app_database.dart';
import 'backup_io.dart' if (dart.library.html) 'backup_web.dart' as bio;
import 'download_io.dart' if (dart.library.html) 'download_web.dart' as dl;
import 'file_share_io.dart' if (dart.library.html) 'file_share_web.dart' as fs;
import 'file_saver_io.dart'
    if (dart.library.html) 'file_saver_web.dart'
    as saver;

class BackupService {
  // --------------------------- مفاتيح الإعدادات ---------------------------
  static const _kDir = 'backupFolder';
  static const _kDisplay = 'backupFolderDisplay';
  static const _kLastFile = 'lastBackupFile';
  static const _kStamp = 'lastBackupAt';
  static const _kAsked = 'backupLocationAsked';
  static const _saverKey = 'backup';

  /// هل تم اختيار مكان النسخة الاحتياطية من قبل؟
  static bool get hasFolder {
    final d = AppDatabase.getSetting(_kDir);
    return d.trim().isNotEmpty;
  }

  /// المسار الفعلي المختار
  static String get folder => AppDatabase.getSetting(_kDir);

  /// الاسم المعروض للمكان المختار
  static String get folderDisplay {
    final d = AppDatabase.getSetting(_kDisplay);
    return d.trim().isNotEmpty ? d : folder;
  }

  static String get lastFilePath => AppDatabase.getSetting(_kLastFile);
  static String get lastBackupAt => AppDatabase.getSetting(_kStamp);

  static String get suggestedFolder {
    final d = AppDatabase.getSetting(_kDisplay);
    return d.trim().isNotEmpty ? d : 'لم يتم اختيار مكان بعد';
  }

  /// يحفظ اختيار المستخدم لمكان النسخة الاحتياطية
  static Future<void> setLocation(String path, {String? display}) async {
    await AppDatabase.setSetting(_kDir, path);
    await AppDatabase.setSetting(_kDisplay, display ?? path);
    await AppDatabase.setSetting(_kAsked, 'true');
  }

  /// المجلد الافتراضي المقترح من النظام (إن وُجد)
  static Future<String?> suggestedDefaultDir() async {
    try {
      return await bio.defaultBackupDirImpl();
    } catch (_) {
      return null;
    }
  }

  /// نافذة اختيار مجلد من نظام الملفات
  static Future<String?> pickFolder() async {
    try {
      return await bio.pickFolderImpl(title: 'اختر مجلد حفظ النسخ الاحتياطي');
    } catch (_) {
      return null;
    }
  }

  /// مسح المكان المختار
  static Future<void> clearLocation() async {
    await AppDatabase.setSetting(_kDir, '');
    await AppDatabase.setSetting(_kDisplay, '');
  }

  static Future<bool> dirExists(String dir) async {
    try {
      return await bio.dirExistsImpl(dir);
    } catch (_) {
      return false;
    }
  }

  /// قائمة ملفات النسخ الاحتياطي في المكان المختار
  static Future<List<String>> listBackups() async {
    if (!hasFolder) return [];
    try {
      return await bio.listBackupsImpl(folder);
    } catch (_) {
      return [];
    }
  }

  static Uint8List _encodeBackup() {
    final data = AppDatabase.exportAll();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    return Uint8List.fromList(utf8.encode(jsonStr));
  }

  static String _stampName() {
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    return 'easy_accountant_backup_$stamp.json';
  }

  /// تصدير النسخة الاحتياطية إلى المكان المختار.
  /// إن لم يكن هناك مكان مختار أو تعذّرت الكتابة مباشرة، يُفتح متصفح الملفات.
  static Future<String?> exportBackup() async {
    final bytes = _encodeBackup();
    final filename = _stampName();

    if (hasFolder) {
      try {
        final path = await bio.writeBackupFileImpl(folder, filename, bytes);
        if (path != null) {
          await AppDatabase.setSetting(_kLastFile, path);
          await AppDatabase.setSetting(
            _kStamp,
            DateTime.now().toIso8601String(),
          );
          return path;
        }
      } catch (_) {}
    }

    // ملاذ: نافذة اختيار مكان الحفظ (Android SAF / سطح المكتب)
    final path = await saver.saveBytesToPickedLocationImpl(
      bytes,
      filename,
      'application/json',
      storageKey: _saverKey,
    );
    if (path != null) {
      await AppDatabase.setSetting(_kLastFile, path);
      await AppDatabase.setSetting(_kStamp, DateTime.now().toIso8601String());
      // نتذكّر المجلد الأب
      final norm = path.replaceAll('\\', '/');
      final idx = norm.lastIndexOf('/');
      if (idx > 0) await rememberByPath(norm.substring(0, idx), path);
    }
    return path;
  }

  static Future<void> rememberByPath(String dir, String path) async {
    await AppDatabase.setSetting(_kDir, dir);
    await AppDatabase.setSetting(_kDisplay, dir);
  }

  /// مشاركة النسخة الاحتياطية عبر ورقة المشاركة (واتساب/البريد/درايف...)
  static Future<bool> shareBackup() async {
    try {
      final bytes = _encodeBackup();
      return fs.shareBytesImpl(bytes, _stampName(), 'application/json');
    } catch (_) {
      return false;
    }
  }

  /// تنزيل النسخة (للويب)
  static Future<String?> downloadBackup() async {
    final bytes = _encodeBackup();
    return dl.downloadBytesImpl(bytes, _stampName(), 'application/json');
  }

  /// استعادة من ملف محدّد مسبقاً
  static Future<BackupResult> restoreFromPath(String path) async {
    try {
      final bytes = await bio.readFileBytesImpl(path);
      if (bytes == null) {
        return BackupResult(false, 'تعذّر قراءة الملف');
      }
      return _apply(bytes);
    } catch (e) {
      return BackupResult(false, 'خطأ في الاستعادة: $e');
    }
  }

  /// اختيار ملف نسخة احتياطية (يفتح المكان المختار إن أمكن) ثم استعادته
  static Future<BackupResult> restoreBackup() async {
    try {
      final bytes = await bio.pickBackupBytesImpl(
        initialDir: hasFolder ? folderDisplay : null,
      );
      if (bytes == null) {
        return BackupResult(false, 'تم الإلغاء');
      }
      return _apply(bytes);
    } catch (e) {
      return BackupResult(false, 'خطأ في الاستعادة: $e');
    }
  }

  static Future<BackupResult> _apply(Uint8List bytes) async {
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
  }
}

class BackupResult {
  final bool success;
  final String message;
  BackupResult(this.success, this.message);
}
