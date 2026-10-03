// ============================================================================
// مساعد الصلاحيات — يطلب الصلاحية عند الحاجة فقط (on-demand)
// يعرض حواراً واضحاً عند الرفض النهائي مع زر لفتح الإعدادات
// ============================================================================
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/permission_service.dart';
import '../../theme/app_theme.dart';

/// يطلب صلاحية واحدة عند الحاجة فقط.
/// - إن كانت ممنوحة: يعيد true دون أي إزعاج.
/// - إن رُفضت للتو: يعرض رسالة توضح سبب الحاجة.
/// - إن رُفضت نهائياً: يعرض حواراً لفتح إعدادات التطبيق.
Future<bool> ensurePermission(
  BuildContext context,
  Permission p, {
  String? reason,
}) async {
  final status = await PermissionService.request(p);
  if (status.isGranted || status.isLimited) return true;

  final why = reason ?? PermissionService.usage(p);

  if (!context.mounted) return false;

  if (status.isPermanentlyDenied || status.isRestricted) {
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('صلاحية مطلوبة'),
        content: Text(
          'يحتاج التطبيق صلاحية «${PermissionService.label(p)}».\n\n'
          'السبب: $why\n\n'
          'يرجى فتح الإعدادات ومنح الصلاحية يدوياً.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('لاحقاً'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('فتح الإعدادات'),
          ),
        ],
      ),
    );
    if (open == true) await PermissionService.openSettings();
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('يجب منح صلاحية «${PermissionService.label(p)}» لإتمام العملية'),
        backgroundColor: AppColors.warning,
      ),
    );
  }
  return false;
}

/// يطلب عدة صلاحيات (عند الحاجة فقط) — يعيد true إن مُنحت كلها
Future<bool> ensurePermissions(
  BuildContext context,
  List<Permission> perms, {
  String? reason,
}) async {
  for (final p in perms) {
    final ok = await ensurePermission(context, p, reason: reason);
    if (!ok) return false;
  }
  return true;
}
