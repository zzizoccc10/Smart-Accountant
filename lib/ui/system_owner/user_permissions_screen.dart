// ============================================================================
// صلاحيات مستخدم (لوحة مالك النظام) — UserPermissionsScreen
// ----------------------------------------------------------------------------
// يفتح لأي مستخدم في أي منشأة، ويعرض:
//   • بياناته الأساسية + نوع الهاتف + الدولة + عدّاد عملياته.
//   • تفعيل/إيقاف المستخدم (من أي منشأة).
//   • كل صلاحية من صلاحيات النظام (33 صلاحية) بمفتاح تشغيل/إيقاف.
//   • تغيير الدور، إعادة تعيين كلمة المرور، حذف المستخدم.
// ============================================================================
import 'package:flutter/material.dart';

import '../../models/user_models.dart';
import '../../services/control_service.dart';
import '../../services/operation_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import 'widgets.dart';

class UserPermissionsScreen extends StatefulWidget {
  final String userId;
  const UserPermissionsScreen({super.key, required this.userId});

  @override
  State<UserPermissionsScreen> createState() => _UserPermissionsScreenState();
}

class _UserPermissionsScreenState extends State<UserPermissionsScreen> {
  AppUser? _user;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() => _user = UserService.byId(widget.userId));

  // --------------------------------------------------------------------------
  Future<void> _togglePermission(String key) async {
    final u = _user;
    if (u == null) return;
    final set = u.useRoleDefaults
        ? Set<String>.from(u.effectivePermissions)
        : Set<String>.from(u.permissions);
    if (set.contains(key)) {
      set.remove(key);
    } else {
      set.add(key);
    }
    await UserService.update(u.copyWith(
      permissions: set,
      useRoleDefaults: false,
    ));
    _reload();
  }

  Future<void> _setAll(bool grant) async {
    final u = _user;
    if (u == null) return;
    await UserService.update(u.copyWith(
      permissions: grant ? Perm.all.toSet() : <String>{},
      useRoleDefaults: false,
    ));
    _reload();
  }

  Future<void> _useRoleDefaults(bool v) async {
    final u = _user;
    if (u == null) return;
    await UserService.update(u.copyWith(useRoleDefaults: v));
    _reload();
  }

  Future<void> _changeRole(UserRole role) async {
    final u = _user;
    if (u == null) return;
    await UserService.update(u.copyWith(role: role, useRoleDefaults: true));
    _reload();
  }

  Future<void> _resetPassword() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('إعادة تعيين كلمة المرور'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'كلمة المرور الجديدة',
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dlgCtx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.length < 6) return;
              Navigator.pop(dlgCtx, true);
            },
            child: const Text('تعيين'),
          ),
        ],
      ),
    );
    if (ok == true && ctrl.text.length >= 6) {
      await UserService.setPassword(widget.userId, ctrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إعادة تعيين كلمة المرور'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final u = _user;
    if (u == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('حذف المستخدم'),
        content: Text('هل تريد حذف «${u.name}» نهائياً؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dlgCtx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dlgCtx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await UserService.delete(u.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final u = _user;
    if (u == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('صلاحيات المستخدم')),
        body: const Center(child: Text('المستخدم غير موجود')),
      );
    }

    final company = ControlService.companyById(u.companyId);
    final device = ControlService.lastDeviceOfUser(u.id) ??
        (company != null
            ? ControlService.lastDeviceOfCompany(company.id)
            : null);
    final opsCount = OperationService.countOfUser(u.id);
    final effective = u.effectivePermissions;

    return Scaffold(
      appBar: AppBar(
        title: Text(u.name.isEmpty ? 'مستخدم' : u.name),
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'حذف',
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // ------- رأس المستخدم -------
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: u.isActive
                            ? AppColors.teal
                            : Colors.grey.shade400,
                        child: Text(u.initials,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u.name,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                            Text(
                              '${u.role.labelAr}'
                              '${u.username.isNotEmpty ? " • @${u.username}" : ""}',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600),
                            ),
                            if (company != null)
                              Text('المنشأة: ${company.companyName}',
                                  style: const TextStyle(fontSize: 11.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      BadgeChip(u.isActive ? 'نشط' : 'معطّل',
                          u.isActive ? AppColors.success : Colors.grey,
                          icon: u.isActive
                              ? Icons.check_circle_outline
                              : Icons.block),
                      BadgeChip('$opsCount عملية', AppColors.indigo,
                          icon: Icons.sync_alt),
                      if (u.isOwner)
                        const BadgeChip('المستخدم الرئيسي', AppColors.purple,
                            icon: Icons.star),
                      if (u.createdBy.isNotEmpty)
                        const BadgeChip('مستخدم فرعي', AppColors.info,
                            icon: Icons.subdirectory_arrow_right),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('المستخدم مُفعّل'),
                    subtitle: Text(u.isActive
                        ? 'يمكنه الدخول واستخدام التطبيق'
                        : 'الدخول موقوف'),
                    value: u.isActive,
                    activeThumbColor: AppColors.success,
                    onChanged: (v) async {
                      await UserService.update(u.copyWith(isActive: v));
                      _reload();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ------- الجهاز والدولة -------
          const SectionTitle('معلومات الجهاز والدولة', Icons.smartphone),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: device == null
                  ? const Text('لا توجد بيانات جهاز مسجّلة لهذا المستخدم',
                      style: TextStyle(fontSize: 12.5))
                  : Column(
                      children: [
                        KvRow('نوع الهاتف',
                            device.deviceLabel.isEmpty
                                ? platformLabel(device.platform)
                                : device.deviceLabel,
                            icon: platformIcon(device.platform)),
                        KvRow('النظام', device.osVersion,
                            icon: Icons.memory),
                        KvRow('المنصّة', platformLabel(device.platform),
                            icon: Icons.devices),
                        KvRow('الدولة',
                            device.country.isEmpty ? 'غير معروف' : device.country,
                            icon: Icons.public),
                        KvRow('رمز الدولة', device.countryCode,
                            icon: Icons.flag),
                        KvRow('آخر ظهور', timeAgo(device.lastSeenAt),
                            icon: Icons.schedule),
                        KvRow('عدد فتحات التطبيق', '${device.launchCount}',
                            icon: Icons.launch),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 14),

          // ------- بيانات الدخول -------
          const SectionTitle('بيانات الدخول', Icons.key),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  KvRow('اسم المستخدم', u.username),
                  KvRow('البريد', u.email),
                  KvRow('الهاتف', u.phone),
                  KvRow('له كلمة مرور',
                      u.hasCredentials ? 'نعم' : 'لا (حساب قديم)'),
                  KvRow('أُنشئ في', fmtDate(u.createdAt)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.password,
                      color: AppColors.warning),
                  title: const Text('إعادة تعيين كلمة المرور'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: _resetPassword,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.badge_outlined,
                      color: AppColors.info),
                  title: const Text('تغيير الدور'),
                  trailing: DropdownButton<UserRole>(
                    value: u.role,
                    underline: const SizedBox.shrink(),
                    items: UserRole.values
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r.labelAr,
                                  style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (r) {
                      if (r != null) _changeRole(r);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ------- الصلاحيات -------
          SectionTitle(
            'الصلاحيات الممنوحة (${effective.length}/${Perm.all.length})',
            Icons.tune,
          ),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  dense: true,
                  title: const Text('استخدام صلاحيات الدور الافتراضية'),
                  subtitle: const Text(
                      'عند الإيقاف تُطبَّق الصلاحيات المخصّصة أدناه فقط',
                      style: TextStyle(fontSize: 11)),
                  value: u.useRoleDefaults,
                  activeThumbColor: AppColors.primary,
                  onChanged: _useRoleDefaults,
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _setAll(true),
                        icon: const Icon(Icons.done_all,
                            size: 16, color: AppColors.success),
                        label: const Text('منح الكل',
                            style: TextStyle(fontSize: 12)),
                      ),
                      TextButton.icon(
                        onPressed: () => _setAll(false),
                        icon: const Icon(Icons.remove_done,
                            size: 16, color: AppColors.danger),
                        label: const Text('سحب الكل',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ..._permissionGroups(effective, u),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  /// مجموعات الصلاحيات لعرض منظّم
  List<Widget> _permissionGroups(Set<String> effective, AppUser u) {
    final groups = <String, List<String>>{
      'المبيعات': [
        Perm.salesView, Perm.salesCreate, Perm.salesEdit, Perm.salesDelete,
      ],
      'المشتريات': [
        Perm.purchasesView, Perm.purchasesCreate, Perm.purchasesEdit,
        Perm.purchasesDelete,
      ],
      'المخزون': [
        Perm.inventoryView, Perm.inventoryManage, Perm.inventoryTransfer,
        Perm.inventoryCount,
      ],
      'جهات الاتصال': [Perm.contactsView, Perm.contactsManage],
      'المحاسبة والقيود': [
        Perm.accountsView, Perm.accountsManage, Perm.journalView,
        Perm.journalCreate, Perm.journalDelete,
      ],
      'الخزينة والبنوك': [Perm.cashView, Perm.cashManage],
      'التقارير': [Perm.reportsView, Perm.reportsExport],
      'الموارد البشرية': [Perm.hrView, Perm.hrManage],
      'الأصول الثابتة': [Perm.assetsView, Perm.assetsManage],
      'الإعدادات': [Perm.settingsView, Perm.settingsManage],
      'المستخدمون': [Perm.usersView, Perm.usersManage],
      'المزامنة والنسخ الاحتياطي': [Perm.syncManage, Perm.backupManage],
    };

    final widgets = <Widget>[];
    groups.forEach((title, keys) {
      final granted = keys.where(effective.contains).length;
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        child: Row(
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            BadgeChip('$granted/${keys.length}',
                granted == keys.length
                    ? AppColors.success
                    : granted == 0
                        ? Colors.grey
                        : AppColors.warning),
          ],
        ),
      ));
      widgets.add(Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Column(
          children: keys.map((k) {
            final on = effective.contains(k);
            return SwitchListTile(
              dense: true,
              title: Text(Perm.labelsAr[k] ?? k,
                  style: const TextStyle(fontSize: 13)),
              value: on,
              activeThumbColor: AppColors.primary,
              onChanged: (_) => _togglePermission(k),
            );
          }).toList(),
        ),
      ));
    });
    return widgets;
  }
}
