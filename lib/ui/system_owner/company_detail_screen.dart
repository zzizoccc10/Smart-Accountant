// ============================================================================
// تفاصيل منشأة (لوحة مالك النظام) — CompanyDetailScreen
// ----------------------------------------------------------------------------
// • تفعيل/إيقاف المنشأة + تعديل البيانات + إعادة تعيين كلمة المرور + حذف.
// • عدّادات: العمليات / المستخدمون / الأجهزة.
// • نوع الهاتف + الدولة التي يُفتح منها التطبيق.
// • المستخدم الرئيسي (أعلى) ثم المستخدمون الفرعيون (تحته).
// • كل مستخدم يعرض عدّاد عملياته، وبالضغط عليه تُفتح شاشة صلاحياته
//   لتفعيل/إيقاف أي صلاحية، ومع ذلك يمكن تفعيل/إيقاف المستخدم مباشرة.
// ============================================================================
import 'package:flutter/material.dart';

import '../../models/control_models.dart';
import '../../models/user_models.dart';
import '../../services/control_service.dart';
import '../../services/operation_service.dart';
import '../../services/stats_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import 'user_permissions_screen.dart';
import 'widgets.dart';

class CompanyDetailScreen extends StatefulWidget {
  final String companyId;
  const CompanyDetailScreen({super.key, required this.companyId});

  @override
  State<CompanyDetailScreen> createState() => _CompanyDetailScreenState();
}

class _CompanyDetailScreenState extends State<CompanyDetailScreen> {
  CompanyAccount? _company;

  @override
  void initState() {
    super.initState();
    _company = ControlService.companyById(widget.companyId);
  }

  void _reload() {
    if (!mounted) return;
    setState(() => _company = ControlService.companyById(widget.companyId));
  }

  @override
  Widget build(BuildContext context) {
    final c = _company;
    if (c == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل المنشأة')),
        body: const Center(child: Text('المنشأة غير موجودة')),
      );
    }

    final users = UserService.ofCompany(c.id);
    final mainUser = users.where((u) => u.isOwner).toList();
    final subUsers = users.where((u) => !u.isOwner).toList()
      ..sort((a, b) => OperationService.countOfUser(b.id)
          .compareTo(OperationService.countOfUser(a.id)));

