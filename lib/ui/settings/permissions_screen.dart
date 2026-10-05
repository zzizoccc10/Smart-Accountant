// ============================================================================
// شاشة الصلاحيات — عرض وطلب أذونات أندرويد (جهات الاتصال/التخزين/SMS/الهاتف)
// ============================================================================
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/permission_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  Map<Permission, PermissionStatus> _statuses = {};
  bool _loading = true;

  IconData _icon(Permission p) {
    if (p == Permission.contacts) return Icons.contacts;
    if (p == Permission.storage) return Icons.folder;
    if (p == Permission.phone) return Icons.phone;
    if (p == Permission.sms) return Icons.sms;
    if (p == Permission.camera) return Icons.camera_alt;
    return Icons.lock;
  }

  Color _color(PermissionStatus s) {
    if (s.isGranted) return AppColors.success;
    if (s.isPermanentlyDenied || s.isRestricted) return AppColors.danger;
    return AppColors.warning;
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final map = await PermissionService.statusMap();
    if (!mounted) return;
    setState(() {
      _statuses = map;
      _loading = false;
    });
  }

  Future<void> _requestAll() async {
    final result = await PermissionService.requestCore();
    if (!mounted) return;
    setState(() => _statuses = result);
    final granted = result.values.where((s) => s.isGranted).length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم منح $granted من ${result.length} صلاحيات'),
        backgroundColor: granted == result.length
            ? AppColors.success
            : AppColors.warning,
      ),
    );
  }

  Future<void> _requestOne(Permission p) async {
    final s = await PermissionService.request(p);
    if (!mounted) return;
    if (s.isPermanentlyDenied) {
      final open = await confirmDialog(
        context,
        title: 'الصلاحية مرفوضة نهائياً',
        message:
            'يرجى فتح إعدادات التطبيق ومنح الصلاحية يدوياً من قائمة الأذونات.',
        confirmText: 'فتح الإعدادات',
      );
      if (open) await PermissionService.openSettings();
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final granted = _statuses.values.where((s) => s.isGranted).length;
    final total = _statuses.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('صلاحيات التطبيق'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: _refresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          granted == total
                              ? Icons.verified_user
                              : Icons.shield_outlined,
                          size: 42,
                          color: granted == total
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$granted / $total صلاحية مُمنوحة',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'يمنح التطبيق ميزات التواصل والاستيراد والحفظ',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _requestAll,
                            icon: const Icon(Icons.check_circle),
                            label: const Text('طلب جميع الصلاحيات'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const SectionTitle('الصلاحيات', icon: Icons.lock_open),
                ...PermissionService.corePermissions.map((p) {
                  final st = _statuses[p] ?? PermissionStatus.denied;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _color(st).withValues(alpha: 0.14),
                        child: Icon(_icon(p), color: _color(st), size: 20),
                      ),
                      title: Text(
                        PermissionService.label(p),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        PermissionService.usage(p),
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: st.isGranted
                          ? Icon(Icons.check_circle, color: AppColors.success)
                          : TextButton(
                              onPressed: () => _requestOne(p),
                              child: Text(
                                PermissionService.statusLabel(st),
                                style: TextStyle(color: _color(st)),
                              ),
                            ),
                    ),
                  );
                }),
                const SizedBox(height: 10),
                Card(
                  color: AppColors.info.withValues(alpha: 0.06),
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.info),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'تُستخدم هذه الصلاحيات لاستيراد العملاء من جهات الاتصال، '
                            'وحفظ الملفات، وإرسال الفواتير عبر واتساب أو رسائل SMS.',
                            style: TextStyle(fontSize: 12),
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
