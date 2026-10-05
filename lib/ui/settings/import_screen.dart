// ============================================================================
// شاشة الاستيراد والتصدير — Excel/CSV لكل أجزاء النظام
// اختيار الكيان + تصدير (مع اختيار مكان الحفظ) + استيراد من ملف
// ============================================================================
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/erp_provider.dart';
import '../../services/data_registry.dart';
import '../../services/file_saver_io.dart'
    if (dart.library.html) '../../services/file_saver_web.dart'
    as saver;
import '../../services/excel_service.dart';
import '../../services/import_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  String _entity = 'contacts';
  bool _busy = false;
  ImportResult? _result;
  String? _fileName;
  String? _savedPath;

  DataEntity get _current => DataRegistry.byId(_entity)!;

  // ---------------------------- التصدير ----------------------------
  Future<void> _exportExcel() async {
    setState(() {
      _busy = true;
      _result = null;
      _savedPath = null;
    });
    try {
      final bytes = DataRegistry.exportExcel(_entity);
      final filename = '${_entity}_${_stamp()}.xlsx';
      final path = await saver.saveBytesToPickedLocationImpl(
        bytes,
        filename,
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _savedPath = path;
      });
      _snack(
        path == null ? 'تم تجهيز ملف Excel' : 'تم حفظ الملف في: $path',
        AppColors.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('فشل التصدير: $e', AppColors.danger);
    }
  }

  Future<void> _exportCsv() async {
    setState(() {
      _busy = true;
      _result = null;
      _savedPath = null;
    });
    try {
      final lines = DataRegistry.exportCsv(_entity);
      final csv = '\uFEFF${lines.join('\n')}';
      final bytes = Uint8List.fromList(csv.codeUnits);
      final filename = '${_entity}_${_stamp()}.csv';
      final path = await saver.saveBytesToPickedLocationImpl(
        bytes,
        filename,
        'text/csv',
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _savedPath = path;
      });
      _snack(
        path == null ? 'تم تصدير CSV' : 'تم الحفظ في: $path',
        AppColors.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('فشل التصدير: $e', AppColors.danger);
    }
  }

  // ---------------------------- الاستيراد ----------------------------
  Future<void> _import() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    setState(() {
      _busy = true;
      _fileName = file.name;
      _result = null;
    });

    try {
      final lower = file.name.toLowerCase();
      final rows = lower.endsWith('.csv')
          ? ImportService.parseBytes(file.name, bytes)
          : ExcelService.parse(bytes);
      final res = await DataRegistry.importFromRows(_entity, rows);
      if (!mounted) return;
      context.read<ERPProvider>().reload();
      setState(() {
        _result = res;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('فشل قراءة الملف: $e', AppColors.danger);
    }
  }

  void _snack(String msg, Color c) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: c));
  }

  String _stamp() =>
      DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;

  @override
  Widget build(BuildContext context) {
    final headers = _current.headers;

    return Scaffold(
      appBar: AppBar(title: const Text('الاستيراد والتصدير')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionTitle('نوع البيانات', icon: Icons.category),
          DropdownButtonFormField<String>(
            initialValue: _entity,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'اختر القسم',
              prefixIcon: Icon(Icons.list_alt),
            ),
            items: [
              for (final e in DataRegistry.entities)
                DropdownMenuItem(value: e.id, child: Text(e.title)),
            ],
            onChanged: (v) => setState(() {
              _entity = v ?? 'contacts';
              _result = null;
              _fileName = null;
              _savedPath = null;
            }),
          ),
          const SizedBox(height: 16),

          // الأعمدة
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الأعمدة (الصف الأول = العناوين):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    headers.join(' | '),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // التصدير
          const SectionTitle('تصدير', icon: Icons.upload),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _exportExcel,
                  icon: const Icon(Icons.table_chart),
                  label: const Text('Excel (.xlsx)'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _exportCsv,
                  icon: const Icon(Icons.description),
                  label: const Text('CSV'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'سيتم عرض نافذة لاختيار مكان الحفظ في ذاكرة الهاتف.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),

          const SizedBox(height: 20),
          // الاستيراد
          const SectionTitle('استيراد', icon: Icons.download),
          ElevatedButton.icon(
            onPressed: _busy ? null : _import,
            icon: const Icon(Icons.file_open),
            label: Text(_busy ? 'جارٍ المعالجة...' : 'اختيار ملف Excel/CSV'),
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          if (_fileName != null) ...[
            const SizedBox(height: 12),
            Text(
              'الملف: $_fileName',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
          if (_savedPath != null) ...[
            const SizedBox(height: 12),
            Card(
              color: AppColors.success.withValues(alpha: 0.08),
              child: ListTile(
                leading: const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                ),
                title: const Text('تم حفظ الملف'),
                subtitle: Text(
                  _savedPath!,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 20),
            Card(
              color: _result!.failed == 0
                  ? AppColors.success.withValues(alpha: 0.08)
                  : AppColors.warning.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _result!.failed == 0
                              ? Icons.check_circle
                              : Icons.info,
                          color: _result!.failed == 0
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'نجح: ${_result!.success}  |  فشل: ${_result!.failed}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    if (_result!.hasErrors) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'تفاصيل الأخطاء:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ..._result!.errors
                          .take(20)
                          .map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '• $e',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.danger,
                                ),
                              ),
                            ),
                          ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