    final ops = StatsService.opsOfCompany(c.id);
    final devices = ControlService.devicesOfCompany(c.id);
    final device = ControlService.lastDeviceOfCompany(c.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(c.companyName),
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
          IconButton(
            tooltip: 'حذف المنشأة',
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // ------- الحالة + الخطة -------
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('المنشأة مُفعّلة'),
                  subtitle: Text(c.isActive
                      ? 'يمكن للمستخدمين الدخول'
                      : 'الدخول موقوف مؤقتاً'),
                  value: c.isActive,
                  activeThumbColor: AppColors.success,
                  onChanged: (v) async {
                    await ControlService.setCompanyActive(c.id, v);
                    _reload();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.verified_user,
                      color: AppColors.primary),
                  title: const Text('الفئة/الخطة'),
                  trailing: DropdownButton<CompanyPlan>(
                    value: c.plan,
                    underline: const SizedBox.shrink(),
                    items: CompanyPlan.values
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(p.labelAr),
                            ))
                        .toList(),
                    onChanged: (p) async {
                      if (p == null) return;
                      await ControlService.updateCompany(c.copyWith(plan: p));
                      _reload();
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ------- العدّادات -------
          Row(
            children: [
              Expanded(
                child: MiniStat(
                  label: 'عملية',
                  value: '$ops',
                  color: AppColors.indigo,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MiniStat(
                  label: 'مستخدم',
                  value: '${users.length}',
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MiniStat(
                  label: 'جهاز',
                  value: '${devices.length}',
                  color: AppColors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ------- المعلومات الأساسية -------
          const SectionTitle('المعلومات الأساسية', Icons.info_outline),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  KvRow('اسم المنشأة', c.companyName,
                      icon: Icons.business),
                  KvRow('صاحب المنشأة', c.ownerName,
                      icon: Icons.person),
                  KvRow('اسم المستخدم', '@${c.username}',
                      icon: Icons.account_circle_outlined),
                  KvRow('البريد', c.email, icon: Icons.email_outlined),
                  KvRow('الهاتف', c.phone, icon: Icons.phone_outlined),
                  KvRow('أُنشئ في', fmtDate(c.createdAt),
                      icon: Icons.event),
                  KvRow('آخر دخول',
                      c.lastLoginAt.isEmpty
                          ? 'لم يدخل بعد'
                          : fmtDate(c.lastLoginAt),
                      icon: Icons.schedule),
                  KvRow('طريقة الإنشاء', _viaLabel(c.createdVia),
                      icon: Icons.input),
                  KvRow('نوع الهاتف',
                      device == null
                          ? 'غير مسجّل'
                          : (device.deviceLabel.isEmpty
                              ? platformLabel(device.platform)
                              : device.deviceLabel),
                      icon: device == null
                          ? Icons.smartphone
                          : platformIcon(device.platform)),
                  KvRow('نظام الجهاز', device?.osVersion ?? '',
                      icon: Icons.memory),
                  KvRow('الدولة',
                      device == null || device.country.isEmpty
                          ? 'غير معروف'
                          : device.country,
                      icon: Icons.public),
                  KvRow('معرّف الجهاز',
                      c.deviceId.isEmpty ? '—' : c.deviceId,
                      icon: Icons.fingerprint),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ------- الصلاحيات -------
          const SectionTitle('صلاحيات المنشأة والامتيازات', Icons.tune),
          Card(
            child: Column(
              children: [
                ...CompanyPrivileges.allKeys.map((key) {
                  final on = c.privileges.granted.contains(key);
                  return SwitchListTile(
                    dense: true,
                    title: Text(CompanyPrivileges.labelsAr[key] ?? key),
                    value: on,
                    activeThumbColor: AppColors.primary,
                    onChanged: (_) async {
                      await ControlService.togglePrivilege(c.id, key);
                      _reload();
                    },
                  );
                }),
                const Divider(height: 1),
                SwitchListTile(
                  dense: true,
                  title: const Text('السماح بالتصدير والطباعة'),
                  value: c.privileges.allowExport,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) async {
                    await ControlService.updatePrivileges(
                      c.id,
                      c.privileges.copyWith(allowExport: v),
                    );
                    _reload();
                  },
                ),
                SwitchListTile(
                  dense: true,
                  title: const Text('السماح بالمزامنة السحابية'),
                  value: c.privileges.allowCloud,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) async {
                    await ControlService.updatePrivileges(
                      c.id,
                      c.privileges.copyWith(allowCloud: v),
                    );
                    _reload();
                  },
                ),
                SwitchListTile(
                  dense: true,
                  title: const Text('الدعم الفني المتقدم'),
                  value: c.privileges.allowSupport,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) async {
                    await ControlService.updatePrivileges(
                      c.id,
                      c.privileges.copyWith(allowSupport: v),
                    );
                    _reload();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ------- إجراءات -------
          const SectionTitle('إجراءات', Icons.settings),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.password,
                      color: AppColors.warning),
                  title: const Text('إعادة تعيين كلمة مرور المنشأة'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: _resetPasswordDialog,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.edit, color: AppColors.info),
                  title: const Text('تعديل البيانات'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: _editDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ------- المستخدم الرئيسي -------
          SectionTitle('المستخدم الرئيسي', Icons.star,
              trailing: BadgeChip('${mainUser.length}', AppColors.purple)),
          if (mainUser.isEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('لا يوجد مستخدم رئيسي مسجّل محلياً',
                    style: TextStyle(fontSize: 13)),
                subtitle: Text(
                    'اسم المستخدم: @${c.username}', 
                    style: const TextStyle(fontSize: 11)),
              ),
            )
          else
            ...mainUser.map((u) => _userCard(u, isMain: true)),

          const SizedBox(height: 16),

          // ------- المستخدمون الفرعيون -------
          SectionTitle('المستخدمون الفرعيون (${subUsers.length})',
              Icons.people_outline),
          if (subUsers.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('لا يوجد مستخدمون فرعيون',
                    style: TextStyle(fontSize: 13)),
                subtitle: Text('يُضافون من داخل الحساب الرئيسي للمنشأة',
                    style: TextStyle(fontSize: 11)),
              ),
            )
          else
            ...subUsers.map((u) => _userCard(u, isMain: false)),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  /// بطاقة مستخدم: عدّاد العمليات + تفعيل/إيقاف + فتح الصلاحيات
  Widget _userCard(AppUser u, {required bool isMain}) {
    final ops = OperationService.countOfUser(u.id);
    final device = ControlService.lastDeviceOfUser(u.id);
    final granted = u.effectivePermissions.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserPermissionsScreen(userId: u.id),
            ),
          );
          _reload();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: u.isActive
                        ? (isMain ? AppColors.purple : AppColors.teal)
                        : Colors.grey.shade400,
                    child: Text(u.initials,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(u.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold)),
                            ),
                            if (isMain)
                              const BadgeChip('رئيسي', AppColors.purple,
                                  icon: Icons.star),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${u.role.labelAr}'
                          '${u.username.isNotEmpty ? " • @${u.username}" : ""}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: u.isActive,
                    activeThumbColor: AppColors.success,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (v) async {
                      await UserService.update(u.copyWith(isActive: v));
                      _reload();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(v
                                ? 'تم تفعيل «${u.name}»'
                                : 'تم إيقاف «${u.name}»'),
                            backgroundColor:
                                v ? AppColors.success : AppColors.warning,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  BadgeChip('$ops عملية', AppColors.indigo,
                      icon: Icons.sync_alt),
                  BadgeChip('$granted/${Perm.all.length} صلاحية',
                      AppColors.info, icon: Icons.tune),
                  if (device != null)
                    BadgeChip(
                        device.deviceLabel.isEmpty
                            ? platformLabel(device.platform)
                            : device.deviceLabel,
                        AppColors.purple,
                        icon: platformIcon(device.platform)),
                  if (device != null)
                    BadgeChip(
                        device.country.isEmpty ? 'غير معروف' : device.country,
                        AppColors.teal,
                        icon: Icons.public),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('اضغط لإدارة الصلاحيات',
                        style: TextStyle(
                            fontSize: 10.5, color: Colors.grey.shade600)),
                    const Icon(Icons.chevron_left,
                        size: 16, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _viaLabel(String via) {
    switch (via) {
      case 'email':
        return 'بريد إلكتروني';
      case 'google':
        return 'حساب Google';
      case 'device':
        return 'الجهاز';
      default:
        return via;
    }
  }

  // --------------------------------------------------------------------------
  // حوارات
  // --------------------------------------------------------------------------
  Future<void> _resetPasswordDialog() async {
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
      await ControlService.resetCompanyPassword(widget.companyId, ctrl.text);
      _reload();
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

  Future<void> _editDialog() async {
    final c = _company!;
    final name = TextEditingController(text: c.companyName);
    final owner = TextEditingController(text: c.ownerName);
    final phone = TextEditingController(text: c.phone);
    final email = TextEditingController(text: c.email);

    final ok = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('تعديل بيانات المنشأة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: name,
                  decoration:
                      const InputDecoration(labelText: 'اسم المنشأة')),
              TextField(
                  controller: owner,
                  decoration:
                      const InputDecoration(labelText: 'صاحب المنشأة')),
              TextField(
                  controller: phone,
                  decoration: const InputDecoration(labelText: 'الهاتف')),
              TextField(
                  controller: email,
                  decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dlgCtx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () => Navigator.pop(dlgCtx, true),
              child: const Text('حفظ')),
        ],
      ),
    );
    if (ok == true) {
      await ControlService.updateCompany(c.copyWith(
        companyName: name.text.trim(),
        ownerName: owner.text.trim(),
        phone: phone.text.trim(),
        email: email.text.trim(),
      ));
      _reload();
    }
  }

  Future<void> _confirmDelete() async {
    final c = _company!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('حذف المنشأة'),
        content: Text('هل تريد حذف «${c.companyName}» نهائياً؟ '
            'لا يمكن التراجع عن هذا الإجراء.'),
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
      await ControlService.deleteCompany(c.id);
      if (mounted) Navigator.of(context).pop();
    }
  }
}
