// ============================================================================
// تصدير سريع للكيانات — يبني ملف Excel ويطلبه في مكان يختاره المستخدم
// ============================================================================
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'data_registry.dart';
import 'file_saver_io.dart'
    if (dart.library.html) 'file_saver_web.dart'
    as saver;

/// تصدير كيان (حسب معرّفه في DataRegistry) إلى ملف Excel مع نافذة اختيار المكان.
/// يعرض رسائل النجاح/الفشل عبر SnackBar.
Future<void> exportEntityExcel(BuildContext context, String entityId) async {
  final messenger = ScaffoldMessenger.of(context);
  final entity = DataRegistry.byId(entityId);
  if (entity == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('لا يوجد كيان بهذا المعرّف')),
    );
    return;
  }
  try {
    final Uint8List bytes = DataRegistry.exportExcel(entityId);
    final filename = '${entityId}_${_stamp()}.xlsx';
    final path = await saver.saveBytesToPickedLocationImpl(
      bytes,
      filename,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      storageKey: entityId,
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          path == null
              ? 'تم تجهيز ملف ${entity.title}'
              : 'حُفظ ملف ${entity.title} في: $path',
        ),
      ),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('تعذّر التصدير: $e')));
  }
}

String _stamp() {
  return DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
}
