// ============================================================================
// شاشة استعادة النسخة الاحتياطية
// تعرض ملفات النسخ الموجودة في المكان المختار، مع خيار تصفّح ملف آخر
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/erp_provider.dart';
import '../../services/backup_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';
import 'backup_location_screen.dart';

class RestoreScreen extends StatefulWidget {
  const RestoreScreen({super.key});

  @override
  State<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends State<RestoreScreen> {
  bool _loading = true;
  bool _busy = false;
  List<String> _files = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final files = await BackupService.listBackups();
    if (!mounted) return;
    setState(() {
      _files = files;
      _loading = false;
    });
  }

  String _fileName(String path) {
    final n = path.replaceAll('\\', '/');
    final i = n.lastIndexOf('/');
    return i >= 0 ? n.substring(i + 1) : n;
  }

  Future<void> _restoreFrom(String path) async {
    final ok = await confirmDialog(
      context,
      title: 'استعادة نسخة احتياطية',
      message:
          'سيتم استبدال كل البيانات الحالية بالبيانات الموجودة في الملف:\n${_fileName(path)}\n\nهل أنت متأكد؟',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final res = await BackupService.restoreFromPath(path);
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.success) context.read<ERPProvider>().reload();
    _snack(res.message, res.success ? AppColors.success : AppColors.danger);
  }

  Future<void> _browseFile() async {
    final ok = await confirmDialog(
      context,
      title: 'استعادة نسخة احتياطية',
      message:
          'سيتم استبدال كل البيانات الحالية بالبيانات من الملف. هل أنت متأكد؟',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final res = await BackupService.restoreBackup();
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.success) {
      context.read<ERPProvider>().reload();
      _load();
    }
    _snack(res.message, res.success ? AppColors.success : AppColors.danger);
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final place = BackupService.suggestedFolder;
    return Scaffold(
      appBar: AppBar(title: const Text('استعادة نسخة احتياطية')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.folder_special,
                  color: AppColors.info,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'مكان الحفظ: $place',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          final ok = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BackupLocationScreen(),
                            ),
                          );
                          if (ok == true) _load();
                        },
                  child: const Text('تغيير'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _files.isEmpty
                ? const EmptyState(
                    message:
                        'لا توجد ملفات نسخ احتياطية في المكان المختار.\nيمكنك تصفّح ملف آخر يدوياً.',
                    icon: Icons.folder_off_outlined,
                  )
                : ListView.separated(
                    itemCount: _files.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final f = _files[i];
                      return ListTile(
                        leading: const Icon(
                          Icons.description,
                          color: AppColors.info,
                        ),
                        title: Text(
                          _fileName(f),
                          style: const TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          f,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10),
                        ),
                        trailing: const Icon(Icons.restore),
                        enabled: !_busy,
                        onTap: () => _restoreFrom(f),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('تحديث القائمة'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : _browseFile,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.folder_open),
                      label: const Text('تصفّح ملفاً'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
