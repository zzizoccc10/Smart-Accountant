// ============================================================================
// إدارة مستخدمي المنشأة — SubUsersScreen
// ----------------------------------------------------------------------------
// يفتحها صاحب المنشأة (الدور owner) من داخل الحساب الرئيسي.
// يضيف مستخدمين ببيانات دخول (اسم مستخدم + كلمة مرور)، ويحدّد صلاحياتهم.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_models.dart';
import '../../providers/session_provider.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import 'sub_user_form.dart';

class SubUsersScreen extends StatefulWidget {
  const SubUsersScreen({super.key});

  @override
  State<SubUsersScreen> createState() => _SubUsersScreenState();
}

class _SubUsersScreenState extends State<SubUsersScreen> {
  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final companyId = session.currentCompanyId;
    final me = session.currentUser;

    // مستخدمو هذه المنشأة فقط (بدون المستخدم الحالي/المالك الأساسي إن أردت)
    final users = UserService.ofCompany(companyId, excludeId: me?.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('مستخدمو المنشأة'),
        actions: [
          IconButton(
            tooltip: 'إضافة مستخدم',
            icon: const Icon(Icons.person_add),
            onPressed: () async {
              final res = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const SubUserForm()),
              );
              if (res == true) setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ترويسة معلوماتية
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'تُضاف حسابات الموظفين هنا. يدخلون للنظام باسم المستخدم '
                    'وكلمة المرور التي تُنشئها لهم، ضمن صلاحيات محددة.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: users.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.group_add_outlined,
                          size: 56,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 12),
                        Text('لا يوجد مستخدمون بعد'),
                        SizedBox(height: 6),
                        Text(
                          'اضغط + لإضافة أول مستخدم',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: users.length,
                    itemBuilder: (context, i) {
                      final u = users[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: u.isActive
                                ? AppColors.primary
                                : Colors.grey,
                            child: Text(
                              u.initials,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(u.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${u.role.labelAr}'
                                '${u.username.isNotEmpty ? ' • @${u.username}' : ''}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  _chip(
                                    u.isActive ? 'نشط' : 'معطّل',
                                    u.isActive ? Colors.green : Colors.red,
                                  ),
                                  const SizedBox(width: 6),
                                  _chip(
                                    '${u.effectivePermissions.length} صلاحية',
                                    Colors.blueGrey,
                                  ),
                                  if (u.hasCredentials) ...[
                                    const SizedBox(width: 6),
                                    _chip('له دخول', AppColors.info),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'edit') {
                                final res = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SubUserForm(user: u),
                                  ),
                                );
                                if (res == true) setState(() {});
                              } else if (v == 'toggle') {
                                await UserService.update(
                                  u.copyWith(isActive: !u.isActive),
                                );
                                setState(() {});
                              } else if (v == 'password') {
                                await _resetPassword(u);
                              } else if (v == 'delete') {
                                final ok = await _confirm(
                                  'حذف المستخدم',
                                  'هل تريد حذف "${u.name}"؟',
                                );
                                if (ok) {
                                  await UserService.delete(u.id);
                                  setState(() {});
                                }
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: ListTile(
                                  leading: Icon(Icons.edit),
                                  title: Text('تعديل'),
                                  dense: true,
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'password',
                                child: ListTile(
                                  leading: Icon(Icons.password),
                                  title: Text('تغيير كلمة المرور'),
                                  dense: true,
                                ),
                              ),
                              PopupMenuItem(
                                value: 'toggle',
                                child: ListTile(
                                  leading: Icon(
                                    u.isActive
                                        ? Icons.block
                                        : Icons.check_circle_outline,
                                  ),
                                  title: Text(u.isActive ? 'تعطيل' : 'تفعيل'),
                                  dense: true,
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: ListTile(
                                  leading: Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  title: Text('حذف'),
                                  dense: true,
                                ),
                              ),
                            ],
                          ),
                          onTap: () async {
                            final res = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SubUserForm(user: u),
                              ),
                            );
                            if (res == true) setState(() {});
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPassword(AppUser u) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Text('تغيير كلمة مرور "${u.name}"'),
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
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.length >= 6) Navigator.pop(dlgCtx, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (ok == true && ctrl.text.length >= 6) {
      await UserService.setPassword(u.id, ctrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تغيير كلمة المرور'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(text, style: TextStyle(fontSize: 10, color: color)),
  );

  Future<bool> _confirm(String title, String body) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dlgCtx).pop(true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    return r ?? false;
  }
}
