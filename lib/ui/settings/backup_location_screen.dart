// ============================================================================
// شاشة مكان النسخة الاحتياطية — اختيار المجلد الذي تُحفظ فيه النسخ
// تظهر تلقائياً عند أول حفظ للنسخة الاحتياطية، ويمكن فتحها لاحقاً
// ============================================================================
import 'dart:io';

import 'package:flutter/material.dart';

import '../../services/backup_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

/// نتيجة الشاشة: true إذا تم اختيار مكان
class BackupLocationScreen extends StatefulWidget {
  final bool firstTime;
  const BackupLocationScreen({super.key, this.firstTime = false});

  @override
  State<BackupLocationScreen> createState() => _BackupLocationScreenState();
}

class _BackupLocationScreenState extends State<BackupLocationScreen> {
  final _pathCtrl = TextEditingController();
  String? _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = BackupService.folderDisplay;
    if (existing.trim().isNotEmpty) {
      _pathCtrl.text = existing;
      _selected = existing;
    }
  }

  @override
  void dispose() {
    _pathCtrl.dispose();
    super.dispose();
  }

  bool get _isWeb => !(Platform.isAndroid || Platform.isIOS || Platform.isLinux ||
      Platform.isMacOS || Platform.isWindows);

  Future<void> _browse() async {
    final dir = await BackupService.pickFolder();
    if (dir != null && mounted) {
      setState(() {
        _selected = dir;
        _pathCtrl.text = dir;
      });
    }
  }

  Future<void> _useDefault() async {
    final def = await BackupService.suggestedDefaultDir();
    if (def != null && mounted) {
      setState(() {
        _selected = def;
        _pathCtrl.text = def;
      });
    }
  }

  Future<void> _save() async {
    final p = _pathCtrl.text.trim();
    if (p.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء اختيار مكان حفظ النسخة الاحتياطية'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    await BackupService.setLocation(p, display: p);
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final hasExisting = BackupService.hasFolder;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.firstTime ? 'مكان حفظ النسخة الاحتياطية' : 'مكان النسخة الاحتياطية'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.firstTime)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.info),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'هذه أول مرة تحفظ فيها نسخة احتياطية. اختر المكان المناسب لحفظها، وسيتم استخدامه تلقائياً لاحقاً.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          const SectionTitle('مكان الحفظ', icon: Icons.folder_special),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isWeb)
                    const Text(
                      'على المتصفح يتم تنزيل ملف النسخة الاحتياطية إلى مجلد التنزيلات تلقائياً.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    )
                  else ...[
                    TextField(
                      controller: _pathCtrl,
                      onChanged: (v) => _selected = v,
                      decoration: const InputDecoration(
                        labelText: 'المسار / المجلد',
                        prefixIcon: Icon(Icons.folder_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _browse,
                            icon: const Icon(Icons.folder_open),
                            label: const Text('اختيار مجلد'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _useDefault,
                            icon: const Icon(Icons.settings_suggest),
                            label: const Text('المجلد الافتراضي'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_selected != null && _selected!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: AppColors.success, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'المكان الحالي: ${_selected!}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.success),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
            label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ المكان'),
          ),
          if (hasExisting) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                final nav = Navigator.of(context);
                await BackupService.clearLocation();
                nav.pop(false);
              },
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              label: const Text('مسح المكان المحدد',
                  style: TextStyle(color: AppColors.danger)),
            ),
          ],
        ],
      ),
    );
  }
}
