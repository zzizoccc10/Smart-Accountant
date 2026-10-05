// ============================================================================
// شاشة إدارة المستخدمين والصلاحيات — UsersScreen
// ----------------------------------------------------------------------------
// • عرض/إضافة/تعديل/تعطيل/حذف المستخدمين.
// • تعيين الدور + تخصيص الصلاحيات الدقيقة.
// • عرض سجل النشاط.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_models.dart';
import '../../providers/session_provider.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import 'user_form.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final canManage = session.can(Perm.usersManage) || session.isOwner;

    return Scaffold(
      appBar: AppBar(
        title: const Text('المستخدمون والصلاحيات'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'المستخدمون', icon: Icon(Icons.people_outline, size: 20)),
            Tab(text: 'سجل النشاط', icon: Icon(Icons.history, size: 20)),
          ],
        ),
        actions: [
          if (canManage)
            IconButton(
              tooltip: 'إضافة مستخدم',
              icon: const Icon(Icons.person_add),
              onPressed: () async {
                final res = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const UserForm()),
                );
                if (res == true) setState(() {});
              },
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_usersTab(session, canManage), _activityTab()],
      ),
    );
  }

  Widget _usersTab(SessionProvider session, bool canManage) {
    final users = UserService.all();
    if (users.isEmpty) {
      return const Center(child: Text('لا يوجد مستخدمون بعد'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: users.length,
      itemBuilder: (context, i) {
        final u = users[i];
        final isCurrent = session.currentUser?.id == u.id;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: u.isActive ? AppColors.primary : Colors.grey,
              child: Text(
                u.initials,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Row(
              children: [
                Flexible(child: Text(u.name, overflow: TextOverflow.ellipsis)),
                if (isCurrent) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.check_circle, size: 14, color: Colors.green),
                ],
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${u.role.labelAr} • ${u.email}'),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _chip(
                      u.isActive ? 'نشط' : 'مُعطّل',
                      u.isActive ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 6),
                    _chip(
                      '${u.effectivePermissions.length} صلاحية',
                      Colors.blueGrey,
                    ),
                  ],
                ),
              ],
            ),
            trailing: canManage
                ? PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'edit') {
                        final res = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(builder: (_) => UserForm(user: u)),
                        );
                        if (res == true) setState(() {});
                      } else if (v == 'toggle') {
                        await UserService.update(
                          u.copyWith(isActive: !u.isActive),
                        );
                        setState(() {});
                      } else if (v == 'delete') {
                        if (u.isOwner) {
                          _snack('لا يمكن حذف المالك');
                          return;
                        }
                        if (isCurrent) {
                          _snack('لا يمكن حذف المستخدم الحالي');
                          return;
                        }
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
                          leading: Icon(Icons.delete, color: Colors.red),
                          title: Text('حذف'),
                          dense: true,
                        ),
                      ),
                    ],
                  )
                : null,
            onTap: canManage
                ? () async {
                    final res = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => UserForm(user: u)),
                    );
                    if (res == true) setState(() {});
                  }
                : null,
          ),
        );
      },
    );
  }

  Widget _activityTab() {
    final acts = UserService.recentActivity(limit: 200);
    if (acts.isEmpty) {
      return const Center(child: Text('لا يوجد سجل نشاط'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: acts.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final a = acts[i];
        return ListTile(
          dense: true,
          leading: const Icon(
            Icons.fiber_manual_record,
            size: 10,
            color: Colors.blueGrey,
          ),
          title: Text('${a.userName} — ${_actionLabel(a.action)}'),
          subtitle: Text(
            '${_fmt(a.createdAt)}${a.details.isNotEmpty ? ' • ${a.details}' : ''}',
            style: const TextStyle(fontSize: 11),
          ),
        );
      },
    );
  }

  String _actionLabel(String a) {
    const map = {
      'login': 'تسجيل دخول',
      'logout': 'تسجيل خروج',
      'create_invoice': 'إنشاء فاتورة',
      'delete_invoice': 'حذف فاتورة',
    };
    return map[a] ?? a;
  }

  String _fmt(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/'
        '${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(text, style: TextStyle(fontSize: 10, color: color)),
  );

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _confirm(String title, String body) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    return r ?? false;
  }
}
