// ============================================================================
// عمليات ملفات النسخ الاحتياطي — تنفيذ الويب
// الويب لا يمنح الوصول لنظام الملفات، لذا نستخدم التنزيل/الرفع
// ============================================================================
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<String?> pickFolderImpl({String? title}) async => null;

Future<String?> defaultBackupDirImpl() async => null;

Future<bool> dirExistsImpl(String dir) async => false;

Future<String?> writeBackupFileImpl(
  String dir,
  String filename,
  Uint8List bytes,
) async {
  return filename;
}

Future<Uint8List?> readFileBytesImpl(String path) async => null;

Future<List<String>> listBackupsImpl(String dir) async => [];

Future<Uint8List?> pickBackupBytesImpl({String? initialDir}) async {
  try {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (r == null || r.files.isEmpty) return null;
    return r.files.first.bytes;
  } catch (_) {
    return null;
  }
}
