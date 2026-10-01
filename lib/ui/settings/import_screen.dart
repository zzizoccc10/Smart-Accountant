// ============================================================================
// شاشة استيراد البيانات — Excel / CSV
// ============================================================================
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/erp_provider.dart';
import '../../services/import_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  String _target = 'items'; // items / contacts
  bool _busy = false;
  ImportResult? _result;
  String? _fileName;

  Future<void> _pickAndImport() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx'],
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
      final rows = ImportService.parseBytes(file.name, bytes);
      final res = _target == 'items'
          ? await ImportService.importItems(rows)
          : await ImportService.importContacts(rows);
      if (!mounted) return;
      context.read<ERPProvider>().reload();
      setState(() {
        _result = res;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل قراءة الملف: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _copyTemplate() async {
    final csv = _target == 'items'
        ? ImportService.itemsTemplateCsv()
        : ImportService.contactsTemplateCsv();
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ القالب — الصقه في Excel ثم املأه وارفع الملف'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استيراد البيانات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionTitle('نوع البيانات', icon: Icons.category),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'items',
                label: Text('الأصناف'),
                icon: Icon(Icons.inventory_2),
              ),
              ButtonSegment(
                value: 'contacts',
                label: Text('العملاء والموردون'),
                icon: Icon(Icons.people),
              ),
            ],
            selected: {_target},
            onSelectionChanged: (s) => setState(() {
              _target = s.first;
              _result = null;
              _fileName = null;
            }),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الأعمدة المطلوبة (الصف الأول = العناوين):',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(
                    _target == 'items'
                        ? 'الكود | الاسم | الباركود | سعر الشراء | سعر البيع | حد الطلب'
                        : 'الكود | الاسم | النوع | الهاتف | البريد | الرقم الضريبي',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _target == 'items'
                        ? 'ملاحظة: عمود «الاسم» إلزامي.'
                        : 'ملاحظة: النوع = عميل / مورد / كلاهما.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _copyTemplate,
            icon: const Icon(Icons.copy_all),
            label: const Text('نسخ قالب CSV (لصقه في Excel)'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _busy ? null : _pickAndImport,
            icon: const Icon(Icons.upload_file),
            label: Text(_busy ? 'جارٍ الاستيراد...' : 'اختيار ملف Excel/CSV'),
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          if (_fileName != null) ...[
            const SizedBox(height: 12),
            Text('الملف: $_fileName',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
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
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    if (_result!.hasErrors) ...[
                      const SizedBox(height: 10),
                      const Text('تفاصيل الأخطاء:',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      ..._result!.errors.take(20).map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('• $e',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.danger)),
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
