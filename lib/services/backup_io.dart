// ============================================================================
// عمليات ملفات النسخ الاحتياطي — تنفيذ Android/Desktop
// ============================================================================
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

/// نافذة اختيار مجلد
Future<String?> pickFolderImpl({String? title}) async {
  try {
    return await FilePicker.platform.getDirectoryPath(
      dialogTitle: title ?? 'اختر مجلداً',
    );
  } catch (_) {
    return null;
  }
}

/// المجلد الافتراضي المقترح للنسخ الاحتياطي
Future<String?> defaultBackupDirImpl() async {
  try {
    final d = await getApplicationDocumentsDirectory();
    return '${d.path}/backups';
  } catch (_) {
    return null;
  }
}

Future<bool> dirExistsImpl(String dir) async {
  try {
    return Directory(dir).exists();
  } catch (_) {
    return false;
  }
}

/// كتابة ملف النسخة الاحتياطية داخل المجلد المحدد
Future<String?> writeBackupFileImpl(
  String dir,
  String filename,
  Uint8List bytes,
) async {
  try {
    final d = Directory(dir);
    if (!await d.exists()) await d.create(recursive: true);
    final f = File('${d.path}/$filename');
    await f.writeAsBytes(bytes, flush: true);
    return f.path;
  } catch (_) {
    return null;
  }
}

Future<Uint8List?> readFileBytesImpl(String path) async {
  try {
    return await File(path).readAsBytes();
  } catch (_) {
    return null;
  }
}

/// قائمة ملفات النسخ الاحتياطي في المجلد، الأحدث أولاً
Future<List<String>> listBackupsImpl(String dir) async {
  try {
    final d = Directory(dir);
    if (!await d.exists()) return [];
    final files = d
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.json'))
        .toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files.map((f) => f.path).toList();
  } catch (_) {
    return [];
  }
}

/// فتح نافذة اختيار ملف نسخة احتياطية وإرجاع محتواه
Future<Uint8List?> pickBackupBytesImpl({String? initialDir}) async {
  try {
    final supportsInitialDir =
        Platform.isLinux || Platform.isMacOS || Platform.isWindows;
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      initialDirectory: supportsInitialDir ? initialDir : null,
      withData: true,
    );
    if (r == null || r.files.isEmpty) return null;
    final f = r.files.first;
    if (f.bytes != null) return f.bytes;
    if (f.path != null) return await File(f.path!).readAsBytes();
    return null;
  } catch (_) {
    return null;
  }
}
