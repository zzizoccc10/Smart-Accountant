// ============================================================================
// إعدادات مالك النظام — OwnerSettingsScreen
// ----------------------------------------------------------------------------
// تتيح لمالك النظام من داخل اللوحة:
//   1) عرض بيانات الدخول (اسم المستخدم/الاسم/البريد/تواريخ).
//   2) تعديل اسم المستخدم وكلمة المرور والاسم/البريد.
//   3) التحكّم بإتاحة اللوحة:
//      • إظهار قسم دخول المالك على الأجهزة الأخرى.
//      • تفعيل لوحة المالك من حساب «أول منشأة» (ربط منشأة).
//   4) عرض حالة جلسة المالك (فعّالة الآن على أي جهاز).
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/control_models.dart';
import '../../providers/session_provider.dart';
import '../../services/control_service.dart';
import '../../services/device_service.dart';
import '../../theme/app_theme.dart';
import 'widgets.dart';

class OwnerSettingsScreen extends StatefulWidget {
  const OwnerSettingsScreen({super.key});

  @override
  State<OwnerSettingsScreen> createState() => _OwnerSettingsScreenState();
}

class _OwnerSettingsScreenState extends State<OwnerSettingsScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _oldPass = TextEditingController();
  final _newPass = TextEditingController();
  bool _busy = false;
  bool _obscureOld = true;
  bool _obscureNew = true;

  @override
  void initState() {
    super.initState();
    final o = ControlService.systemOwner;
    _name.text = o?.name ?? '';
    _email.text = o?.email ?? '';
    _username.text = o?.username ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _username.dispose();
    _oldPass.dispose();
    _newPass.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.danger : AppColors.success,
      ),
    );
  }

  Future<void> _saveProfile() async {
    setState(() => _busy = true);
    try {
      await ControlService.updateSystemOwnerProfile(
        name: _name.text,
        email: _email.text,
      );
      final newUser = _username.text.trim();
      final o = ControlService.systemOwner;
      if (o != null && newUser.isNotEmpty && newUser != o.username) {
        final ok = await ControlService.changeSystemOwnerUsername(newUser);
        if (!ok) {
          _snack('اسم المستخدم قصير جداً (3 أحرف على الأقل)', error: true);
          return;
        }
      }
      if (mounted) _snack('تم حفظ بيانات الحساب');
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePassword() async {
    if (_newPass.text.length < 6) {
      _snack('كلمة المرور 6 أحرف على الأقل', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final ok = await ControlService.changeSystemOwnerPassword(
        oldPassword: _oldPass.text,
        newPassword: _newPass.text,
      );
      if (ok) {
        _oldPass.clear();
        _newPass.clear();
        if (mounted) _snack('تم تغيير كلمة المرور');
      } else {
        if (mounted) _snack('كلمة المرور الحالية غير صحيحة', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _endSession() async {
    await ControlService.endOwnerSession();
    if (mounted) {
      _snack('تم إنهاء جلسة المالك');
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final owner = ControlService.systemOwner;
    final cfg = ControlService.ownerConfig;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات مالك النظام'),
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // ---------------- حالة الجلسة ----------------
          _statusCard(cfg),

          const SizedBox(height: 14),

          // ---------------- بيانات الدخول الحالية ----------------
          const SectionTitle('بيانات الدخول الحالية', Icons.badge_outlined),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  KvRow('الاسم', owner?.name ?? '—', icon: Icons.person),
                  KvRow(
                    'اسم المستخدم',
                    owner?.username ?? '—',
                    icon: Icons.account_circle_outlined,
                  ),
                  KvRow(
                    'البريد الإلكتروني',
                    owner?.email ?? '—',
                    icon: Icons.email_outlined,
                  ),
                  KvRow(
                    'كلمة المرور',
                    '•••••••• (مشفَّرة — يمكنك تغييرها أدناه)',
                    icon: Icons.lock_outline,
                  ),
                  KvRow(
                    'هذا الجهاز',
                    ControlService.isPrimaryOwnerDevice
                        ? 'الجهاز الأول (مصرّح له)'
                        : 'جهاز فرعي',
                    icon: Icons.smartphone,
                  ),
                  KvRow(
                    'تاريخ الإنشاء',
                    fmtDate(owner?.createdAt ?? ''),
                    icon: Icons.event,
                  ),
                  KvRow(
                    'آخر دخول',
                    fmtDate(owner?.lastLoginAt ?? ''),
                    icon: Icons.login,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ---------------- تعديل اسم المستخدم/الاسم/البريد ----------------
          const SectionTitle('تعديل بيانات الدخول', Icons.edit_outlined),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  TextField(
                    controller: _username,
                    decoration: const InputDecoration(
                      labelText: 'اسم المستخدم',
                      prefixIcon: Icon(Icons.account_circle_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'الاسم',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _saveProfile,
                      icon: const Icon(Icons.save),
                      label: const Text('حفظ بيانات الحساب'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ---------------- تغيير كلمة المرور ----------------
          const SectionTitle('تغيير كلمة المرور', Icons.password),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  TextField(
                    controller: _oldPass,
                    obscureText: _obscureOld,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور الحالية',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureOld ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _obscureOld = !_obscureOld),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _newPass,
                    obscureText: _obscureNew,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور الجديدة',
                      prefixIcon: const Icon(Icons.lock_reset),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNew ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _changePassword,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.warning,
                      ),
                      icon: const Icon(Icons.lock_reset),
                      label: const Text('تغيير كلمة المرور'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ---------------- إتاحة اللوحة ----------------
          const SectionTitle('إتاحة لوحة المالك', Icons.admin_panel_settings),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: cfg.allowDeviceEntry,
                  activeThumbColor: AppColors.purple,
                  secondary: const Icon(
                    Icons.devices_other,
                    color: AppColors.purple,
                  ),
                  title: const Text(
                    'إظهار قسم دخول المالك على الأجهزة الأخرى',
                    style: TextStyle(fontSize: 13.5),
                  ),
                  subtitle: const Text(
                    'عند التعطيل يظهر قسم دخول المالك على الجهاز الأول فقط.',
                    style: TextStyle(fontSize: 11),
                  ),
                  onChanged: (v) async {
                    await ControlService.setAllowDeviceEntry(v);
                    if (mounted) setState(() {});
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: cfg.allowCompanyEntry,
                  activeThumbColor: AppColors.teal,
                  secondary: const Icon(
                    Icons.store_mall_directory,
                    color: AppColors.teal,
                  ),
                  title: const Text(
                    'تفعيل اللوحة من حساب «أول منشأة»',
                    style: TextStyle(fontSize: 13.5),
                  ),
                  subtitle: const Text(
                    'يسمح لحساب أول منشأة مرتبطة بفتح لوحة المالك من داخل التطبيق.',
                    style: TextStyle(fontSize: 11),
                  ),
                  onChanged: (v) async {
                    if (v && cfg.linkedCompanyId.isEmpty) {
                      await _pickCompany();
                      return;
                    }
                    await ControlService.setAllowCompanyEntry(v);
                    if (mounted) setState(() {});
                  },
                ),
                if (cfg.allowCompanyEntry) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.link, color: AppColors.teal),
                    title: const Text(
                      'المنشأة المرتبطة',
                      style: TextStyle(fontSize: 13.5),
                    ),
                    subtitle: Text(
                      _companyName(cfg.linkedCompanyId),
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: TextButton(
                      onPressed: _pickCompany,
                      child: const Text('تغيير'),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ---------------- إنهاء الجلسة ----------------
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppColors.danger),
              title: const Text(
                'إنهاء جلسة المالك الآن',
                style: TextStyle(fontSize: 13.5),
              ),
              subtitle: const Text(
                'تُخفي قسم الدخول للجميع، وتُظهره للأجهزة المصرّح لها.',
                style: TextStyle(fontSize: 11),
              ),
              onTap: session.isSystemOwner ? _endSession : null,
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  String _companyName(String id) {
    if (id.isEmpty) return '— لم تُحدَّد —';
    final c = ControlService.companyById(id);
    return c?.companyName ?? id;
  }

  Future<void> _pickCompany() async {
    final companies = ControlService.allCompanies();
    if (companies.isEmpty) {
      _snack('لا توجد منشآت بعد', error: true);
      return;
    }
    final chosen = await showModalBottomSheet<CompanyAccount>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'اختر «أول منشأة» لربط اللوحة بها',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: companies.length,
                itemBuilder: (_, i) {
                  final c = companies[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.teal.withValues(alpha: 0.15),
                      child: Text(
                        c.initials,
                        style: const TextStyle(
                          color: AppColors.teal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(c.companyName),
                    subtitle: Text(
                      '@${c.username}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    onTap: () => Navigator.pop(context, c),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (chosen != null) {
      await ControlService.setAllowCompanyEntry(true, companyId: chosen.id);
      if (mounted) setState(() {});
      _snack('تم ربط اللوحة بالمنشأة: ${chosen.companyName}');
    }
  }

  Widget _statusCard(OwnerConfig cfg) {
    final fresh = cfg.isSessionFresh;
    return Card(
      color: fresh
          ? AppColors.success.withValues(alpha: 0.08)
          : AppColors.info.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              fresh ? Icons.lock_clock : Icons.lock_open,
              color: fresh ? AppColors.success : AppColors.info,
              size: 30,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fresh ? 'جلسة المالك فعّالة الآن' : 'لا توجد جلسة فعّالة',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    fresh
                        ? 'قسم دخول المالك مخفيّ عن الجميع أثناء فعالية الجلسة.'
                        : 'قسم دخول المالك متاح حسب إعدادات الإتاحة أدناه.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  if (fresh && cfg.sessionDeviceId.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      cfg.sessionDeviceId == DeviceService.deviceId
                          ? 'الجهاز الفعّال: هذا الجهاز'
                          : 'الجهاز الفعّال: ${cfg.sessionDeviceId}',
                      style: const TextStyle(fontSize: 10.5),
                    ),
                  ],
                ],
              ),
            ),
            if (fresh)
              IconButton(
                tooltip: 'إنهاء الجلسة',
                icon: const Icon(
                  Icons.power_settings_new,
                  color: AppColors.danger,
                ),
                onPressed: _endSession,
              ),
          ],
        ),
      ),
    );
  }
}
