// ============================================================================
// حفظ ملفات — تنفيذ Android/Desktop
// يفتح نافذة اختيار مكان الحفظ (SAF) ثم يكتب الملف هناك
// ويتذكّر آخر مجلد اختاره المستخدم ليظهر تلقائياً في المرة القادمة
// ============================================================================
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

// صندوق نتذكّر فيه آخر مجلد اختاره المستخدم لكل نوع ملف
const _boxName = 'export_locations';

Future<Box> _openBox() async {
  if (Hive.isBoxOpen(_boxName)) return Hive.box(_boxName);
  return Hive.openBox(_boxName);
}

/// يعيد اسم المجلد الأب لمسار ملف
String? _parentDir(String filePath) {
  final norm = filePath.replaceAll('\\', '/');
  final idx = norm.lastIndexOf('/');
  if (idx <= 0) return null;
  return norm.substring(0, idx);
}

/// آخر مجلد اختاره المستخدم لهذا النوع من الملفات (إن وُجد)
Future<String?> lastDirFor(String key) async {
  try {
    final box = await _openBox();
    final v = box.get(key);
    return (v is String && v.trim().isNotEmpty) ? v : null;
  } catch (_) {
    return null;
  }
}

/// يحفظ المجلد المختار لهذه المفتاح
Future<void> rememberDir(String key, String? filePath) async {
  if (filePath == null) return;
  final dir = _parentDir(filePath);
  if (dir == null) return;
  try {
    final box = await _openBox();
    await box.put(key, dir);
  } catch (_) {}
}

/// آخر مجلد محفوظ لمفتاح معيّن (للقراءة المباشرة من الإعدادات)
Future<String?> savedDirFor(String key) => lastDirFor(key);

/// ملاذ أخير: الكتابة في مجلد التطبيق عند فشل نافذة الاختيار
Future<String?> _fallbackWrite(Uint8List bytes, String filename) async {
  try {
    Directory? dir;
    if (Platform.isAndroid) {
      dir = await getExternalStorageDirectory();
    }
    dir ??= await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  } catch (_) {
    return null;
  }
}

/// يفتح نافذة اختيار مكان الحفظ ويُرجع المسار المختار (أو null عند الإلغاء)
Future<String?> saveBytesToPickedLocationImpl(
  Uint8List bytes,
  String filename,
  String mimeType, {
  String? storageKey,
}) async {
  final key = storageKey ?? 'default';
  final initialDir = await lastDirFor(key);
  final supportsInitialDir = Platform.isLinux || Platform.isMacOS || Platform.isWindows;

  try {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'اختر مكان حفظ الملف',
      fileName: filename,
      initialDirectory: supportsInitialDir ? initialDir : null,
      type: FileType.custom,
      allowedExtensions: [filename.split('.').last],
      bytes: bytes,
    );
    if (path != null) await rememberDir(key, path);
    return path;
  } catch (_) {
    try {
      final path = await FilePicker.platform.saveFile(
        fileName: filename,
        bytes: bytes,
      );
      if (path != null) await rememberDir(key, path);
      return path;
    } catch (_) {
      final fallback = await _fallbackWrite(bytes, filename);
      if (fallback != null) await rememberDir(key, fallback);
      return fallback;
    }
  }
}

/// حفظ مباشر بدون نافذة (احتياطي)
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

/// يفتح نافذة اختيار مجلد ويُرجع مساره (أو null عند الإلغاء)
Future<String?> getDirectoryPathImpl({String? title}) async {
  try {
    final dir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: title ?? 'اختر مجلداً',
    );
    return dir;
  } catch (_) {
    return null;
  }
}
