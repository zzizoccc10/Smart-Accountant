// ============================================================================
// نموذج إضافة/تعديل مستخدم — UserForm
// ----------------------------------------------------------------------------
// • حقول: الاسم، البريد، الهاتف، الدور، الفرع.
// • اختيار الدور يُعبّئ الصلاحيات الافتراضية تلقائياً.
// • إمكانية تخصيص كل صلاحية يدوياً (Switch لكل صلاحية مجمّعة بالأقسام).
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_database.dart';
import '../../models/user_models.dart';
import '../../providers/session_provider.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';

class UserForm extends StatefulWidget {
  final AppUser? user;
  const UserForm({super.key, this.user});

  @override
  State<UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<UserForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _email;
  late TextEditingController _phone;
  late UserRole _role;
  late Set<String> _permissions;
  bool _useDefaults = true;
  bool _isActive = true;
  String? _branchId;

  bool get _isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _name = TextEditingController(text: u?.name ?? '');
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
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save(SessionProvider session) async {
    if (!_formKey.currentState!.validate()) return;

    // منع تعديل صلاحيات المالك (حماية)
    final isOwnerRole = _role == UserRole.owner;
    final perms = isOwnerRole
        ? {...Perm.all}
        : (_useDefaults ? Perm.defaultsForRole(_role) : _permissions);

    if (_isEdit) {
      final u = widget.user!.copyWith(
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        role: _role,
        permissions: perms,
        useRoleDefaults: isOwnerRole ? true : _useDefaults,
        isActive: _isActive,
        branchId: _branchId,
      );
      await UserService.update(u);
    } else {
      // منع تكرار البريد
      if (UserService.byEmail(_email.text.trim()) != null) {
        _snack('البريد مستخدم بالفعل', error: true);
        return;
      }
      await UserService.create(
        AppUser(
          id: UserService.newId(),
          name: _name.text.trim(),
          email: _email.text.trim(),
          phone: _phone.text.trim(),
          role: _role,
          permissions: perms,
          useRoleDefaults: isOwnerRole ? true : _useDefaults,
          isActive: _isActive,
          branchId: _branchId,
        ),
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
    final effectivePerms = _role == UserRole.owner
        ? Perm.all
        : Perm.defaultsForRole(_role);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'تعديل مستخدم' : 'مستخدم جديد'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'الاسم',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'أدخل الاسم' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'أدخل البريد';
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
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // الدور
            DropdownButtonFormField<UserRole>(
              initialValue: _role,
              decoration: const InputDecoration(
                labelText: 'الدور',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
              ),
              items: UserRole.values
                  .map(
                    (r) => DropdownMenuItem(value: r, child: Text(r.labelAr)),
                  )
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

            // الفرع
            if (branches.isNotEmpty)
              DropdownButtonFormField<String?>(
                initialValue: branches.any((b) => b.id == _branchId)
                    ? _branchId
                    : null,
                decoration: const InputDecoration(
                  labelText: 'الفرع (اختياري)',
                  prefixIcon: Icon(Icons.store_outlined),
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('بدون فرع')),
                  ...branches.map(
                    (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
                  ),
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
            const Text(
              'الصلاحيات',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),

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
                subtitle: Text(
                  '${effectivePerms.length} صلاحية مفعّلة افتراضياً',
                  style: const TextStyle(fontSize: 12),
                ),
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
              if (!_useDefaults) ...[
                const SizedBox(height: 4),
                ..._permissionSections(),
              ],
            ],

            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _save(session),
                icon: const Icon(Icons.save),
                label: Text(_isEdit ? 'حفظ التعديلات' : 'إضافة المستخدم'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// أقسام الصلاحيات (مجمّعة)
  List<Widget> _permissionSections() {
    final groups = <String, List<String>>{
      'المبيعات': [
        Perm.salesView,
        Perm.salesCreate,
        Perm.salesEdit,
        Perm.salesDelete,
      ],
      'المشتريات': [
        Perm.purchasesView,
        Perm.purchasesCreate,
        Perm.purchasesEdit,
        Perm.purchasesDelete,
      ],
      'المخزون': [
        Perm.inventoryView,
        Perm.inventoryManage,
        Perm.inventoryTransfer,
        Perm.inventoryCount,
      ],
      'جهات الاتصال': [Perm.contactsView, Perm.contactsManage],
      'الحسابات والقيود': [
        Perm.accountsView,
        Perm.accountsManage,
        Perm.journalView,
        Perm.journalCreate,
        Perm.journalDelete,
      ],
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
          title: Text(
            e.key,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
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
              title: Text(
                Perm.labelsAr[p] ?? p,
                style: const TextStyle(fontSize: 13),
              ),
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
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }
}
