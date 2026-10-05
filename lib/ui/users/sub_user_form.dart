// ============================================================================
// نموذج إضافة/تعديل مستخدم فرعي — SubUserForm
// ----------------------------------------------------------------------------
// يُنشئ مستخدماً ببيانات دخول (اسم مستخدم + كلمة مرور) من داخل الحساب الرئيسي.
// يعيّن الدور + الصلاحيات، ويربطه بالمنشأة الحالية.
// ============================================================================
import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../models/user_models.dart';
import '../../providers/session_provider.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import 'package:provider/provider.dart';

class SubUserForm extends StatefulWidget {
  final AppUser? user;
  const SubUserForm({super.key, this.user});

  @override
  State<SubUserForm> createState() => _SubUserFormState();
}

class _SubUserFormState extends State<SubUserForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _username;
  late TextEditingController _password;
  late TextEditingController _email;
  late TextEditingController _phone;
  late UserRole _role;
  late Set<String> _permissions;
  bool _useDefaults = true;
  bool _isActive = true;
  bool _obscure = true;
  String? _branchId;

  bool get _isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _name = TextEditingController(text: u?.name ?? '');
    _username = TextEditingController(text: u?.username ?? '');
    _password = TextEditingController();
    _email = TextEditingController(text: u?.email ?? '');
    _phone = TextEditingController(text: u?.phone ?? '');
    _role = u?.role ?? UserRole.viewer;
    _permissions = u?.permissions.toSet() ?? {};
    _useDefaults = u?.useRoleDefaults ?? true;
    _isActive = u?.isActive ?? true;
    _branchId = u?.branchId;
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _password.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save(SessionProvider session) async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final isOwnerRole = _role == UserRole.owner;
    final perms = isOwnerRole
        ? {...Perm.all}
        : (_useDefaults ? Perm.defaultsForRole(_role) : _permissions);
    final companyId = session.currentCompanyId;

    if (_isEdit) {
      final u = widget.user!.copyWith(
        name: _name.text.trim(),
        username: _username.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        role: _role,
        permissions: perms,
        useRoleDefaults: isOwnerRole ? true : _useDefaults,
        isActive: _isActive,
        branchId: _branchId,
        companyId: companyId,
      );
      await UserService.update(u);
      // تغيير كلمة المرور إن أُدخلت
      if (_password.text.isNotEmpty) {
        await UserService.setPassword(u.id, _password.text);
      }
    } else {
      // منع تكرار اسم المستخدم/البريد داخل النظام
      if (UserService.byUsername(_username.text.trim()) != null) {
        _snack('اسم المستخدم مستخدم بالفعل', error: true);
        return;
      }
      if (_email.text.trim().isNotEmpty &&
          UserService.byLogin(_email.text.trim()) != null) {
        _snack('البريد مستخدم بالفعل', error: true);
        return;
      }
      await UserService.createWithCredentials(
        name: _name.text.trim(),
        username: _username.text.trim(),
        password: _password.text,
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        role: _role,
        permissions: perms,
        useRoleDefaults: isOwnerRole ? true : _useDefaults,
        branchId: _branchId,
        companyId: companyId,
        createdBy: session.currentUser?.id ?? '',
      );
    }

    if (session.currentUser != null) {
      await UserService.logActivity(
        userId: session.currentUser!.id,
        userName: session.currentUser!.name,
        action: _isEdit ? 'update_user' : 'create_user',
        details: _name.text.trim(),
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionProvider>();
    final branches = AppDatabase.branches;
    final effectivePerms =
        _role == UserRole.owner ? Perm.all : Perm.defaultsForRole(_role);

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'تعديل مستخدم' : 'مستخدم جديد')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _Head('بيانات المستخدم', Icons.person_outline),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'الاسم',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'أدخل الاسم' : null,
            ),
            const SizedBox(height: 12),
            const _Head('بيانات الدخول', Icons.key_outlined),
            TextFormField(
              controller: _username,
              decoration: const InputDecoration(
                labelText: 'اسم المستخدم',
                prefixIcon: Icon(Icons.account_circle_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().length < 3) ? '3 أحرف على الأقل' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: _isEdit
                    ? 'كلمة مرور جديدة (اتركها فارغة لعدم التغيير)'
                    : 'كلمة المرور',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) {
                if (_isEdit && (v == null || v.isEmpty)) return null;
                if (v == null || v.length < 6) {
                  return 'كلمة المرور 6 أحرف على الأقل';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني (اختياري)',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                if (!v.contains('@')) return 'بريد غير صالح';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 16),
            const _Head('الدور والصلاحيات', Icons.badge_outlined),
            DropdownButtonFormField<UserRole>(
              initialValue: _role,
              decoration: const InputDecoration(
                labelText: 'الدور',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              items: UserRole.values
                  .map((r) => DropdownMenuItem(value: r, child: Text(r.labelAr)))
                  .toList(),
              onChanged: (r) {
                if (r == null) return;
                setState(() {
                  _role = r;
                  _useDefaults = true;
                });
              },
            ),
            const SizedBox(height: 12),
            if (branches.isNotEmpty)
              DropdownButtonFormField<String?>(
                initialValue:
                    branches.any((b) => b.id == _branchId) ? _branchId : null,
                decoration: const InputDecoration(
                  labelText: 'الفرع (اختياري)',
                  prefixIcon: Icon(Icons.store_outlined),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('بدون فرع')),
                  ...branches.map((b) => DropdownMenuItem(
                        value: b.id,
                        child: Text(b.name),
                      )),
                ],
                onChanged: (v) => setState(() => _branchId = v),
              ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('المستخدم نشط'),
              value: _isActive,
              activeThumbColor: AppColors.primary,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            const Divider(height: 24),
            if (_role == UserRole.owner)
              const Card(
                color: Color(0xFFE8F5E9),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.verified_user, color: Colors.green),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'المالك يملك كل الصلاحيات تلقائياً ولا يمكن تقييده.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              SwitchListTile(
                title: const Text('استخدام صلاحيات الدور الافتراضية'),
                subtitle: Text('${effectivePerms.length} صلاحية مفعّلة افتراضياً',
                    style: const TextStyle(fontSize: 12)),
                value: _useDefaults,
                activeThumbColor: AppColors.primary,
                onChanged: (v) {
                  setState(() {
                    _useDefaults = v;
                    if (!v && _permissions.isEmpty) {
                      _permissions = Perm.defaultsForRole(_role);
                    }
                  });
                },
              ),
              if (!_useDefaults) ..._permissionSections(),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _save(session),
                icon: const Icon(Icons.save),
                label: Text(_isEdit ? 'حفظ التعديلات' : 'إضافة المستخدم'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  List<Widget> _permissionSections() {
    final groups = <String, List<String>>{
      'المبيعات': [Perm.salesView, Perm.salesCreate, Perm.salesEdit, Perm.salesDelete],
      'المشتريات': [Perm.purchasesView, Perm.purchasesCreate, Perm.purchasesEdit, Perm.purchasesDelete],
      'المخزون': [Perm.inventoryView, Perm.inventoryManage, Perm.inventoryTransfer, Perm.inventoryCount],
      'جهات الاتصال': [Perm.contactsView, Perm.contactsManage],
      'الحسابات والقيود': [Perm.accountsView, Perm.accountsManage, Perm.journalView, Perm.journalCreate, Perm.journalDelete],
      'الخزينة': [Perm.cashView, Perm.cashManage],
      'التقارير': [Perm.reportsView, Perm.reportsExport],
      'الموارد البشرية': [Perm.hrView, Perm.hrManage],
      'الأصول الثابتة': [Perm.assetsView, Perm.assetsManage],
      'الإعدادات': [Perm.settingsView, Perm.settingsManage],
      'المستخدمون': [Perm.usersView, Perm.usersManage],
      'المزامنة والنسخ': [Perm.syncManage, Perm.backupManage],
    };

    return groups.entries.map((e) {
      final allSelected = e.value.every(_permissions.contains);
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ExpansionTile(
          title: Text(e.key,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          trailing: Checkbox(
            value: allSelected,
            onChanged: (v) {
              setState(() {
                if (v == true) {
                  _permissions.addAll(e.value);
                } else {
                  _permissions.removeAll(e.value);
                }
              });
            },
          ),
          children: e.value.map((p) {
            return CheckboxListTile(
              dense: true,
              title: Text(Perm.labelsAr[p] ?? p,
                  style: const TextStyle(fontSize: 13)),
              value: _permissions.contains(p),
              activeColor: AppColors.primary,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _permissions.add(p);
                  } else {
                    _permissions.remove(p);
                  }
                });
              },
            );
          }).toList(),
        ),
      );
    }).toList();
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }
}

class _Head extends StatelessWidget {
  final String text;
  final IconData icon;
  const _Head(this.text, this.icon);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
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
