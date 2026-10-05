// ============================================================================
// تفاصيل منشأة (لوحة مالك النظام) — CompanyDetailScreen
// ----------------------------------------------------------------------------
// • تعديل البيانات الأساسية.
// • تفعيل/إيقاف.
// • منح/سحب الصلاحيات والامتيازات.
// • إعادة تعيين كلمة المرور.
// • عرض مستخدمي المنشأة وحذفها.
// ============================================================================
import 'package:flutter/material.dart';

import '../../models/control_models.dart';
import '../../models/user_models.dart';
import '../../services/control_service.dart';
import '../../services/security_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: Text(c.companyName),
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'حذف المنشأة',
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // الحالة + التفعيل
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
          const SizedBox(height: 16),

          // معلومات
          const _SectionTitle('المعلومات الأساسية', Icons.info_outline),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _kv('اسم المنشأة', c.companyName),
                  _kv('صاحب المنشأة', c.ownerName.isEmpty ? '—' : c.ownerName),
                  _kv('اسم المستخدم', '@${c.username}'),
                  _kv('البريد', c.email.isEmpty ? '—' : c.email),
                  _kv('الهاتف', c.phone.isEmpty ? '—' : c.phone),
                  _kv('أُنشئ في', _fmt(c.createdAt)),
                  _kv('آخر دخول', c.lastLoginAt.isEmpty ? 'لم يدخل بعد' : _fmt(c.lastLoginAt)),
                  _kv('طريقة الإنشاء', _viaLabel(c.createdVia)),
                  _kv('معرّف الجهاز', c.deviceId.isEmpty ? '—' : c.deviceId),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // الصلاحيات
          const _SectionTitle('الصلاحيات والامتيازات', Icons.tune),
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

          // إجراءات
          const _SectionTitle('إجراءات', Icons.settings),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.password, color: AppColors.warning),
                  title: const Text('إعادة تعيين كلمة المرور'),
                  subtitle:
                      const Text('تعيين كلمة مرور جديدة لدخول المنشأة'),
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

          // مستخدمو المنشأة
          _SectionTitle('مستخدمو المنشأة (${users.length})', Icons.people_outline),
          Card(
            child: users.isEmpty
                ? const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('لا يوجد مستخدمون فرعيون'),
                    subtitle: Text('يُضافون من داخل الحساب الرئيسي للمنشأة'),
                  )
                : Column(
                    children: users
                        .map((u) => ListTile(
                              leading: CircleAvatar(
                                backgroundColor: u.isActive
                                    ? AppColors.teal
                                    : Colors.grey,
                                child: Text(u.initials,
                                    style: const TextStyle(color: Colors.white)),
                              ),
                              title: Text(u.name),
                              subtitle: Text(
                                  '${u.role.labelAr}${u.username.isNotEmpty ? ' • @${u.username}' : ''}'),
                              trailing: Switch(
                                value: u.isActive,
                                activeThumbColor: AppColors.success,
                                onChanged: (v) async {
                                  await UserService.update(
                                      u.copyWith(isActive: v));
                                  _reload();
                                },
                              ),
                            ))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 130,
              child: Text(k,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ),
            Expanded(
              child: Text(v,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );

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

  String _fmt(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/'
        '${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
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
                  decoration: const InputDecoration(labelText: 'اسم المنشأة')),
              TextField(
                  controller: owner,
                  decoration:
                      const InputDecoration(labelText: 'صاحب المنشأة')),
              TextField(
                  controller: phone,
                  decoration: const InputDecoration(labelText: 'الهاتف')),
              TextField(
                  controller: email,
                  decoration:
                      const InputDecoration(labelText: 'البريد الإلكتروني')),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
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

class _SectionTitle extends StatelessWidget {
  final String text;
  final IconData icon;
  const _SectionTitle(this.text, this.icon);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(text,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }
}

// إشارة لتفادي تحذير الاستيراد غير المستخدم
// ignore: unused_element
final _unused = SecurityService.generateSalt;
